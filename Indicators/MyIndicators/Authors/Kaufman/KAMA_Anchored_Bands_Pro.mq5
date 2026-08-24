//+------------------------------------------------------------------+
//|                                     KAMA_Anchored_Bands_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Fixed Custom Session Band Display & Lifetime Management
#property description "Session-Anchored Kaufman's Adaptive Moving Average (AKAMA) with Standard Deviation Bands."
#property description "Features robust Custom Session handling, non-repainting MTF mapping, and current session focus."

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot 1-2: Anchored KAMA (Odd/Even for Gapped Drawing)
#property indicator_label1  "AKAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3-4: Band 1 (+/- 1.0 Sigma)
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "Lower Band 1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width3  1

//--- Plot 5-6: Band 2 (+/- 2.0 Sigma)
#property indicator_label5  "Upper Band 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCoral
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Lower Band 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCoral
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7-8: Band 3 (+/- 3.0 Sigma)
#property indicator_label7  "Upper Band 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCrimson
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  "Lower Band 3"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrCrimson
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Included Engines & Central Tools
#include <MyIncludes\KAMA_Anchored_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe        = PERIOD_CURRENT;        // Calculation Timeframe (Current or HTF)

input group "--- Anchor Settings ---"
input ENUM_ANCHOR_PERIOD        InpResetPeriod      = ANCHOR_PERIOD_SESSION; // Anchor Reset Period
input int                       InpTzShift          = 0;                     // Timezone Shift (Hours)
input string                    InpCustomStart      = "08:00";               // Custom Session Start (HH:MM)
input string                    InpCustomEnd        = "17:00";               // Custom Session End (HH:MM)

input group "--- KAMA Core Settings ---"
input int                       InpErPeriod         = 10;                    // Efficiency Ratio Period
input int                       InpFastEmaPeriod    = 2;                     // Fastest EMA Period
input int                       InpSlowEmaPeriod    = 30;                    // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice      = PRICE_CLOSE_STD;       // Price Source (Standard / HA)

input group "--- Standard Deviation Bands Settings ---"
input double                    InpBand1Mult        = 1.0;                   // Band 1 Multiplier (Sigma)
input double                    InpBand2Mult        = 2.0;                   // Band 2 Multiplier (Sigma)
input double                    InpBand3Mult        = 3.0;                   // Band 3 Multiplier (Sigma)
input bool                      InpCurrentSessionOnly= true;                 // Display Bands for Most Recent Session Only?

input group "--- Visual Settings - AKAMA Centerline ---"
input color                     InpColorKAMA        = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleKAMA        = STYLE_SOLID;           // Centerline Style
input int                       InpWidthKAMA        = 1;                     // Centerline Width

input group "--- Visual Settings - Bands Colors ---"
input color                     InpColorBand1       = clrDodgerBlue;         // Band 1 Color (+/- 1σ)
input color                     InpColorBand2       = clrCoral;              // Band 2 Color (+/- 2σ)
input color                     InpColorBand3       = clrCrimson;            // Band 3 Color (+/- 3σ)

//--- Visual Indicator Buffers ---
double BufKAMA_Odd[];
double BufKAMA_Even[];
double BufUp1[], BufDn1[];
double BufUp2[], BufDn2[];
double BufUp3[], BufDn3[];

//--- Internal State Buffer (Current Timeframe)
double g_price_series[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[], h_price[];
double h_res_odd[], h_res_even[];
double h_res_up1[], h_res_dn1[];
double h_res_up2[], h_res_dn2[];
double h_res_up3[], h_res_dn3[];
datetime h_time[];

//--- Global Objects & State Management
CKamaAnchoredCalculator *g_calculator = NULL;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Buffers
   SetIndexBuffer(0, BufKAMA_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufKAMA_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufUp1,       INDICATOR_DATA);
   SetIndexBuffer(3, BufDn1,       INDICATOR_DATA);
   SetIndexBuffer(4, BufUp2,       INDICATOR_DATA);
   SetIndexBuffer(5, BufDn2,       INDICATOR_DATA);
   SetIndexBuffer(6, BufUp3,       INDICATOR_DATA);
   SetIndexBuffer(7, BufDn3,       INDICATOR_DATA);

   for(int i = 0; i < 8; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufKAMA_Odd,  false);
   ArraySetAsSeries(BufKAMA_Even, false);
   ArraySetAsSeries(BufUp1,       false);
   ArraySetAsSeries(BufDn1,       false);
   ArraySetAsSeries(BufUp2,       false);
   ArraySetAsSeries(BufDn2,       false);
   ArraySetAsSeries(BufUp3,       false);
   ArraySetAsSeries(BufDn3,       false);

   ArrayInitialize(BufKAMA_Odd,  EMPTY_VALUE);
   ArrayInitialize(BufKAMA_Even, EMPTY_VALUE);
   ArrayInitialize(BufUp1,       EMPTY_VALUE);
   ArrayInitialize(BufDn1,       EMPTY_VALUE);
   ArrayInitialize(BufUp2,       EMPTY_VALUE);
   ArrayInitialize(BufDn2,       EMPTY_VALUE);
   ArrayInitialize(BufUp3,       EMPTY_VALUE);
   ArrayInitialize(BufDn3,       EMPTY_VALUE);

// 3. Configure Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetString(1,  PLOT_LABEL, "AKAMA (Segment)");

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorBand3);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColorBand3);

