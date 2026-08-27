//+------------------------------------------------------------------+
//|                                             KScore_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // First release of Continuous Rolling K-Score Bands
#property description "Statistical K-Score Projected Dynamic Bands on Main Chart (Rolling Gaussian Envelope around KAMA)."
#property description "Features continuous 7-buffer architecture with unified Native & MTF support."

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

//--- Plot 1: KAMA Centerline
#property indicator_label1  "KAMA Middle"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Upper Flow Band (+1.5σ)
#property indicator_label2  "Bull Flow"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightSkyBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Lower Flow Band (-1.5σ)
#property indicator_label3  "Bear Flow"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 4: Upper Extreme Band (+2.0σ)
#property indicator_label4  "Bull Extreme"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDeepSkyBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5: Lower Extreme Band (-2.0σ)
#property indicator_label5  "Bear Extreme"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrangeRed
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Plot 6: Upper Wall Band (+2.5σ)
#property indicator_label6  "Bull Wall"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMidnightBlue
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7: Lower Wall Band (-2.5σ)
#property indicator_label7  "Bear Wall"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrDarkRed
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- Included Engines & Central Tools
#include <MyIncludes\KAMA_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe            = PERIOD_CURRENT;        // Calculation Timeframe (Current or HTF)

input group "--- KAMA Core Settings ---"
input int                       InpErPeriod             = 10;                    // Efficiency Ratio Period
input int                       InpFastEmaPeriod        = 2;                     // Fastest EMA Period
input int                       InpSlowEmaPeriod        = 30;                    // Slowest EMA Period
input int                       InpStDevPeriod          = 20;                    // Volatility Lookback Period (Sigma)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice          = PRICE_CLOSE_STD;       // Price Source (Standard / HA)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- K-Score Z-Levels (Standard Deviations) ---"
input double                    InpLevelFlow            = 1.5;                   // Flow Level (Warning)
input double                    InpLevelExtreme         = 2.0;                   // Extreme Level (Climax)
input double                    InpLevelWall            = 2.5;                   // Wall Level (Exhaustion)

input group "--- Visual Settings - Centerline ---"
input color                     InpColorKAMA            = clrCrimson;            // KAMA Centerline Color
input ENUM_LINE_STYLE           InpStyleKAMA            = STYLE_SOLID;           // KAMA Centerline Style
input int                       InpWidthKAMA            = 2;                     // KAMA Centerline Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Flow Bands (+/- 1.5σ) ---"
input color                     InpColorUpFlow          = clrLightSkyBlue;       // Bull Flow Color
input color                     InpColorDnFlow          = clrCoral;              // Bear Flow Color
input ENUM_LINE_STYLE           InpStyleFlow            = STYLE_SOLID;           // Flow Bands Style
input int                       InpWidthFlow            = 1;                     // Flow Bands Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Extreme Bands (+/- 2.0σ) ---"
input color                     InpColorUpExtr          = clrDeepSkyBlue;        // Bull Extreme Color
input color                     InpColorDnExtr          = clrOrangeRed;          // Bear Extreme Color
input ENUM_LINE_STYLE           InpStyleExtr            = STYLE_SOLID;           // Extreme Bands Style
input int                       InpWidthExtr            = 1;                     // Extreme Bands Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Wall Bands (+/- 2.5σ) ---"
input color                     InpColorUpWall          = clrMidnightBlue;       // Bull Wall Color
input color                     InpColorDnWall          = clrDarkRed;            // Bear Wall Color
input ENUM_LINE_STYLE           InpStyleWall            = STYLE_SOLID;           // Wall Bands Style
input int                       InpWidthWall            = 1;                     // Wall Bands Width

//--- Indicator Buffers (7)
double BufferMiddle[];
double BufferUpFlow[];
double BufferDnFlow[];
double BufferUpExtr[];
double BufferDnExtr[];
double BufferUpWall[];
double BufferDnWall[];

