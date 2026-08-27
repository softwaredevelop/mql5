//+------------------------------------------------------------------+
//|                                    KScore_Anchored_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Session-Anchored K-Score Projected Bands with Open-Ended Sampling
#property description "Session-Anchored K-Score Projected Dynamic Bands on Main Chart (Rolling Envelope around AKAMA)."
#property description "Features 14-buffer odd/even gapped lines, custom session hours, and unified Native & MTF pipelines."

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   14

//--- Plot 1 & 2: AKAMA Centerline (Odd / Even)
#property indicator_label1  "AKAMA"
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
#include <MyIncludes\KAMA_Anchored_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe            = PERIOD_CURRENT;        // Calculation Timeframe (Current or HTF)

input group "--- Anchor Settings ---"
input ENUM_ANCHOR_PERIOD        InpResetPeriod          = ANCHOR_PERIOD_SESSION; // Anchor Reset Period
input int                       InpTzShift              = 0;                     // Timezone Shift (Hours)
input string                    InpCustomStart          = "08:00";               // Custom Session Start (HH:MM)
input string                    InpCustomEnd            = "17:00";               // Custom Session End (HH:MM)

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
input color                     InpColorKAMA            = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleKAMA            = STYLE_SOLID;           // Centerline Style
input int                       InpWidthKAMA            = 2;                     // Centerline Width

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
double BufAKAMA_Odd[],  BufAKAMA_Even[];
double BufUpFlow_Odd[], BufUpFlow_Even[];
double BufDnFlow_Odd[], BufDnFlow_Even[];
double BufUpExtr_Odd[], BufUpExtr_Even[];
double BufDnExtr_Odd[], BufDnExtr_Even[];
double BufUpWall_Odd[], BufUpWall_Even[];
double BufDnWall_Odd[], BufDnWall_Even[];

