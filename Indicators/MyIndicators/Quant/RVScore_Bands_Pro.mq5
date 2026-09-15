//+------------------------------------------------------------------+
//|                                           RVScore_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20"
#property description "Rolling Volume-Weighted Z-Score (RV-Score) Dynamic Bands on Main Chart."
#property description "Continuous non-segmented Gaussian volatility envelope anchored to Rolling VWAP."

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

//--- Plot 1: Centerline (Rolling VWAP)
#property indicator_label1  "Rolling VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2 & 3: Flow Bands (+/- 1.5σ)
#property indicator_label2  "Bull Flow (+1.5σ)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightSkyBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "Bear Flow (-1.5σ)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 4 & 5: Extreme Bands (+/- 2.0σ)
#property indicator_label4  "Bull Extreme (+2.0σ)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDeepSkyBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "Bear Extreme (-2.0σ)"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrangeRed
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Plot 6 & 7: Wall Bands (+/- 2.5σ)
#property indicator_label6  "Bull Wall (+2.5σ)"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMidnightBlue
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7  "Bear Wall (-2.5σ)"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrDarkRed
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- Included Core Suite Frameworks
#include <MyIncludes\Rolling_VWAP_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Candle Source Enum
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Standard OHLC Data
   CANDLE_HEIKIN_ASHI    // Heikin Ashi Smoothed Data
  };
#endif

//--- Inputs
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Rolling VWAP Engine ---"
input ENUM_ROLLING_TYPE         InpRollingType    = ROLLING_BARS;      // Rolling Window Type
input int                       InpRollingWindow  = 144;               // Rolling Window (Bars or Minutes)
input int                       InpSigmaPeriod    = 20;                // Volatility Lookback (Sigma)

input group "--- Calculation Sources ---"
input ENUM_APPLIED_VOLUME       InpVolumeType     = VOLUME_TICK;       // Applied Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource   = CANDLE_STANDARD;   // Candle Source

input group "--- RV-Score Sigma Multipliers ---"
input double                    InpLevelFlow      = 1.5;               // Flow Level (Point of Expansion)
input double                    InpLevelExtreme   = 2.0;               // Extreme Level (Climax Warning)
input double                    InpLevelWall      = 2.5;               // Wall Level (Capitulation Ceiling/Floor)

input group "--- Visual Settings - Centerline ---"
input color                     InpColorVWAP      = clrDeepSkyBlue;    // Centerline Color
input ENUM_LINE_STYLE           InpStyleVWAP      = STYLE_SOLID;       // Centerline Style
input int                       InpWidthVWAP      = 2;                 // Centerline Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Flow Bands (+/- 1.5σ) ---"
input color                     InpColorUpFlow    = clrLightSkyBlue;   // Bull Flow Color
input color                     InpColorDnFlow    = clrCoral;          // Bear Flow Color
input ENUM_LINE_STYLE           InpStyleFlow      = STYLE_SOLID;       // Flow Bands Style
input int                       InpWidthFlow      = 1;                 // Flow Bands Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Extreme Bands (+/- 2.0σ) ---"
input color                     InpColorUpExtr    = clrDeepSkyBlue;    // Bull Extreme Color
input color                     InpColorDnExtr    = clrOrangeRed;      // Bear Extreme Color
input ENUM_LINE_STYLE           InpStyleExtr      = STYLE_SOLID;       // Extreme Bands Style
input int                       InpWidthExtr      = 1;                 // Extreme Bands Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Visual Settings - Wall Bands (+/- 2.5σ) ---"
input color                     InpColorUpWall    = clrMidnightBlue;   // Bull Wall Color
input color                     InpColorDnWall    = clrDarkRed;        // Bear Wall Color
input ENUM_LINE_STYLE           InpStyleWall      = STYLE_SOLID;       // Wall Bands Style
input int                       InpWidthWall      = 1;                 // Wall Bands Width

//--- Indicator Output Buffers (7 Continuous Plots)
double BufVWAP[];
double BufUpFlow[];
double BufDnFlow[];
double BufUpExtr[];
double BufDnExtr[];
double BufUpWall[];
double BufDnWall[];

//--- Internal Dynamic Registers
double m_diff_sq_buf[];

//--- HTF Caching Arrays (Strict Chronological Non-Series Alignment)
double h_open[], h_high[], h_low[], h_close[];
long   h_tick_vol[], h_vol[];
double h_res_vwap[];
double h_res_uf[], h_res_df[];
double h_res_ue[], h_res_de[];
double h_res_uw[], h_res_dw[];
datetime h_time[];

