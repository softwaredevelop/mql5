//+------------------------------------------------------------------+
//|                                           Laguerre_Filter_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with Enhanced Visuals
#property description "John Ehlers' Laguerre Filter as a low-lag moving average with Native & MTF Support."
#property description "Includes an optional 4-point FIR filter for lag and smoothing comparison."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Laguerre Filter Line
#property indicator_label1  "Laguerre Filter"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional FIR Comparison Line
#property indicator_label2  "FIR Filter"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Core Tools
#include <MyIncludes\Laguerre_Filter_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Laguerre Settings ---"
input double                    InpGamma          = 0.5;               // Laguerre Gamma (e.g. 0.236, 0.382, 0.618)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "--- FIR Comparison Filter Settings ---"
input bool                      InpShowFIR        = false;             // Show 4-Point FIR Comparison Line?

input group "--- Visual Settings - Laguerre Filter ---"
input color                     InpColorLaguerre  = clrCrimson;        // Laguerre Line Color
input ENUM_LINE_STYLE           InpStyleLaguerre  = STYLE_SOLID;       // Laguerre Line Style
input int                       InpWidthLaguerre  = 2;                 // Laguerre Line Width

input group "--- Visual Settings - FIR Filter ---"
input color                     InpColorFIR       = clrDarkBlue;       // FIR Line Color
input ENUM_LINE_STYLE           InpStyleFIR       = STYLE_SOLID;       // FIR Line Style
input int                       InpWidthFIR       = 1;                 // FIR Line Width

//--- Indicator Buffers ---
double    BufferFilter[];
double    BufferFIR[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_filter[], h_res_fir[];
datetime  h_time[];

//--- Global Objects & State Management
CLaguerreFilterCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufferFilter, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFIR,    INDICATOR_DATA);

   ArraySetAsSeries(BufferFilter, false);
   ArraySetAsSeries(BufferFIR,    false);

   ArrayInitialize(BufferFilter, EMPTY_VALUE);
   ArrayInitialize(BufferFIR,    EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorLaguerre);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleLaguerre);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthLaguerre);

   if(InpShowFIR)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorFIR);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleFIR);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthFIR);
      PlotIndexSetString(1,  PLOT_LABEL, "FIR Filter");
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1,  PLOT_LABEL, NULL);
     }

   int draw_begin = 4;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CLaguerreFilterCalculator_HA();
   else
      g_calculator = new CLaguerreFilterCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpGamma, SOURCE_PRICE, InpSourcePrice))
     {
      Print("Critical Error: Failed to create or initialize Laguerre Filter Calculator.");
      return INIT_FAILED;
     }

   string ha_tag    = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str    = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Laguerre Filter%s%s(γ=%.3f)", ha_tag, tf_str, InpGamma);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

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
   if(rates_total < 5 || CheckPointer(g_calculator) == POINTER_INVALID)
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
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferFilter, BufferFIR);

      if(!InpShowFIR)
        {
         int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
         for(int i = start_sync; i < rates_total; i++)
            BufferFIR[i] = EMPTY_VALUE;
        }

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

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_res_filter, g_htf_count);
      ArrayResize(h_res_fir,    g_htf_count);

      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_res_filter, false);
      ArraySetAsSeries(h_res_fir,    false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Compute HTF Laguerre & FIR Filter Values
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_filter, h_res_fir);
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

         // Mock update on live HTF bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_filter, h_res_fir);
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

// 7. Chronological Mapping Loop to Chart Timeframe (2 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferFilter[i] = h_res_filter[idx_htf];
            BufferFIR[i]    = InpShowFIR ? h_res_fir[idx_htf] : EMPTY_VALUE;
           }
         else
           {
            BufferFilter[i] = EMPTY_VALUE;
            BufferFIR[i]    = EMPTY_VALUE;
           }
        }
      else
        {
         BufferFilter[i] = EMPTY_VALUE;
         BufferFIR[i]    = EMPTY_VALUE;
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
