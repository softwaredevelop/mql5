//+------------------------------------------------------------------+
//|                                           StochasticFast_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "4.00" // Enterprise Edition: MTF Fast-Path, Direct In-Place HA & Full Visual Panel
#property description "Professional Fast Stochastic Oscillator with 14 MA Types, MTF Fast-Path, and Heikin Ashi."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1  20.0
#property indicator_level2  50.0
#property indicator_level3  80.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Plot Declarations ---
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\StochasticFast_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Standard High / Low / Close
   CANDLE_HEIKIN_ASHI    // Synthetic Heikin Ashi
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== Stochastic Core Settings ==="
input int                       InpKPeriod        = 14;                // %K Lookback Period
input int                       InpDPeriod        = 3;                 // %D Smoothing Period
input ENUM_MA_TYPE              InpDMAType        = SMA;               // %D MA Algorithm (14 Pluggable Models)
input ENUM_CANDLE_SOURCE        InpCandleSource   = CANDLE_STANDARD;   // Price Source (Standard vs. Heikin Ashi)

input group "=== Visual Settings - %K Line ==="
input color                     InpColorK         = clrLightSeaGreen;  // %K Line Color
input ENUM_LINE_STYLE           InpStyleK         = STYLE_SOLID;       // %K Line Style
input int                       InpWidthK         = 1;                 // %K Line Width

input group "=== Visual Settings - %D Line ==="
input color                     InpColorD         = clrLightCoral;     // %D Line Color
input ENUM_LINE_STYLE           InpStyleD         = STYLE_SOLID;       // %D Line Style
input int                       InpWidthD         = 1;                 // %D Line Width

//--- Indicator Output Buffers ---
double BufferK[];
double BufferD[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_k[], h_res_d[];
datetime h_time[];

//--- Global Objects & State Management ---
CStochasticFastCalculator *g_calculator     = NULL;
bool                      g_is_mtf_mode     = false;
ENUM_TIMEFRAMES           g_calc_timeframe;
bool                      g_data_ready      = false;
bool                      g_data_synced     = false;
int                       g_htf_count       = 0;
datetime                  g_last_htf_time   = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Integrity Guard
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

// 2. Bind Output Buffers
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);

   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling from Inputs
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorK);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleK);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthK);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorD);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleD);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthD);

   int draw_begin_k = InpKPeriod - 1;
   int draw_begin_d = InpKPeriod + InpDPeriod - 2;
   if(g_is_mtf_mode)
     {
      draw_begin_k = 0;
      draw_begin_d = 0;
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin_k);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin_d);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CStochasticFastCalculator_HA();
   else
      g_calculator = new CStochasticFastCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpKPeriod, InpDPeriod, InpDMAType))
     {
      Print("Critical Error: Failed to initialize Fast Stochastic Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("FastStoch Pro%s%s(%d,%d,%s)",
                                    ha_tag, tf_str, InpKPeriod, InpDPeriod, EnumToString(InpDMAType));

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("%%K(%d)", InpKPeriod));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("%%D(%d)", InpDPeriod));

// 5. Background MTF Sync Daemon
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID && g_calculator != NULL)
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
   int warmup = InpKPeriod + InpDPeriod + 5;
   if(rates_total < warmup || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
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
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = InpKPeriod + InpDPeriod + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform atomic full history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars_mtf)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays with capacity reservation
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,  g_htf_count, 2048);
         ArrayResize(h_open,  g_htf_count, 2048);
         ArrayResize(h_high,  g_htf_count, 2048);
         ArrayResize(h_low,   g_htf_count, 2048);
         ArrayResize(h_close, g_htf_count, 2048);
         ArrayResize(h_res_k, g_htf_count, 2048);
         ArrayResize(h_res_d, g_htf_count, 2048);

         ArraySetAsSeries(h_time,  false);
         ArraySetAsSeries(h_open,  false);
         ArraySetAsSeries(h_high,  false);
         ArraySetAsSeries(h_low,   false);
         ArraySetAsSeries(h_close, false);
         ArraySetAsSeries(h_res_k, false);
         ArraySetAsSeries(h_res_d, false);
        }

      // Single Atomic Bulk Rates Copy
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
        }

      // Compute HTF Fast Stochastic on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_k, h_res_d);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferK[i] = EMPTY_VALUE;
            BufferD[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferK[i] = h_res_k[htf_ptr];
         BufferD[i] = h_res_d[htf_ptr];
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: Update forming candle strictly in RAM
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars_mtf)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         // Recompute strictly forming bar in RAM
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_k, h_res_d);
        }
     }

// Binary Search for forming bar block start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

   double val_k = h_res_k[live_idx];
   double val_d = h_res_d[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferK[i] = val_k;
      BufferD[i] = val_d;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpKPeriod + InpDPeriod + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