// 4. Initialize Anchored KAMA Engine
   g_calculator = new CKamaAnchoredCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpResetPeriod, InpTzShift, InpCustomStart, InpCustomEnd,
                         InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Anchored KAMA Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("AKAMA Bands%s%s(%s, ER%d)",
                                    ha_tag, tf_str, EnumToString(InpResetPeriod), InpErPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Helper: Compute Running Variance Bands                           |
//+------------------------------------------------------------------+
void CalculateBandsFromAKAMA(const int total_bars,
                             const double &kama_odd_arr[],
                             const double &kama_even_arr[],
                             const double &price_arr[],
                             const bool current_session_only,
                             double &up1[], double &dn1[],
                             double &up2[], double &dn2[],
                             double &up3[], double &dn3[])
  {
   ArrayInitialize(up1, EMPTY_VALUE);
   ArrayInitialize(dn1, EMPTY_VALUE);
   ArrayInitialize(up2, EMPTY_VALUE);
   ArrayInitialize(dn2, EMPTY_VALUE);
   ArrayInitialize(up3, EMPTY_VALUE);
   ArrayInitialize(dn3, EMPTY_VALUE);

// 1. Identify the Most Recent Active/Closed Session
   int most_recent_end   = -1;
   int most_recent_start = -1;

   for(int i = total_bars - 1; i >= 0; i--)
     {
      if(kama_odd_arr[i] != EMPTY_VALUE || kama_even_arr[i] != EMPTY_VALUE)
        {
         most_recent_end = i;
         break;
        }
     }

   if(most_recent_end >= 0)
     {
      bool is_odd_target = (kama_odd_arr[most_recent_end] != EMPTY_VALUE);
      most_recent_start  = most_recent_end;

      for(int i = most_recent_end; i >= 0; i--)
        {
         bool is_valid = is_odd_target ? (kama_odd_arr[i] != EMPTY_VALUE) : (kama_even_arr[i] != EMPTY_VALUE);
         if(!is_valid)
            break;
         most_recent_start = i;
        }
     }

// 2. Calculate Standard Deviation Bands
   int start_bar = (current_session_only && most_recent_start >= 0) ? most_recent_start : 0;
   int end_bar   = (current_session_only && most_recent_end >= 0) ? most_recent_end : (total_bars - 1);

   double sum_sq_dev = 0.0;
   int    count = 0;
   int    last_session_tag = 0; // 0=None, 1=Odd, 2=Even

   for(int i = start_bar; i <= end_bar; i++)
     {
      bool is_odd = (kama_odd_arr[i] != EMPTY_VALUE);
      bool is_even = (kama_even_arr[i] != EMPTY_VALUE);

      if(!is_odd && !is_even)
        {
         // In gap between sessions
         last_session_tag = 0;
         sum_sq_dev = 0.0;
         count = 0;
         continue;
        }

      int session_tag = is_odd ? 1 : 2;
      if(session_tag != last_session_tag)
        {
         sum_sq_dev = 0.0;
         count = 0;
         last_session_tag = session_tag;
        }

      double akama = is_odd ? kama_odd_arr[i] : kama_even_arr[i];
      if(akama > 0.0)
        {
         double diff = price_arr[i] - akama;
         sum_sq_dev += (diff * diff);
         count++;

         double stddev = (count > 0) ? MathSqrt(sum_sq_dev / (double)count) : 0.0;

         up1[i] = akama + (InpBand1Mult * stddev);
         dn1[i] = akama - (InpBand1Mult * stddev);
         up2[i] = akama + (InpBand2Mult * stddev);
         dn2[i] = akama - (InpBand2Mult * stddev);
         up3[i] = akama + (InpBand3Mult * stddev);
         dn3[i] = akama - (InpBand3Mult * stddev);
        }
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int required_bars = InpErPeriod + 10;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Chronological Array Safety
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      // 1. Run Anchored KAMA Engine
      g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                             BufKAMA_Odd, BufKAMA_Even, g_price_series);

      // 2. Calculate Standard Deviation Bands with Safe Lifetime Handling
      CalculateBandsFromAKAMA(rates_total, BufKAMA_Odd, BufKAMA_Even, g_price_series, InpCurrentSessionOnly,
                              BufUp1, BufDn1, BufUp2, BufDn2, BufUp3, BufDn3);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000); // Memory safeguard

      // Resize all HTF caching arrays
      ArrayResize(h_time,     g_htf_count);
      ArrayResize(h_open,     g_htf_count);
      ArrayResize(h_high,     g_htf_count);
      ArrayResize(h_low,      g_htf_count);
      ArrayResize(h_close,    g_htf_count);
      ArrayResize(h_price,    g_htf_count);
      ArrayResize(h_res_odd,  g_htf_count);
      ArrayResize(h_res_even, g_htf_count);
      ArrayResize(h_res_up1,  g_htf_count);
      ArrayResize(h_res_dn1,  g_htf_count);
      ArrayResize(h_res_up2,  g_htf_count);
      ArrayResize(h_res_dn2,  g_htf_count);
      ArrayResize(h_res_up3,  g_htf_count);
      ArrayResize(h_res_dn3,  g_htf_count);

      // Force chronological alignment
      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_price,    false);
      ArraySetAsSeries(h_res_odd,  false);
      ArraySetAsSeries(h_res_even, false);
      ArraySetAsSeries(h_res_up1,  false);
      ArraySetAsSeries(h_res_dn1,  false);
      ArraySetAsSeries(h_res_up2,  false);
      ArraySetAsSeries(h_res_dn2,  false);
      ArraySetAsSeries(h_res_up3,  false);
      ArraySetAsSeries(h_res_dn3,  false);

      // Copy pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Compute HTF Anchored KAMA Values
      g_calculator.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                             h_res_odd, h_res_even, h_price);

      // Calculate HTF Standard Deviation Bands (All HTF history computed)
      CalculateBandsFromAKAMA(g_htf_count, h_res_odd, h_res_even, h_price, false,
                              h_res_up1, h_res_dn1, h_res_up2, h_res_dn2, h_res_up3, h_res_dn3);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for the active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,  g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_time[live_idx]  = t_bar[0];
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Mock update on live bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                h_res_odd, h_res_even, h_price);

         CalculateBandsFromAKAMA(g_htf_count, h_res_odd, h_res_even, h_price, false,
                                 h_res_up1, h_res_dn1, h_res_up2, h_res_dn2, h_res_up3, h_res_dn3);
        }
     }