//--- Internal State Buffers
double m_akama_odd[];
double m_akama_even[];
double m_price_series[];
double m_merged_akama[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[], h_price[];
double h_res_odd[], h_res_even[];
double h_res_uf_odd[], h_res_uf_even[];
double h_res_df_odd[], h_res_df_even[];
double h_res_ue_odd[], h_res_ue_even[];
double h_res_de_odd[], h_res_de_even[];
double h_res_uw_odd[], h_res_uw_even[];
double h_res_dw_odd[], h_res_dw_even[];
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
   SetIndexBuffer(0,  BufAKAMA_Odd,   INDICATOR_DATA);
   SetIndexBuffer(1,  BufAKAMA_Even,  INDICATOR_DATA);
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
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufAKAMA_Odd,   false);
   ArraySetAsSeries(BufAKAMA_Even,  false);
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
   PlotIndexSetInteger(0,  PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0,  PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0,  PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetInteger(1,  PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(1,  PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(1,  PLOT_LINE_WIDTH, InpWidthKAMA);

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
   string short_name = StringFormat("AK-Score Bands%s%s(%s, ER%d, σ%d)",
                                    ha_tag, tf_str, EnumToString(InpResetPeriod), InpErPeriod, InpStDevPeriod);
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
//| Helper: Calculate Open-Ended Session-Anchored K-Score Bands      |
//+------------------------------------------------------------------+
void CalculateAKScoreBandsEngine(const int total, const int prev_calc,
                                 const datetime &time_arr[],
                                 const double &open_arr[], const double &high_arr[],
                                 const double &low_arr[], const double &close_arr[],
                                 double &odd_akama[], double &even_akama[],
                                 double &merged_akama[], double &price_series[],
                                 double &uf_odd[], double &uf_even[],
                                 double &df_odd[], double &df_even[],
                                 double &ue_odd[], double &ue_even[],
                                 double &de_odd[], double &de_even[],
                                 double &uw_odd[], double &uw_even[],
                                 double &dw_odd[], double &dw_even[])
  {
   if(total < 2)
      return;

// 1. Run Anchored KAMA Engine
   g_calculator.Calculate(total, prev_calc, time_arr, open_arr, high_arr, low_arr, close_arr,
                          odd_akama, even_akama, price_series);

   int start = (prev_calc > 0) ? (prev_calc - 1) : 0;

// 2. Project Open-Ended Rolling Standard Deviation Bands
   for(int i = start; i < total; i++)
     {
      bool is_odd  = (odd_akama[i]  != EMPTY_VALUE && odd_akama[i]  > 0.0);
      bool is_even = (even_akama[i] != EMPTY_VALUE && even_akama[i] > 0.0);
      double cur_akama = is_odd ? odd_akama[i] : (is_even ? even_akama[i] : EMPTY_VALUE);
      merged_akama[i] = cur_akama;

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

      if(cur_akama == EMPTY_VALUE || cur_akama <= 0.0)
         continue;

      // Open-Ended In-Session Sampling: Collect the last InpStDevPeriod valid in-session bars
      double sum_sq_diff = 0.0;
      int    collected   = 0;
      int    k           = 0;

      while(collected < InpStDevPeriod && (i - k) >= 0)
        {
         int idx = i - k;
         double v = merged_akama[idx];
         if(v != EMPTY_VALUE && v > 0.0)
           {
            double p = price_series[idx];
            double diff = p - v;
            sum_sq_diff += diff * diff;
            collected++;
           }
         k++;
        }

      double std_dev = (collected > 0) ? MathSqrt(sum_sq_diff / (double)collected) : 0.0;

      if(is_odd)
        {
         uf_odd[i] = cur_akama + (InpLevelFlow * std_dev);
         df_odd[i] = cur_akama - (InpLevelFlow * std_dev);
         ue_odd[i] = cur_akama + (InpLevelExtreme * std_dev);
         de_odd[i] = cur_akama - (InpLevelExtreme * std_dev);
         uw_odd[i] = cur_akama + (InpLevelWall * std_dev);
         dw_odd[i] = cur_akama - (InpLevelWall * std_dev);
        }
      else
        {
         uf_even[i] = cur_akama + (InpLevelFlow * std_dev);
         df_even[i] = cur_akama - (InpLevelFlow * std_dev);
         ue_even[i] = cur_akama + (InpLevelExtreme * std_dev);
         de_even[i] = cur_akama - (InpLevelExtreme * std_dev);
         uw_even[i] = cur_akama + (InpLevelWall * std_dev);
         dw_even[i] = cur_akama - (InpLevelWall * std_dev);
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
      if(ArraySize(m_akama_odd) != rates_total)
        {
         ArrayResize(m_akama_odd,     rates_total);
         ArraySetAsSeries(m_akama_odd,     false);
         ArrayResize(m_akama_even,    rates_total);
         ArraySetAsSeries(m_akama_even,    false);
         ArrayResize(m_merged_akama,  rates_total);
         ArraySetAsSeries(m_merged_akama,  false);
         ArrayResize(m_price_series,  rates_total);
         ArraySetAsSeries(m_price_series,  false);
        }

      CalculateAKScoreBandsEngine(rates_total, prev_calculated, time, open, high, low, close,
                                  BufAKAMA_Odd, BufAKAMA_Even,
                                  m_merged_akama, m_price_series,
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
      ArrayResize(h_price,       g_htf_count);
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
      ArraySetAsSeries(h_price,       false);
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

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      double h_merged[];
      ArrayResize(h_merged, g_htf_count);
      ArraySetAsSeries(h_merged, false);

      // Compute HTF Anchored K-Score Bands
      CalculateAKScoreBandsEngine(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                                  h_res_odd, h_res_even,
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
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,  g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o)     == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h)     == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l)     == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c)     == 1)
        {
         h_time[live_idx]  = t_bar[0];
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         double h_merged[];
         ArrayResize(h_merged, g_htf_count);
         ArraySetAsSeries(h_merged, false);

         // Mock update on live HTF bar
         CalculateAKScoreBandsEngine(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                     h_res_odd, h_res_even,
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
            BufAKAMA_Odd[i]   = h_res_odd[idx_htf];
            BufAKAMA_Even[i]  = h_res_even[idx_htf];
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
            BufAKAMA_Odd[i]   = EMPTY_VALUE;
            BufAKAMA_Even[i]  = EMPTY_VALUE;
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
         BufAKAMA_Odd[i]   = EMPTY_VALUE;
         BufAKAMA_Even[i]  = EMPTY_VALUE;
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
   int required_bars = InpErPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