//--- Global Engine Pointer & State Management
CRollingVWAPCalculator *g_vwap = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Guard
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("RV-Score Bands Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Buffer Bindings (7 Pure Streams)
   SetIndexBuffer(0, BufVWAP,   INDICATOR_DATA);
   SetIndexBuffer(1, BufUpFlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufDnFlow, INDICATOR_DATA);
   SetIndexBuffer(3, BufUpExtr, INDICATOR_DATA);
   SetIndexBuffer(4, BufDnExtr, INDICATOR_DATA);
   SetIndexBuffer(5, BufUpWall, INDICATOR_DATA);
   SetIndexBuffer(6, BufDnWall, INDICATOR_DATA);

   for(int i = 0; i < 7; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufVWAP,   false);
   ArraySetAsSeries(BufUpFlow, false);
   ArraySetAsSeries(BufDnFlow, false);
   ArraySetAsSeries(BufUpExtr, false);
   ArraySetAsSeries(BufDnExtr, false);
   ArraySetAsSeries(BufUpWall, false);
   ArraySetAsSeries(BufDnWall, false);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthVWAP);

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

// Data Window Dynamic Labels
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Bull Flow (+%.2fσ)", InpLevelFlow));
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("Bear Flow (-%.2fσ)", InpLevelFlow));
   PlotIndexSetString(3, PLOT_LABEL, StringFormat("Bull Extr (+%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(4, PLOT_LABEL, StringFormat("Bear Extr (-%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(5, PLOT_LABEL, StringFormat("Bull Wall (+%.2fσ)", InpLevelWall));
   PlotIndexSetString(6, PLOT_LABEL, StringFormat("Bear Wall (-%.2fσ)", InpLevelWall));

// 4. Instantiate Core Calculation Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_vwap = new CRollingVWAPCalculator_HA();
   else
      g_vwap = new CRollingVWAPCalculator();

   if(CheckPointer(g_vwap) == POINTER_INVALID)
     {
      Print("RV-Score Bands Critical Error: Failed to allocate math engine.");
      return INIT_FAILED;
     }

   if(!g_vwap.Init(InpRollingType, InpRollingWindow, InpVolumeType, true))
     {
      Print("RV-Score Bands Critical Error: Failed to initialize Rolling VWAP Engine.");
      return INIT_FAILED;
     }

// 5. Compose Indicator Shortname
   string ha_tag   = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string type_str = (InpRollingType == ROLLING_BARS) ? "Bars" : "Min";
   string short_name = StringFormat("RV-Score Bands%s%s(%d %s, %dσ)",
                                    ha_tag, tf_str,
                                    InpRollingWindow, type_str,
                                    InpSigmaPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 6. Asynchronous Background Sync Daemon for MTF
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_vwap) != POINTER_INVALID)
     {
      delete g_vwap;
      g_vwap = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Engine: Calculate Continuous RV-Score Volatility Envelope        |
//+------------------------------------------------------------------+
void CalculateRVScoreBandsEngine(const int total, const int prev_calc,
                                 const datetime &time_arr[],
                                 const double &open_arr[], const double &high_arr[],
                                 const double &low_arr[], const double &close_arr[],
                                 const long &tick_vol_arr[], const long &vol_arr[],
                                 double &vwap_out[],
                                 double &uf_out[], double &df_out[],
                                 double &ue_out[], double &de_out[],
                                 double &uw_out[], double &dw_out[],
                                 double &diff_sq_cache[])
  {
   if(total < 2 || CheckPointer(g_vwap) == POINTER_INVALID)
      return;

// 1. Calculate Continuous Underlying Rolling VWAP
   g_vwap.Calculate(total, prev_calc, time_arr, open_arr, high_arr, low_arr, close_arr,
                    tick_vol_arr, vol_arr, vwap_out);

   if(ArraySize(diff_sq_cache) != total)
     {
      ArrayResize(diff_sq_cache, total);
      ArraySetAsSeries(diff_sq_cache, false);
     }

   int start = (prev_calc > 0) ? (prev_calc - 1) : 0;

// 2. Update Squared Deviations
   for(int i = start; i < total; i++)
     {
      double diff = close_arr[i] - vwap_out[i];
      diff_sq_cache[i] = diff * diff;
     }

// 3. Project Stationary Volatility Envelopes
   for(int i = start; i < total; i++)
     {
      double cur_vwap = vwap_out[i];
      if(cur_vwap == EMPTY_VALUE || cur_vwap <= 0.0)
        {
         uf_out[i] = EMPTY_VALUE;
         df_out[i] = EMPTY_VALUE;
         ue_out[i] = EMPTY_VALUE;
         de_out[i] = EMPTY_VALUE;
         uw_out[i] = EMPTY_VALUE;
         dw_out[i] = EMPTY_VALUE;
         continue;
        }

      double sum_sq = 0.0;
      int count = 0;
      int lookback_limit = MathMin(i + 1, InpSigmaPeriod);

      for(int j = 0; j < lookback_limit; j++)
        {
         sum_sq += diff_sq_cache[i - j];
         count++;
        }

      double std_dev = (count > 0) ? MathSqrt(sum_sq / (double)count) : 0.0;

      // Project Symmetrical Sigma Envelopes
      uf_out[i] = cur_vwap + (InpLevelFlow    * std_dev);
      df_out[i] = cur_vwap - (InpLevelFlow    * std_dev);
      ue_out[i] = cur_vwap + (InpLevelExtreme * std_dev);
      de_out[i] = cur_vwap - (InpLevelExtreme * std_dev);
      uw_out[i] = cur_vwap + (InpLevelWall    * std_dev);
      dw_out[i] = cur_vwap - (InpLevelWall    * std_dev);
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation iteration                           |
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
   int required_bars = InpSigmaPeriod + 10;
   if(rates_total < required_bars || CheckPointer(g_vwap) == POINTER_INVALID)
      return 0;

// Enforce strict chronological input ordering
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Native Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      CalculateRVScoreBandsEngine(rates_total, prev_calculated,
                                  time, open, high, low, close,
                                  tick_volume, volume,
                                  BufVWAP,
                                  BufUpFlow, BufDnFlow,
                                  BufUpExtr, BufDnExtr,
                                  BufUpWall, BufDnWall,
                                  m_diff_sq_buf);
      return rates_total;
     }

//===================================================================
// MODE 2: Synchronized MTF Engine (Warp-free Step Synchronization)
//===================================================================
   int htf_required = (InpRollingType == ROLLING_BARS) ? (InpRollingWindow + InpSigmaPeriod + 10) : (InpSigmaPeriod + 50);
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, htf_required))
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
      if(htf_bars < htf_required)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000); // Enterprise memory safeguard

      // Resize all HTF caching structures
      ArrayResize(h_time,     g_htf_count);
      ArrayResize(h_open,     g_htf_count);
      ArrayResize(h_high,     g_htf_count);
      ArrayResize(h_low,      g_htf_count);
      ArrayResize(h_close,    g_htf_count);
      ArrayResize(h_tick_vol, g_htf_count);
      ArrayResize(h_vol,      g_htf_count);
      ArrayResize(h_res_vwap, g_htf_count);
      ArrayResize(h_res_uf,   g_htf_count);
      ArrayResize(h_res_df,   g_htf_count);
      ArrayResize(h_res_ue,   g_htf_count);
      ArrayResize(h_res_de,   g_htf_count);
      ArrayResize(h_res_uw,   g_htf_count);
      ArrayResize(h_res_dw,   g_htf_count);

      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_tick_vol, false);
      ArraySetAsSeries(h_vol,      false);
      ArraySetAsSeries(h_res_vwap, false);
      ArraySetAsSeries(h_res_uf,   false);
      ArraySetAsSeries(h_res_df,   false);
      ArraySetAsSeries(h_res_ue,   false);
      ArraySetAsSeries(h_res_de,   false);
      ArraySetAsSeries(h_res_uw,   false);
      ArraySetAsSeries(h_res_dw,   false);

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

      double htf_diff_sq[];
      ArrayResize(htf_diff_sq, g_htf_count);
      ArraySetAsSeries(htf_diff_sq, false);

      // Compute Synchronized HTF Bands
      CalculateRVScoreBandsEngine(g_htf_count, 0,
                                  h_time, h_open, h_high, h_low, h_close,
                                  h_tick_vol, h_vol,
                                  h_res_vwap,
                                  h_res_uf, h_res_df,
                                  h_res_ue, h_res_de,
                                  h_res_uw, h_res_dw,
                                  htf_diff_sq);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= htf_required)
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

         double htf_diff_sq[];
         ArrayResize(htf_diff_sq, g_htf_count);
         ArraySetAsSeries(htf_diff_sq, false);

         // Mock update on live bar
         CalculateRVScoreBandsEngine(g_htf_count, g_htf_count,
                                     h_time, h_open, h_high, h_low, h_close,
                                     h_tick_vol, h_vol,
                                     h_res_vwap,
                                     h_res_uf, h_res_df,
                                     h_res_ue, h_res_de,
                                     h_res_uw, h_res_dw,
                                     htf_diff_sq);
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

