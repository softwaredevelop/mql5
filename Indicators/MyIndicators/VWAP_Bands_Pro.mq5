//+------------------------------------------------------------------+
//|                                               VWAP_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with Robust Volume-Weighted Dispersion
#property description "Volume Weighted Average Price (VWAP) with Volume-Weighted Standard Deviation Bands."
#property description "Features unified Native & MTF pipelines, odd/even gapped lines, and session focus."

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot 1-2: VWAP (Odd/Even for Gapped Drawing)
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

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
#include <MyIncludes\VWAP_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting candle source ---
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };
#endif

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe            = PERIOD_CURRENT;        // Calculation Timeframe (Current or HTF)

input group "--- VWAP Settings ---"
input ENUM_VWAP_PERIOD          InpResetPeriod          = PERIOD_SESSION;        // Reset Period
input int                       InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string                    InpCustomSessionStart   = "09:30";               // Start time (HH:MM) for Custom Session
input string                    InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

input group "--- Calculation Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;       // Candle Source

input group "--- Bands Settings ---"
input double                    InpBand1Mult            = 1.0;                   // Band 1 Multiplier (Sigma)
input double                    InpBand2Mult            = 2.0;                   // Band 2 Multiplier (Sigma)
input double                    InpBand3Mult            = 3.0;                   // Band 3 Multiplier (Sigma)
input bool                      InpCurrentSessionOnly   = true;                  // Display Bands for Most Recent Session Only?

input group "--- Visual Settings - VWAP Centerline ---"
input color                     InpColorVWAP            = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleVWAP            = STYLE_SOLID;           // Centerline Style
input int                       InpWidthVWAP            = 2;                     // Centerline Width

input group "--- Visual Settings - Bands Colors ---"
input color                     InpColorBand1           = clrDodgerBlue;         // Band 1 Color (+/- 1σ)
input color                     InpColorBand2           = clrCoral;              // Band 2 Color (+/- 2σ)
input color                     InpColorBand3           = clrCrimson;            // Band 3 Color (+/- 3σ)

//--- Visual Indicator Buffers ---
double BufVWAP_Odd[];
double BufVWAP_Even[];
double BufUp1[], BufDn1[];
double BufUp2[], BufDn2[];
double BufUp3[], BufDn3[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
double   h_res_odd[], h_res_even[];
double   h_res_up1[], h_res_dn1[];
double   h_res_up2[], h_res_dn2[];
double   h_res_up3[], h_res_dn3[];
datetime h_time[];

//--- Global Objects & State Management
CVWAPCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufVWAP_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufVWAP_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufUp1,       INDICATOR_DATA);
   SetIndexBuffer(3, BufDn1,       INDICATOR_DATA);
   SetIndexBuffer(4, BufUp2,       INDICATOR_DATA);
   SetIndexBuffer(5, BufDn2,       INDICATOR_DATA);
   SetIndexBuffer(6, BufUp3,       INDICATOR_DATA);
   SetIndexBuffer(7, BufDn3,       INDICATOR_DATA);

   for(int i = 0; i < 8; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufVWAP_Odd,  false);
   ArraySetAsSeries(BufVWAP_Even, false);
   ArraySetAsSeries(BufUp1,       false);
   ArraySetAsSeries(BufDn1,       false);
   ArraySetAsSeries(BufUp2,       false);
   ArraySetAsSeries(BufDn2,       false);
   ArraySetAsSeries(BufUp3,       false);
   ArraySetAsSeries(BufDn3,       false);

   ArrayInitialize(BufVWAP_Odd,  EMPTY_VALUE);
   ArrayInitialize(BufVWAP_Even, EMPTY_VALUE);
   ArrayInitialize(BufUp1,       EMPTY_VALUE);
   ArrayInitialize(BufDn1,       EMPTY_VALUE);
   ArrayInitialize(BufUp2,       EMPTY_VALUE);
   ArrayInitialize(BufDn2,       EMPTY_VALUE);
   ArrayInitialize(BufUp3,       EMPTY_VALUE);
   ArrayInitialize(BufDn3,       EMPTY_VALUE);

// 3. Configure Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthVWAP);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthVWAP);
   PlotIndexSetString(1,  PLOT_LABEL, "VWAP (Segment)");

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorBand3);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColorBand3);

