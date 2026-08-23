//+------------------------------------------------------------------+
//|                                                         KAMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.40" // Standardized MTF Framework with DataSync Daemon
#property description "Professional Kaufman's Adaptive Moving Average with Unified Native & MTF Support."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Definition
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Included Engines & Core Tools
#include <MyIncludes\KAMA_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group                     "Timeframe Settings"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group                     "KAMA Core Settings"
input int                       InpErPeriod       = 10;                // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;                 // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;                // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group                     "Visual Settings"
input color                     InpColorKAMA      = clrCrimson;        // Line Color
input ENUM_LINE_STYLE           InpStyleKAMA      = STYLE_SOLID;       // Line Style
input int                       InpWidthKAMA      = 1;                 // Line Width

//--- Indicator Buffers ---
double    BufferKAMA[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_kama[];
datetime  h_time[];

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

// 2. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufferKAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA, false);
   ArrayInitialize(BufferKAMA, EMPTY_VALUE);

// Configure Visuals
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int draw_begin = InpErPeriod + 5;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 3. Initialize Physical Calculator
   g_calculator = new CKamaCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to create or initialize KAMA Calculator.");
      return INIT_FAILED;
     }

// 4. Dynamic Setup of Indicator Shortname
   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("KAMA%s%s(%d,%d,%d)",
                                    ha_tag, tf_str,
                                    InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod);
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
   int required_bars = InpErPeriod + 10;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing on current timeframe arrays
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
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferKAMA);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // History sync pending
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
      ArrayResize(h_res_kama, g_htf_count);

      // Force chronological alignment
      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_res_kama, false);

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

      // Compute HTF KAMA Values
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_kama);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for the active forming HTF candle
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

         // Real-time live bar state mocking
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_kama);
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
   first_bar_of_forming_htf++; // Dynamic anchor start

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
            BufferKAMA[i] = h_res_kama[idx_htf];
           }
         else
           {
            BufferKAMA[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferKAMA[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
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