//--- Internal State Buffers
double m_price_cache[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[];
double h_res_middle[];
double h_res_up_flow[], h_res_dn_flow[];
double h_res_up_extr[], h_res_dn_extr[];
double h_res_up_wall[], h_res_dn_wall[];
datetime h_time[];

//--- Global Objects & State Management
CKamaCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufferMiddle, INDICATOR_DATA);
   SetIndexBuffer(1, BufferUpFlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufferDnFlow, INDICATOR_DATA);
   SetIndexBuffer(3, BufferUpExtr, INDICATOR_DATA);
   SetIndexBuffer(4, BufferDnExtr, INDICATOR_DATA);
   SetIndexBuffer(5, BufferUpWall, INDICATOR_DATA);
   SetIndexBuffer(6, BufferDnWall, INDICATOR_DATA);

   for(int i = 0; i < 7; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufferMiddle, false);
   ArraySetAsSeries(BufferUpFlow, false);
   ArraySetAsSeries(BufferDnFlow, false);
   ArraySetAsSeries(BufferUpExtr, false);
   ArraySetAsSeries(BufferDnExtr, false);
   ArraySetAsSeries(BufferUpWall, false);
   ArraySetAsSeries(BufferDnWall, false);

   ArrayInitialize(BufferMiddle, EMPTY_VALUE);
   ArrayInitialize(BufferUpFlow, EMPTY_VALUE);
   ArrayInitialize(BufferDnFlow, EMPTY_VALUE);
   ArrayInitialize(BufferUpExtr, EMPTY_VALUE);
   ArrayInitialize(BufferDnExtr, EMPTY_VALUE);
   ArrayInitialize(BufferUpWall, EMPTY_VALUE);
   ArrayInitialize(BufferDnWall, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorUpFlow);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthFlow);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorDnFlow);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthFlow);

   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorUpExtr);
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpWidthExtr);

   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorDnExtr);
   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpWidthExtr);

   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorUpWall);
   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpWidthWall);

   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorDnWall);
   PlotIndexSetInteger(6, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpWidthWall);