// 6. Forming LTF Block Flat-Force Anchor (The Staircase Solution)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++;

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// 7. Chronological Mapping Loop to Chart Timeframe
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufKAMA_Odd[i]  = h_res_odd[idx_htf];
            BufKAMA_Even[i] = h_res_even[idx_htf];
            BufUp1[i]       = h_res_up1[idx_htf];
            BufDn1[i]       = h_res_dn1[idx_htf];
            BufUp2[i]       = h_res_up2[idx_htf];
            BufDn2[i]       = h_res_dn2[idx_htf];
            BufUp3[i]       = h_res_up3[idx_htf];
            BufDn3[i]       = h_res_dn3[idx_htf];
           }
         else
           {
            BufKAMA_Odd[i] = EMPTY_VALUE;
            BufKAMA_Even[i] = EMPTY_VALUE;
            BufUp1[i] = EMPTY_VALUE;
            BufDn1[i] = EMPTY_VALUE;
            BufUp2[i] = EMPTY_VALUE;
            BufDn2[i] = EMPTY_VALUE;
            BufUp3[i] = EMPTY_VALUE;
            BufDn3[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufKAMA_Odd[i] = EMPTY_VALUE;
         BufKAMA_Even[i] = EMPTY_VALUE;
         BufUp1[i] = EMPTY_VALUE;
         BufDn1[i] = EMPTY_VALUE;
         BufUp2[i] = EMPTY_VALUE;
         BufDn2[i] = EMPTY_VALUE;
         BufUp3[i] = EMPTY_VALUE;
         BufDn3[i] = EMPTY_VALUE;
        }
     }

// 8. Mask Older Session Bands if CurrentSessionOnly is true on LTF
   if(InpCurrentSessionOnly)
     {
      int most_recent_ltf_end   = -1;
      int most_recent_ltf_start = -1;

      for(int i = rates_total - 1; i >= 0; i--)
        {
         if(BufKAMA_Odd[i] != EMPTY_VALUE || BufKAMA_Even[i] != EMPTY_VALUE)
           {
            most_recent_ltf_end = i;
            break;
           }
        }

      if(most_recent_ltf_end >= 0)
        {
         bool is_odd_target = (BufKAMA_Odd[most_recent_ltf_end] != EMPTY_VALUE);
         most_recent_ltf_start = most_recent_ltf_end;

         for(int i = most_recent_ltf_end; i >= 0; i--)
           {
            bool is_valid = is_odd_target ? (BufKAMA_Odd[i] != EMPTY_VALUE) : (BufKAMA_Even[i] != EMPTY_VALUE);
            if(!is_valid)
               break;
            most_recent_ltf_start = i;
           }

         // Wipe bands before the most recent active session
         for(int i = 0; i < most_recent_ltf_start; i++)
           {
            BufUp1[i] = EMPTY_VALUE;
            BufDn1[i] = EMPTY_VALUE;
            BufUp2[i] = EMPTY_VALUE;
            BufDn2[i] = EMPTY_VALUE;
            BufUp3[i] = EMPTY_VALUE;
            BufDn3[i] = EMPTY_VALUE;
           }
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpErPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
