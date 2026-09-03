//+------------------------------------------------------------------+
//|                                                     MACD_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "5.00" // Unified Native & MTF Release with Full VWMA Volume Routing
#property description "Gerald Appel's MACD with Native & MTF Support, VWMA Volume Routing, and Heikin Ashi."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: MACD Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\MACD_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- MACD Core Settings ---"
input int                       InpFastPeriod     = 12;                // Fast MA Period
input int                       InpSlowPeriod     = 26;                // Slow MA Period
input int                       InpSignalPeriod   = 9;                 // Signal MA Period
input ENUM_MA_TYPE              InpSourceMAType   = EMA;               // Fast/Slow MA Type (Supports VWMA)
input ENUM_MA_TYPE              InpSignalMAType   = EMA;               // Signal Line MA Type (Supports VWMA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "--- Visual Settings - MACD Line ---"
input color                     InpColorMACD      = clrDodgerBlue;     // MACD Line Color
input ENUM_LINE_STYLE           InpStyleMACD      = STYLE_SOLID;       // MACD Line Style
input int                       InpWidthMACD      = 2;                 // MACD Line Width

input group "--- Visual Settings - Signal Line ---"
input color                     InpColorSignal    = clrOrangeRed;      // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;       // Signal Line Style
input int                       InpWidthSignal    = 1;                 // Signal Line Width

input group "--- Visual Settings - Histogram ---"
input color                     InpColorHist      = clrSilver;         // Histogram Color
input ENUM_LINE_STYLE           InpStyleHist      = STYLE_SOLID;       // Histogram Style
input int                       InpWidthHist      = 1;                 // Histogram Width

//--- Indicator Buffers ---
double    BufferMACD_Histogram[];
double    BufferMACDLine[];
double    BufferSignalLine[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_vol[];
double    h_res_macd[], h_res_signal[], h_res_hist[];
datetime  h_time[];

//--- Global Objects & State Management
CMACDCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);

   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);

   ArrayInitialize(BufferMACD_Histogram, 0.0);
   ArrayInitialize(BufferMACDLine,       EMPTY_VALUE);
   ArrayInitialize(BufferSignalLine,     EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorHist);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleHist);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthHist);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMACD);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMACD);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMACD);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorSignal);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleSignal);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthSignal);

   int slow_period = MathMax(InpFastPeriod, InpSlowPeriod);
   int signal_draw_begin = slow_period + InpSignalPeriod - 2;
   if(g_is_mtf_mode)
      signal_draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, (g_is_mtf_mode ? 0 : slow_period - 1));
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMACDCalculator_HA();
   else
      g_calculator = new CMACDCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpSignalPeriod, InpSourceMAType, InpSignalMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize MACD Calculator.");
      return INIT_FAILED;
     }

   string ha_tag    = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str    = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("MACD Pro%s%s(%d,%d,%d)",
                                    ha_tag, tf_str,
                                    InpFastPeriod, InpSlowPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

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
   int warmup = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod;
   if(rates_total < warmup || CheckPointer(g_calculator) == POINTER_INVALID)
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
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume,
                                BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume,
                                BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);

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
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_vol,        g_htf_count);
      ArrayResize(h_res_macd,   g_htf_count);
      ArrayResize(h_res_signal, g_htf_count);
      ArrayResize(h_res_hist,   g_htf_count);

      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_vol,        false);
      ArraySetAsSeries(h_res_macd,   false);
      ArraySetAsSeries(h_res_signal, false);
      ArraySetAsSeries(h_res_hist,   false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
        {
         long temp_vol[];
         if(CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_vol[i] = (double)temp_vol[i];
           }
        }
      else
        {
         long temp_vol[];
         if(CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_vol[i] = (double)temp_vol[i];
           }
        }

      // Compute HTF MACD Values with Volume Routing
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_macd, h_res_signal, h_res_hist);
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
      long v[1];

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

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = (double)v[0];
         else
            if(CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_vol[live_idx] = (double)v[0];

         // Mock update on live bar with volume
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol,
                                h_res_macd, h_res_signal, h_res_hist);
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

// 7. Chronological Mapping Loop to Chart Timeframe (3 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferMACD_Histogram[i] = h_res_hist[idx_htf];
            BufferMACDLine[i]       = h_res_macd[idx_htf];
            BufferSignalLine[i]     = h_res_signal[idx_htf];
           }
         else
           {
            BufferMACD_Histogram[i] = 0.0;
            BufferMACDLine[i]       = EMPTY_VALUE;
            BufferSignalLine[i]     = EMPTY_VALUE;
           }
        }
      else
        {
         BufferMACD_Histogram[i] = 0.0;
         BufferMACDLine[i]       = EMPTY_VALUE;
         BufferSignalLine[i]     = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpFastPeriod, InpSlowPeriod) + InpSignalPeriod;
   int required_bars = warmup + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
