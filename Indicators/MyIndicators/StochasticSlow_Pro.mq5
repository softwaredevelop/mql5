//+------------------------------------------------------------------+
//|                                           StochasticSlow_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20" // Enterprise Refactor: Zero-Lag MTF Fast-Path & Fused Memory
#property description "Professional Slow Stochastic with selectable MA types and"
#property description "candle source (Standard or Heikin Ashi) with Native & MTF support."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K line
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\StochasticSlow_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting the candle source ---
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
input ENUM_TIMEFRAMES     InpTimeframe      = PERIOD_CURRENT;       // Target Higher Timeframe

input group "--- Stochastic Settings ---"
input int                InpKPeriod       = 5;
input int                InpSlowingPeriod = 3;
input ENUM_MA_TYPE       InpSlowingMAType = SMA;
input int                InpDPeriod       = 3;
input ENUM_MA_TYPE       InpDMAType       = SMA;
input ENUM_CANDLE_SOURCE InpCandleSource  = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_k[], h_res_d[];
datetime  h_time[];

//--- Global Objects & State Management
CStochasticSlowCalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
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
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Buffers
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);

   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   ArrayInitialize(BufferK, EMPTY_VALUE);
   ArrayInitialize(BufferD, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Factory Logic for Heikin Ashi price routing
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CStochasticSlowCalculator_HA();
         break;
      default:
         g_calculator = new CStochasticSlowCalculator();
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpKPeriod, InpSlowingPeriod, InpSlowingMAType, InpDPeriod, InpDMAType))
     {
      Print("Critical Error: Failed to create or initialize Slow Stochastic Calculator object.");
      return(INIT_FAILED);
     }

// 4. Dynamic Setup of Indicator Shortname and Plots
   string type   = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SlowStoch%s%s(%d,%d,%d)", type, tf_str, InpKPeriod, InpSlowingPeriod, InpDPeriod));

   int draw_begin_k = InpKPeriod + InpSlowingPeriod - 2;
   int draw_begin_d = InpKPeriod + InpSlowingPeriod + InpDPeriod - 3;
   if(g_is_mtf_mode)
     {
      draw_begin_k = 0;
      draw_begin_d = 0;
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin_k);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin_d);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
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
//| Custom indicator calculation function                            |
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
   int required_bars = InpKPeriod + InpSlowingPeriod + InpDPeriod + 5;
   if(rates_total < required_bars || !g_calculator)
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
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform full history sync once
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
      ArrayResize(h_time,    g_htf_count);
      ArrayResize(h_open,    g_htf_count);
      ArrayResize(h_high,    g_htf_count);
      ArrayResize(h_low,     g_htf_count);
      ArrayResize(h_close,   g_htf_count);
      ArrayResize(h_res_k,   g_htf_count);
      ArrayResize(h_res_d,   g_htf_count);

      ArraySetAsSeries(h_time,    false);
      ArraySetAsSeries(h_open,    false);
      ArraySetAsSeries(h_high,    false);
      ArraySetAsSeries(h_low,     false);
      ArraySetAsSeries(h_close,   false);
      ArraySetAsSeries(h_res_k,   false);
      ArraySetAsSeries(h_res_d,   false);

      // Atomic bulk rates copy (Single API call replaces 5 calls!)
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

      // Compute HTF Slow Stochastic Values across history
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_k, h_res_d);
      g_data_ready = true;

      // Full Historical Projection to Chart Buffers (Only on new HTF candle)
      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);
         if(shift_htf >= 0)
           {
            int idx_htf = g_htf_count - 1 - shift_htf;
            if(idx_htf >= 0 && idx_htf < g_htf_count)
              {
               BufferK[i] = h_res_k[idx_htf];
               BufferD[i] = h_res_d[idx_htf];
              }
            else
              {
               BufferK[i] = EMPTY_VALUE;
               BufferD[i] = EMPTY_VALUE;
              }
           }
         else
           {
            BufferK[i] = EMPTY_VALUE;
            BufferD[i] = EMPTY_VALUE;
           }
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update strictly forming block!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      // Single atomic API call instead of 4 separate copies!
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         // Mock update strictly on forming candle
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_k, h_res_d);
        }
     }

// Instant Binary Search for Forming Block Start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Direct Vectorized Assignment (Zero API calls, Nanosecond Execution across 2 buffers)
   double k_val = h_res_k[live_idx];
   double d_val = h_res_d[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferK[i] = k_val;
      BufferD[i] = d_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpKPeriod + InpSlowingPeriod + InpDPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