// 7. Chronological Mapping Loop to Chart Timeframe (7 Continuous Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufVWAP[i]   = h_res_vwap[idx_htf];
            BufUpFlow[i] = h_res_uf[idx_htf];
            BufDnFlow[i] = h_res_df[idx_htf];
            BufUpExtr[i] = h_res_ue[idx_htf];
            BufDnExtr[i] = h_res_de[idx_htf];
            BufUpWall[i] = h_res_uw[idx_htf];
            BufDnWall[i] = h_res_dw[idx_htf];
           }
         else
           {
            BufVWAP[i]   = EMPTY_VALUE;
            BufUpFlow[i] = EMPTY_VALUE;
            BufDnFlow[i] = EMPTY_VALUE;
            BufUpExtr[i] = EMPTY_VALUE;
            BufDnExtr[i] = EMPTY_VALUE;
            BufUpWall[i] = EMPTY_VALUE;
            BufDnWall[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufVWAP[i]   = EMPTY_VALUE;
         BufUpFlow[i] = EMPTY_VALUE;
         BufDnFlow[i] = EMPTY_VALUE;
         BufUpExtr[i] = EMPTY_VALUE;
         BufDnExtr[i] = EMPTY_VALUE;
         BufUpWall[i] = EMPTY_VALUE;
         BufDnWall[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int htf_required = (InpRollingType == ROLLING_BARS) ? (InpRollingWindow + InpSigmaPeriod + 10) : (InpSigmaPeriod + 50);
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, htf_required, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
