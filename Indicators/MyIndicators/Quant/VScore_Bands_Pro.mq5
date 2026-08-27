//+------------------------------------------------------------------+
//|                                             VScore_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with 14-Buffer Synchronized Gapped Engine
#property description "V-Score Projected Dynamic Bands on Main Chart (Rolling Gaussian Envelope around VWAP)."
#property description "Features unified Native & MTF pipelines, custom sessions, and swapped thermal colors."

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   14

//--- Plot 1 & 2: VWAP Base (Odd / Even)
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

//--- Plot 3 & 4: Upper Flow Band (+1.5σ)
#property indicator_label3  "Bull Flow"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLightSkyBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  ""
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLightSkyBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5 & 6: Lower Flow Band (-1.5σ)
#property indicator_label5  "Bear Flow"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCoral
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  ""
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCoral
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7 & 8: Upper Extreme Band (+2.0σ)
#property indicator_label7  "Bull Extreme"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrDeepSkyBlue
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  ""
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrDeepSkyBlue
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Plot 9 & 10: Lower Extreme Band (-2.0σ)
#property indicator_label9  "Bear Extreme"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrOrangeRed
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

#property indicator_label10 ""
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrOrangeRed
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//--- Plot 11 & 12: Upper Wall Band (+2.5σ)
#property indicator_label11 "Bull Wall"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrMidnightBlue
#property indicator_style11 STYLE_SOLID
#property indicator_width11 1

#property indicator_label12 ""
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrMidnightBlue
#property indicator_style12 STYLE_SOLID
#property indicator_width12 1

//--- Plot 13 & 14: Lower Wall Band (-2.5σ)
#property indicator_label13 "Bear Wall"
#property indicator_type13  DRAW_LINE
#property indicator_color13 clrDarkRed
#property indicator_style13 STYLE_SOLID
#property indicator_width13 1

#property indicator_label14 ""
#property indicator_type14  DRAW_LINE
#property indicator_color14 clrDarkRed
#property indicator_style14 STYLE_SOLID
#property indicator_width14 1

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

input group "--- V-Score Core Settings ---"
input int                       InpPeriod               = 20;                    // Volatility Lookback (Sigma)
input ENUM_VWAP_PERIOD          InpVWAPReset            = PERIOD_SESSION;        // VWAP Anchor Reset
input int                       InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string                    InpCustomSessionStart   = "09:30";               // Start time (HH:MM) for Custom Session
input string                    InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

input group "--- Calculation Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;       // Candle Source

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- V-Score Z-Levels (Standard Deviations) ---"
input double                    InpLevelFlow            = 1.5;                   // Flow Level (Point of No Return)
input double                    InpLevelExtreme         = 2.0;                   // Extreme Level (Warning)
input double                    InpLevelWall            = 2.5;                   // Wall Level (Climax Exhaustion)

input group "--- Visual Settings - Centerline ---"
input color                     InpColorVWAP            = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleVWAP            = STYLE_SOLID;           // Centerline Style
input int                       InpWidthVWAP            = 2;                     // Centerline Width

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

//--- Indicator Buffers (14)
double BufVWAP_Odd[],   BufVWAP_Even[];
double BufUpFlow_Odd[], BufUpFlow_Even[];
double BufDnFlow_Odd[], BufDnFlow_Even[];
double BufUpExtr_Odd[], BufUpExtr_Even[];
double BufDnExtr_Odd[], BufDnExtr_Even[];
double BufUpWall_Odd[], BufUpWall_Even[];
double BufDnWall_Odd[], BufDnWall_Even[];