// Labels for Data Window
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Bull Flow (+%.2fσ)", InpLevelFlow));
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("Bear Flow (-%.2fσ)", InpLevelFlow));
   PlotIndexSetString(3, PLOT_LABEL, StringFormat("Bull Extr (+%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(4, PLOT_LABEL, StringFormat("Bear Extr (-%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(5, PLOT_LABEL, StringFormat("Bull Wall (+%.2fσ)", InpLevelWall));
   PlotIndexSetString(6, PLOT_LABEL, StringFormat("Bear Wall (-%.2fσ)", InpLevelWall));

// 4. Initialize KAMA Engine
   g_calculator = new CKamaCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize KAMA Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("K-Score Bands%s%s(ER%d, σ%d)",
                                    ha_tag, tf_str, InpErPeriod, InpStDevPeriod);
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
//| Helper: Compute Continuous Rolling K-Score Bands                 |
//+------------------------------------------------------------------+
void CalculateKScoreBandsEngine(const int total, const int prev_calc,
                                const double &open_arr[], const double &high_arr[],
                                const double &low_arr[], const double &close_arr[],
                                double &kama_arr[], double &price_cache[],
                                double &uf_arr[], double &df_arr[],
                                double &ue_arr[], double &de_arr[],
                                double &uw_arr[], double &dw_arr[])
  {
   int warmup = MathMax(InpErPeriod, InpStDevPeriod);
   if(total <= warmup)
      return;

// 1. Calculate Underlying KAMA Baseline
   g_calculator.Calculate(total, prev_calc, open_arr, high_arr, low_arr, close_arr, kama_arr);

   int start = (prev_calc > warmup) ? (prev_calc - 1) : warmup;
   if(start < warmup)
      start = warmup;

// 2. Project Rolling Standard Deviation Bands
   for(int i = start; i < total; i++)
     {
      price_cache[i] = close_arr[i];
      double cur_kama = kama_arr[i];

      if(cur_kama == EMPTY_VALUE || cur_kama <= 0.0)
        {
         uf_arr[i] = EMPTY_VALUE;
         df_arr[i] = EMPTY_VALUE;
         ue_arr[i] = EMPTY_VALUE;
         de_arr[i] = EMPTY_VALUE;
         uw_arr[i] = EMPTY_VALUE;
         dw_arr[i] = EMPTY_VALUE;
         continue;
        }

      // Compute Rolling Variance of (Price - KAMA)
      double sum_sq_diff = 0.0;
      for(int k = 0; k < InpStDevPeriod; k++)
        {
         int idx = i - k;
         double p = price_cache[idx];
         double v = kama_arr[idx];

         if(v == EMPTY_VALUE || v <= 0.0)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / (double)InpStDevPeriod);

      uf_arr[i] = cur_kama + (InpLevelFlow * std_dev);
      df_arr[i] = cur_kama - (InpLevelFlow * std_dev);
      ue_arr[i] = cur_kama + (InpLevelExtreme * std_dev);
      de_arr[i] = cur_kama - (InpLevelExtreme * std_dev);
      uw_arr[i] = cur_kama + (InpLevelWall * std_dev);
      dw_arr[i] = cur_kama - (InpLevelWall * std_dev);
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
   int warmup = MathMax(InpErPeriod, InpStDevPeriod);
   if(rates_total <= warmup || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing
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
      if(ArraySize(m_price_cache) != rates_total)
        {
         ArrayResize(m_price_cache, rates_total);
         ArraySetAsSeries(m_price_cache, false);
        }

      CalculateKScoreBandsEngine(rates_total, prev_calculated, open, high, low, close,
                                 BufferMiddle, m_price_cache,
                                 BufferUpFlow, BufferDnFlow,
                                 BufferUpExtr, BufferDnExtr,
                                 BufferUpWall, BufferDnWall);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   int required_bars = warmup + 10;
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

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      ArrayResize(h_time,        g_htf_count);
      ArrayResize(h_open,        g_htf_count);
      ArrayResize(h_high,        g_htf_count);
      ArrayResize(h_low,         g_htf_count);
      ArrayResize(h_close,       g_htf_count);
      ArrayResize(h_res_middle,  g_htf_count);
      ArrayResize(h_res_up_flow, g_htf_count);
      ArrayResize(h_res_dn_flow, g_htf_count);
      ArrayResize(h_res_up_extr, g_htf_count);
      ArrayResize(h_res_dn_extr, g_htf_count);
      ArrayResize(h_res_up_wall, g_htf_count);
      ArrayResize(h_res_dn_wall, g_htf_count);

      ArraySetAsSeries(h_time,        false);
      ArraySetAsSeries(h_open,        false);
      ArraySetAsSeries(h_high,        false);
      ArraySetAsSeries(h_low,         false);
      ArraySetAsSeries(h_close,       false);
      ArraySetAsSeries(h_res_middle,  false);
      ArraySetAsSeries(h_res_up_flow, false);
      ArraySetAsSeries(h_res_dn_flow, false);
      ArraySetAsSeries(h_res_up_extr, false);
      ArraySetAsSeries(h_res_dn_extr, false);
      ArraySetAsSeries(h_res_up_wall, false);
      ArraySetAsSeries(h_res_dn_wall, false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      double h_price[];
      ArrayResize(h_price, g_htf_count);
      ArraySetAsSeries(h_price, false);

      // Compute HTF Rolling K-Score Bands
      CalculateKScoreBandsEngine(g_htf_count, 0, h_open, h_high, h_low, h_close,
                                 h_res_middle, h_price,
                                 h_res_up_flow, h_res_dn_flow,
                                 h_res_up_extr, h_res_dn_extr,
                                 h_res_up_wall, h_res_dn_wall);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         double h_price[];
         ArrayResize(h_price, g_htf_count);
         ArraySetAsSeries(h_price, false);

         // Mock update on live HTF bar
         CalculateKScoreBandsEngine(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close,
                                    h_res_middle, h_price,
                                    h_res_up_flow, h_res_dn_flow,
                                    h_res_up_extr, h_res_dn_extr,
                                    h_res_up_wall, h_res_dn_wall);
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

// 7. Chronological Mapping Loop to Chart Timeframe (7 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferMiddle[i] = h_res_middle[idx_htf];
            BufferUpFlow[i] = h_res_up_flow[idx_htf];
            BufferDnFlow[i] = h_res_dn_flow[idx_htf];
            BufferUpExtr[i] = h_res_up_extr[idx_htf];
            BufferDnExtr[i] = h_res_dn_extr[idx_htf];
            BufferUpWall[i] = h_res_up_wall[idx_htf];
            BufferDnWall[i] = h_res_dn_wall[idx_htf];
           }
         else
           {
            BufferMiddle[i] = EMPTY_VALUE;
            BufferUpFlow[i] = EMPTY_VALUE;
            BufferDnFlow[i] = EMPTY_VALUE;
            BufferUpExtr[i] = EMPTY_VALUE;
            BufferDnExtr[i] = EMPTY_VALUE;
            BufferUpWall[i] = EMPTY_VALUE;
            BufferDnWall[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferMiddle[i] = EMPTY_VALUE;
         BufferUpFlow[i] = EMPTY_VALUE;
         BufferDnFlow[i] = EMPTY_VALUE;
         BufferUpExtr[i] = EMPTY_VALUE;
         BufferDnExtr[i] = EMPTY_VALUE;
         BufferUpWall[i] = EMPTY_VALUE;
         BufferDnWall[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpErPeriod, InpStDevPeriod);
   int required_bars = warmup + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