// 4. Initialize Core Calculator Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CVWAPCalculator_HA();
   else
      g_calculator = new CVWAPCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to create VWAP Calculator object.");
      return INIT_FAILED;
     }

   bool init_success = false;
   if(InpResetPeriod == PERIOD_CUSTOM_SESSION)
      init_success = g_calculator.Init(InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, true, 0, InpTzShift);
   else
      init_success = g_calculator.Init(InpResetPeriod, InpVolumeType, InpTzShift, true, 0);

   if(!init_success)
     {
      Print("Critical Error: Failed to initialize VWAP Calculator logic.");
      return INIT_FAILED;
     }

   string ha_tag = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("VWAP Bands%s%s(%s)", ha_tag, tf_str, EnumToString(InpResetPeriod));
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
//| Helper: Compute Volume-Weighted Standard Deviation Bands         |
//+------------------------------------------------------------------+
void CalculateVWAPBands(const int total_bars,
                        const double &open_arr[],
                        const double &high_arr[],
                        const double &low_arr[],
                        const double &close_arr[],
                        const long &tick_vol_arr[],
                        const long &vol_arr[],
                        const ENUM_APPLIED_VOLUME vol_type,
                        const double &vwap_odd_arr[],
                        const double &vwap_even_arr[],
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

// 1. Identify Most Recent Session Range
   int most_recent_end   = -1;
   int most_recent_start = -1;

   for(int i = total_bars - 1; i >= 0; i--)
     {
      if(vwap_odd_arr[i] != EMPTY_VALUE || vwap_even_arr[i] != EMPTY_VALUE)
        {
         most_recent_end = i;
         break;
        }
     }

   if(most_recent_end >= 0)
     {
      bool is_odd_target = (vwap_odd_arr[most_recent_end] != EMPTY_VALUE);
      most_recent_start  = most_recent_end;

      for(int i = most_recent_end; i >= 0; i--)
        {
         bool is_valid = is_odd_target ? (vwap_odd_arr[i] != EMPTY_VALUE) : (vwap_even_arr[i] != EMPTY_VALUE);
         if(!is_valid)
            break;
         most_recent_start = i;
        }
     }

// 2. Calculate Running Volume-Weighted Standard Deviation
   int start_bar = (current_session_only && most_recent_start >= 0) ? most_recent_start : 0;
   int end_bar   = (current_session_only && most_recent_end >= 0) ? most_recent_end : (total_bars - 1);

   double cum_vol  = 0.0;
   double cum_tpv2 = 0.0;
   int    last_session_tag = 0; // 0=None, 1=Odd, 2=Even

   for(int i = start_bar; i <= end_bar; i++)
     {
      bool is_odd  = (vwap_odd_arr[i]  != EMPTY_VALUE);
      bool is_even = (vwap_even_arr[i] != EMPTY_VALUE);

      if(!is_odd && !is_even)
        {
         last_session_tag = 0;
         cum_vol  = 0.0;
         cum_tpv2 = 0.0;
         continue;
        }

      int session_tag = is_odd ? 1 : 2;
      if(session_tag != last_session_tag)
        {
         cum_vol  = 0.0;
         cum_tpv2 = 0.0;
         last_session_tag = session_tag;
        }

      double vwap = is_odd ? vwap_odd_arr[i] : vwap_even_arr[i];

      if(vwap != EMPTY_VALUE && vwap > 0.0)
        {
         double tp = (high_arr[i] + low_arr[i] + close_arr[i]) / 3.0;
         long v_raw = (vol_type == VOLUME_REAL) ? vol_arr[i] : tick_vol_arr[i];
         double vol = (v_raw < 1) ? 1.0 : (double)v_raw;

         cum_vol  += vol;
         cum_tpv2 += (tp * tp) * vol;

         if(cum_vol > 0.0)
           {
            // Variance = E[P^2] - (E[P])^2
            double variance = (cum_tpv2 / cum_vol) - (vwap * vwap);
            double stddev = (variance > 0.0) ? MathSqrt(variance) : 0.0;

            up1[i] = vwap + (InpBand1Mult * stddev);
            dn1[i] = vwap - (InpBand1Mult * stddev);
            up2[i] = vwap + (InpBand2Mult * stddev);
            dn2[i] = vwap - (InpBand2Mult * stddev);
            up3[i] = vwap + (InpBand3Mult * stddev);
            dn3[i] = vwap - (InpBand3Mult * stddev);
           }
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
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing on current timeframe arrays
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      // 1. Calculate VWAP Odd/Even Lines
      g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                             tick_volume, volume, BufVWAP_Odd, BufVWAP_Even);

      // 2. Calculate Running Volume-Weighted Standard Deviation Bands
      CalculateVWAPBands(rates_total, open, high, low, close, tick_volume, volume, InpVolumeType,
                         BufVWAP_Odd, BufVWAP_Even, InpCurrentSessionOnly,
                         BufUp1, BufDn1, BufUp2, BufDn2, BufUp3, BufDn3);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   int required_bars = 10;
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
      ArrayResize(h_tick_vol, g_htf_count);
      ArrayResize(h_vol,      g_htf_count);
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
      ArraySetAsSeries(h_tick_vol, false);
      ArraySetAsSeries(h_vol,      false);
      ArraySetAsSeries(h_res_odd,  false);
      ArraySetAsSeries(h_res_even, false);
      ArraySetAsSeries(h_res_up1,  false);
      ArraySetAsSeries(h_res_dn1,  false);
      ArraySetAsSeries(h_res_up2,  false);
      ArraySetAsSeries(h_res_dn2,  false);
      ArraySetAsSeries(h_res_up3,  false);
      ArraySetAsSeries(h_res_dn3,  false);

      // Copy pricing & volume data
      if(CopyTime(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_time)     != g_htf_count ||
         CopyOpen(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_open)     != g_htf_count ||
         CopyHigh(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_high)     != g_htf_count ||
         CopyLow(_Symbol,        g_calc_timeframe, 0, g_htf_count, h_low)      != g_htf_count ||
         CopyClose(_Symbol,      g_calc_timeframe, 0, g_htf_count, h_close)    != g_htf_count ||
         CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_tick_vol) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
         CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);
      else
         ArrayCopy(h_vol, h_tick_vol, 0, 0, g_htf_count);

      // Compute HTF VWAP Values
      g_calculator.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                             h_tick_vol, h_vol, h_res_odd, h_res_even);

      // Calculate HTF Bands
      CalculateVWAPBands(g_htf_count, h_open, h_high, h_low, h_close, h_tick_vol, h_vol, InpVolumeType,
                         h_res_odd, h_res_even, false,
                         h_res_up1, h_res_dn1, h_res_up2, h_res_dn2, h_res_up3, h_res_dn3);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];
      long tv[1], v[1];

      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,       g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,       g_calc_timeframe, shift, 1, o)     == 1 &&
         CopyHigh(_Symbol,       g_calc_timeframe, shift, 1, h)     == 1 &&
         CopyLow(_Symbol,        g_calc_timeframe, shift, 1, l)     == 1 &&
         CopyClose(_Symbol,      g_calc_timeframe, shift, 1, c)     == 1 &&
         CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, tv)    == 1)
        {
         h_time[live_idx]     = t_bar[0];
         h_open[live_idx]     = o[0];
         h_high[live_idx]     = h[0];
         h_low[live_idx]      = l[0];
         h_close[live_idx]    = c[0];
         h_tick_vol[live_idx] = tv[0];

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = v[0];
         else
            h_vol[live_idx] = tv[0];

         // Mock update on live bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                h_tick_vol, h_vol, h_res_odd, h_res_even);

         CalculateVWAPBands(g_htf_count, h_open, h_high, h_low, h_close, h_tick_vol, h_vol, InpVolumeType,
                            h_res_odd, h_res_even, false,
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
            BufVWAP_Odd[i]  = h_res_odd[idx_htf];
            BufVWAP_Even[i] = h_res_even[idx_htf];
            BufUp1[i]       = h_res_up1[idx_htf];
            BufDn1[i]       = h_res_dn1[idx_htf];
            BufUp2[i]       = h_res_up2[idx_htf];
            BufDn2[i]       = h_res_dn2[idx_htf];
            BufUp3[i]       = h_res_up3[idx_htf];
            BufDn3[i]       = h_res_dn3[idx_htf];
           }
         else
           {
            BufVWAP_Odd[i] = EMPTY_VALUE;
            BufVWAP_Even[i] = EMPTY_VALUE;
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
         BufVWAP_Odd[i] = EMPTY_VALUE;
         BufVWAP_Even[i] = EMPTY_VALUE;
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
         if(BufVWAP_Odd[i] != EMPTY_VALUE || BufVWAP_Even[i] != EMPTY_VALUE)
           {
            most_recent_ltf_end = i;
            break;
           }
        }

      if(most_recent_ltf_end >= 0)
        {
         bool is_odd_target = (BufVWAP_Odd[most_recent_ltf_end] != EMPTY_VALUE);
         most_recent_ltf_start = most_recent_ltf_end;

         for(int i = most_recent_ltf_end; i >= 0; i--)
           {
            bool is_valid = is_odd_target ? (BufVWAP_Odd[i] != EMPTY_VALUE) : (BufVWAP_Even[i] != EMPTY_VALUE);
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
   int required_bars = 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