//--- Internal State Buffers
double m_vwap_odd[];
double m_vwap_even[];
double m_merged_vwap[];
double m_price_buf[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[];
long   h_tick_vol[], h_vol[];
double h_res_odd[], h_res_even[];
double h_res_uf_odd[], h_res_uf_even[];
double h_res_df_odd[], h_res_df_even[];
double h_res_ue_odd[], h_res_ue_even[];
double h_res_de_odd[], h_res_de_even[];
double h_res_uw_odd[], h_res_uw_even[];
double h_res_dw_odd[], h_res_dw_even[];
datetime h_time[];

//--- Global Objects & State Management
CVWAPCalculator *g_vwap = NULL;

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
   SetIndexBuffer(0,  BufVWAP_Odd,    INDICATOR_DATA);
   SetIndexBuffer(1,  BufVWAP_Even,   INDICATOR_DATA);
   SetIndexBuffer(2,  BufUpFlow_Odd,  INDICATOR_DATA);
   SetIndexBuffer(3,  BufUpFlow_Even, INDICATOR_DATA);
   SetIndexBuffer(4,  BufDnFlow_Odd,  INDICATOR_DATA);
   SetIndexBuffer(5,  BufDnFlow_Even, INDICATOR_DATA);
   SetIndexBuffer(6,  BufUpExtr_Odd,  INDICATOR_DATA);
   SetIndexBuffer(7,  BufUpExtr_Even, INDICATOR_DATA);
   SetIndexBuffer(8,  BufDnExtr_Odd,  INDICATOR_DATA);
   SetIndexBuffer(9,  BufDnExtr_Even, INDICATOR_DATA);
   SetIndexBuffer(10, BufUpWall_Odd,  INDICATOR_DATA);
   SetIndexBuffer(11, BufUpWall_Even, INDICATOR_DATA);
   SetIndexBuffer(12, BufDnWall_Odd,  INDICATOR_DATA);
   SetIndexBuffer(13, BufDnWall_Even, INDICATOR_DATA);

   for(int i = 0; i < 14; i++)
     {
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }

   ArraySetAsSeries(BufVWAP_Odd,    false);
   ArraySetAsSeries(BufVWAP_Even,   false);
   ArraySetAsSeries(BufUpFlow_Odd,  false);
   ArraySetAsSeries(BufUpFlow_Even, false);
   ArraySetAsSeries(BufDnFlow_Odd,  false);
   ArraySetAsSeries(BufDnFlow_Even, false);
   ArraySetAsSeries(BufUpExtr_Odd,  false);
   ArraySetAsSeries(BufUpExtr_Even, false);
   ArraySetAsSeries(BufDnExtr_Odd,  false);
   ArraySetAsSeries(BufDnExtr_Even, false);
   ArraySetAsSeries(BufUpWall_Odd,  false);
   ArraySetAsSeries(BufUpWall_Even, false);
   ArraySetAsSeries(BufDnWall_Odd,  false);
   ArraySetAsSeries(BufDnWall_Even, false);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0,  PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(0,  PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(0,  PLOT_LINE_WIDTH, InpWidthVWAP);
   PlotIndexSetInteger(1,  PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(1,  PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(1,  PLOT_LINE_WIDTH, InpWidthVWAP);

   PlotIndexSetInteger(2,  PLOT_LINE_COLOR, InpColorUpFlow);
   PlotIndexSetInteger(2,  PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(2,  PLOT_LINE_WIDTH, InpWidthFlow);
   PlotIndexSetInteger(3,  PLOT_LINE_COLOR, InpColorUpFlow);
   PlotIndexSetInteger(3,  PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(3,  PLOT_LINE_WIDTH, InpWidthFlow);

   PlotIndexSetInteger(4,  PLOT_LINE_COLOR, InpColorDnFlow);
   PlotIndexSetInteger(4,  PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(4,  PLOT_LINE_WIDTH, InpWidthFlow);
   PlotIndexSetInteger(5,  PLOT_LINE_COLOR, InpColorDnFlow);
   PlotIndexSetInteger(5,  PLOT_LINE_STYLE, InpStyleFlow);
   PlotIndexSetInteger(5,  PLOT_LINE_WIDTH, InpWidthFlow);

   PlotIndexSetInteger(6,  PLOT_LINE_COLOR, InpColorUpExtr);
   PlotIndexSetInteger(6,  PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(6,  PLOT_LINE_WIDTH, InpWidthExtr);
   PlotIndexSetInteger(7,  PLOT_LINE_COLOR, InpColorUpExtr);
   PlotIndexSetInteger(7,  PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(7,  PLOT_LINE_WIDTH, InpWidthExtr);

   PlotIndexSetInteger(8,  PLOT_LINE_COLOR, InpColorDnExtr);
   PlotIndexSetInteger(8,  PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(8,  PLOT_LINE_WIDTH, InpWidthExtr);
   PlotIndexSetInteger(9,  PLOT_LINE_COLOR, InpColorDnExtr);
   PlotIndexSetInteger(9,  PLOT_LINE_STYLE, InpStyleExtr);
   PlotIndexSetInteger(9,  PLOT_LINE_WIDTH, InpWidthExtr);

   PlotIndexSetInteger(10, PLOT_LINE_COLOR, InpColorUpWall);
   PlotIndexSetInteger(10, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(10, PLOT_LINE_WIDTH, InpWidthWall);
   PlotIndexSetInteger(11, PLOT_LINE_COLOR, InpColorUpWall);
   PlotIndexSetInteger(11, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(11, PLOT_LINE_WIDTH, InpWidthWall);

   PlotIndexSetInteger(12, PLOT_LINE_COLOR, InpColorDnWall);
   PlotIndexSetInteger(12, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(12, PLOT_LINE_WIDTH, InpWidthWall);
   PlotIndexSetInteger(13, PLOT_LINE_COLOR, InpColorDnWall);
   PlotIndexSetInteger(13, PLOT_LINE_STYLE, InpStyleWall);
   PlotIndexSetInteger(13, PLOT_LINE_WIDTH, InpWidthWall);

// Labels for Data Window
   PlotIndexSetString(2,  PLOT_LABEL, StringFormat("Bull Flow (+%.2fσ)", InpLevelFlow));
   PlotIndexSetString(4,  PLOT_LABEL, StringFormat("Bear Flow (-%.2fσ)", InpLevelFlow));
   PlotIndexSetString(6,  PLOT_LABEL, StringFormat("Bull Extr (+%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(8,  PLOT_LABEL, StringFormat("Bear Extr (-%.2fσ)", InpLevelExtreme));
   PlotIndexSetString(10, PLOT_LABEL, StringFormat("Bull Wall (+%.2fσ)", InpLevelWall));
   PlotIndexSetString(12, PLOT_LABEL, StringFormat("Bear Wall (-%.2fσ)", InpLevelWall));

// 4. Initialize Core Calculator Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_vwap = new CVWAPCalculator_HA();
   else
      g_vwap = new CVWAPCalculator();

   if(CheckPointer(g_vwap) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to create VWAP Calculator object.");
      return INIT_FAILED;
     }

   bool init_success = false;
   if(InpVWAPReset == PERIOD_CUSTOM_SESSION)
      init_success = g_vwap.Init(InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, true, 0, InpTzShift);
   else
      init_success = g_vwap.Init(InpVWAPReset, InpVolumeType, InpTzShift, true, 0);

   if(!init_success)
     {
      Print("Critical Error: Failed to initialize VWAP Calculator logic.");
      return INIT_FAILED;
     }

   string ha_tag = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("V-Score Bands%s%s(%d, %s)",
                                    ha_tag, tf_str, InpPeriod, EnumToString(InpVWAPReset));
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

   if(CheckPointer(g_vwap) != POINTER_INVALID)
     {
      delete g_vwap;
      g_vwap = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Helper: Calculate V-Score Rolling Dispersion Bands Engine        |
//+------------------------------------------------------------------+
void CalculateVScoreBandsEngine(const int total, const int prev_calc,
                                const datetime &time_arr[],
                                const double &open_arr[], const double &high_arr[],
                                const double &low_arr[], const double &close_arr[],
                                const long &tick_vol_arr[], const long &vol_arr[],
                                double &odd_vwap[], double &even_vwap[],
                                double &merged_vwap[], double &price_cache[],
                                double &uf_odd[], double &uf_even[],
                                double &df_odd[], double &df_even[],
                                double &ue_odd[], double &ue_even[],
                                double &de_odd[], double &de_even[],
                                double &uw_odd[], double &uw_even[],
                                double &dw_odd[], double &dw_even[])
  {
   if(total < InpPeriod)
      return;

// 1. Run Core VWAP
   g_vwap.Calculate(total, prev_calc, time_arr, open_arr, high_arr, low_arr, close_arr,
                    tick_vol_arr, vol_arr, odd_vwap, even_vwap);

   int start = (prev_calc > InpPeriod) ? (prev_calc - 1) : (InpPeriod - 1);
   if(start < InpPeriod - 1)
      start = InpPeriod - 1;

// 2. Project Rolling Standard Deviation Bands
   for(int i = start; i < total; i++)
     {
      price_cache[i] = close_arr[i];

      bool is_odd = (odd_vwap[i] != EMPTY_VALUE && odd_vwap[i] > 0.0);
      bool is_even = (even_vwap[i] != EMPTY_VALUE && even_vwap[i] > 0.0);
      double cur_vwap = is_odd ? odd_vwap[i] : (is_even ? even_vwap[i] : EMPTY_VALUE);
      merged_vwap[i] = cur_vwap;

      // Clear all bands at bar i
      uf_odd[i] = EMPTY_VALUE;
      uf_even[i] = EMPTY_VALUE;
      df_odd[i] = EMPTY_VALUE;
      df_even[i] = EMPTY_VALUE;
      ue_odd[i] = EMPTY_VALUE;
      ue_even[i] = EMPTY_VALUE;
      de_odd[i] = EMPTY_VALUE;
      de_even[i] = EMPTY_VALUE;
      uw_odd[i] = EMPTY_VALUE;
      uw_even[i] = EMPTY_VALUE;
      dw_odd[i] = EMPTY_VALUE;
      dw_even[i] = EMPTY_VALUE;

      if(cur_vwap == EMPTY_VALUE || cur_vwap <= 0.0)
         continue;

      // Compute Rolling Variance of (Price - VWAP) over InpPeriod
      double sum_sq_diff = 0.0;
      for(int k = 0; k < InpPeriod; k++)
        {
         int idx = i - k;
         double p = price_cache[idx];
         double v = merged_vwap[idx];

         if(v == EMPTY_VALUE || v <= 0.0)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / (double)InpPeriod);

      if(is_odd)
        {
         uf_odd[i] = cur_vwap + (InpLevelFlow * std_dev);
         df_odd[i] = cur_vwap - (InpLevelFlow * std_dev);
         ue_odd[i] = cur_vwap + (InpLevelExtreme * std_dev);
         de_odd[i] = cur_vwap - (InpLevelExtreme * std_dev);
         uw_odd[i] = cur_vwap + (InpLevelWall * std_dev);
         dw_odd[i] = cur_vwap - (InpLevelWall * std_dev);
        }
      else
        {
         uf_even[i] = cur_vwap + (InpLevelFlow * std_dev);
         df_even[i] = cur_vwap - (InpLevelFlow * std_dev);
         ue_even[i] = cur_vwap + (InpLevelExtreme * std_dev);
         de_even[i] = cur_vwap - (InpLevelExtreme * std_dev);
         uw_even[i] = cur_vwap + (InpLevelWall * std_dev);
         dw_even[i] = cur_vwap - (InpLevelWall * std_dev);
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
   if(rates_total < InpPeriod || CheckPointer(g_vwap) == POINTER_INVALID)
      return 0;

// Force chronological indexing
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
      if(ArraySize(m_vwap_odd) != rates_total)
        {
         ArrayResize(m_vwap_odd,    rates_total);
         ArraySetAsSeries(m_vwap_odd,    false);
         ArrayResize(m_vwap_even,   rates_total);
         ArraySetAsSeries(m_vwap_even,   false);
         ArrayResize(m_merged_vwap, rates_total);
         ArraySetAsSeries(m_merged_vwap, false);
         ArrayResize(m_price_buf,   rates_total);
         ArraySetAsSeries(m_price_buf,   false);
        }

      CalculateVScoreBandsEngine(rates_total, prev_calculated, time, open, high, low, close,
                                 tick_volume, volume, BufVWAP_Odd, BufVWAP_Even,
                                 m_merged_vwap, m_price_buf,
                                 BufUpFlow_Odd, BufUpFlow_Even,
                                 BufDnFlow_Odd, BufDnFlow_Even,
                                 BufUpExtr_Odd, BufUpExtr_Even,
                                 BufDnExtr_Odd, BufDnExtr_Even,
                                 BufUpWall_Odd, BufUpWall_Even,
                                 BufDnWall_Odd, BufDnWall_Even);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   int required_bars = InpPeriod + 10;
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
      ArrayResize(h_tick_vol,    g_htf_count);
      ArrayResize(h_vol,         g_htf_count);
      ArrayResize(h_res_odd,     g_htf_count);
      ArrayResize(h_res_even,    g_htf_count);
      ArrayResize(h_res_uf_odd,  g_htf_count);
      ArrayResize(h_res_uf_even, g_htf_count);
      ArrayResize(h_res_df_odd,  g_htf_count);
      ArrayResize(h_res_df_even, g_htf_count);
      ArrayResize(h_res_ue_odd,  g_htf_count);
      ArrayResize(h_res_ue_even, g_htf_count);
      ArrayResize(h_res_de_odd,  g_htf_count);
      ArrayResize(h_res_de_even, g_htf_count);
      ArrayResize(h_res_uw_odd,  g_htf_count);
      ArrayResize(h_res_uw_even, g_htf_count);
      ArrayResize(h_res_dw_odd,  g_htf_count);
      ArrayResize(h_res_dw_even, g_htf_count);

      ArraySetAsSeries(h_time,        false);
      ArraySetAsSeries(h_open,        false);
      ArraySetAsSeries(h_high,        false);
      ArraySetAsSeries(h_low,         false);
      ArraySetAsSeries(h_close,       false);
      ArraySetAsSeries(h_tick_vol,    false);
      ArraySetAsSeries(h_vol,         false);
      ArraySetAsSeries(h_res_odd,     false);
      ArraySetAsSeries(h_res_even,    false);
      ArraySetAsSeries(h_res_uf_odd,  false);
      ArraySetAsSeries(h_res_uf_even, false);
      ArraySetAsSeries(h_res_df_odd,  false);
      ArraySetAsSeries(h_res_df_even, false);
      ArraySetAsSeries(h_res_ue_odd,  false);
      ArraySetAsSeries(h_res_ue_even, false);
      ArraySetAsSeries(h_res_de_odd,  false);
      ArraySetAsSeries(h_res_de_even, false);
      ArraySetAsSeries(h_res_uw_odd,  false);
      ArraySetAsSeries(h_res_uw_even, false);
      ArraySetAsSeries(h_res_dw_odd,  false);
      ArraySetAsSeries(h_res_dw_even, false);

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

      double h_merged[], h_price[];
      ArrayResize(h_merged, g_htf_count);
      ArraySetAsSeries(h_merged, false);
      ArrayResize(h_price,  g_htf_count);
      ArraySetAsSeries(h_price,  false);

      // Compute HTF V-Score Projected Bands
      CalculateVScoreBandsEngine(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                                 h_tick_vol, h_vol, h_res_odd, h_res_even,
                                 h_merged, h_price,
                                 h_res_uf_odd, h_res_uf_even,
                                 h_res_df_odd, h_res_df_even,
                                 h_res_ue_odd, h_res_ue_even,
                                 h_res_de_odd, h_res_de_even,
                                 h_res_uw_odd, h_res_uw_even,
                                 h_res_dw_odd, h_res_dw_even);
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

         double h_merged[], h_price[];
         ArrayResize(h_merged, g_htf_count);
         ArraySetAsSeries(h_merged, false);
         ArrayResize(h_price,  g_htf_count);
         ArraySetAsSeries(h_price,  false);

         // Mock update on live HTF bar
         CalculateVScoreBandsEngine(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                    h_tick_vol, h_vol, h_res_odd, h_res_even,
                                    h_merged, h_price,
                                    h_res_uf_odd, h_res_uf_even,
                                    h_res_df_odd, h_res_df_even,
                                    h_res_ue_odd, h_res_ue_even,
                                    h_res_de_odd, h_res_de_even,
                                    h_res_uw_odd, h_res_uw_even,
                                    h_res_dw_odd, h_res_dw_even);
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

// 7. Chronological Mapping Loop to Chart Timeframe (14 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufVWAP_Odd[i]    = h_res_odd[idx_htf];
            BufVWAP_Even[i]   = h_res_even[idx_htf];
            BufUpFlow_Odd[i]  = h_res_uf_odd[idx_htf];
            BufUpFlow_Even[i] = h_res_uf_even[idx_htf];
            BufDnFlow_Odd[i]  = h_res_df_odd[idx_htf];
            BufDnFlow_Even[i] = h_res_df_even[idx_htf];
            BufUpExtr_Odd[i]  = h_res_ue_odd[idx_htf];
            BufUpExtr_Even[i] = h_res_ue_even[idx_htf];
            BufDnExtr_Odd[i]  = h_res_de_odd[idx_htf];
            BufDnExtr_Even[i] = h_res_de_even[idx_htf];
            BufUpWall_Odd[i]  = h_res_uw_odd[idx_htf];
            BufUpWall_Even[i] = h_res_uw_even[idx_htf];
            BufDnWall_Odd[i]  = h_res_dw_odd[idx_htf];
            BufDnWall_Even[i] = h_res_dw_even[idx_htf];
           }
         else
           {
            BufVWAP_Odd[i]    = EMPTY_VALUE;
            BufVWAP_Even[i]   = EMPTY_VALUE;
            BufUpFlow_Odd[i]  = EMPTY_VALUE;
            BufUpFlow_Even[i] = EMPTY_VALUE;
            BufDnFlow_Odd[i]  = EMPTY_VALUE;
            BufDnFlow_Even[i] = EMPTY_VALUE;
            BufUpExtr_Odd[i]  = EMPTY_VALUE;
            BufUpExtr_Even[i] = EMPTY_VALUE;
            BufDnExtr_Odd[i]  = EMPTY_VALUE;
            BufDnExtr_Even[i] = EMPTY_VALUE;
            BufUpWall_Odd[i]  = EMPTY_VALUE;
            BufUpWall_Even[i] = EMPTY_VALUE;
            BufDnWall_Odd[i]  = EMPTY_VALUE;
            BufDnWall_Even[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufVWAP_Odd[i]    = EMPTY_VALUE;
         BufVWAP_Even[i]   = EMPTY_VALUE;
         BufUpFlow_Odd[i]  = EMPTY_VALUE;
         BufUpFlow_Even[i] = EMPTY_VALUE;
         BufDnFlow_Odd[i]  = EMPTY_VALUE;
         BufDnFlow_Even[i] = EMPTY_VALUE;
         BufUpExtr_Odd[i]  = EMPTY_VALUE;
         BufUpExtr_Even[i] = EMPTY_VALUE;
         BufDnExtr_Odd[i]  = EMPTY_VALUE;
         BufDnExtr_Even[i] = EMPTY_VALUE;
         BufUpWall_Odd[i]  = EMPTY_VALUE;
         BufUpWall_Even[i] = EMPTY_VALUE;
         BufDnWall_Odd[i]  = EMPTY_VALUE;
         BufDnWall_Even[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
