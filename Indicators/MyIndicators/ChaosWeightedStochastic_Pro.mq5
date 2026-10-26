//+------------------------------------------------------------------+
//|                                  ChaosWeightedStochastic_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.10" // Enterprise Edition: Unified ENUM_CANDLE_SOURCE & Clean Architectural Suite Alignment
#property description "Chaos-Weighted Stochastic Oscillator with Sevcik Fractal Modulation & MTF Divergences."
#property description "Combines Fast Stochastic responsiveness in trends with Slow Stochastic noise immunity in chop."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1      80.0
#property indicator_level2      50.0
#property indicator_level3      20.0
#property indicator_levelcolor  clrSilver
#property indicator_levelstyle  STYLE_DOT
#property indicator_minimum    0.0
#property indicator_maximum    100.0

// Plot 1: Chaos-Weighted %K Line
#property indicator_label1  "Chaos %K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Optional %D Signal Line
#property indicator_label2  "Signal %D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\ChaosWeightedStochastic_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES       InpTimeframe        = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "=== Stochastic & Chaos Settings ==="
input int                   InpKPeriod          = 14;                  // %K Lookback Period
input int                   InpSlowingPeriod    = 3;                   // Base Slowing Factor (Alpha Base)
input int                   InpDPeriod          = 3;                   // %D Signal Line Period
input ENUM_MA_TYPE          InpDMAType          = SMA;                 // %D Signal MA Method
input int                   InpDisorderLength   = 20;                  // Disorder Lookback (FDI Period)
input double                InpSensitivity      = 1.0;                 // Chaos Dampening Sensitivity (0.1 - 5.0)
input ENUM_CANDLE_SOURCE    InpCandleSource     = CANDLE_STANDARD;     // Candle Source (Standard vs Heikin Ashi)
input int                   InpHistoryBars      = 1000;                // History Bars Limit (0 = Full Chart)

input group "=== Visuals ==="
input color                 InpColorK           = clrDodgerBlue;       // %K Line Color
input int                   InpWidthK           = 2;                   // %K Line Width
input bool                  InpShowSignal       = true;                // Display %D Signal Line
input color                 InpColorD           = clrMagenta;          // %D Signal Color
input ENUM_LINE_STYLE       InpStyleD           = STYLE_SOLID;         // %D Signal Style
input int                   InpWidthD           = 2;                   // %D Signal Width

input group "=== Divergence Settings ==="
input bool                  InpShowDivLines     = true;                // Draw Divergence Lines in Subwindow
input int                   InpDivStrength      = 15;                  // Divergence Pivot Strength (Confirm Bars)
input color                 InpBullDivColor     = clrMediumSeaGreen;   // Bullish Divergence Line Color
input color                 InpBearDivColor     = clrCrimson;          // Bearish Divergence Line Color

input group "=== Multi-Instance Settings ==="
input int                   InpInstanceID       = 1;                   // Unique Instance ID

//--- Visual Indicator Buffers
double BufferK[];
double BufferD[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_k[], h_res_d[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CChaosWeightedStochastic_Calculator *g_calc              = NULL;
string                               g_prefix            = "";
string                               g_indicator_shortname = "";

bool            g_is_mtf_mode        = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready         = false;
bool            g_data_synced        = false;
int             g_htf_count          = 0;
datetime        g_last_htf_time      = 0;
bool            g_divergences_ready  = false;

//--- Divergence Internal Tracking Registers
double g_last_k_lo   = WRONG_VALUE;
double g_last_prc_lo = WRONG_VALUE;
int    g_last_bar_lo = -1;

double g_last_k_hi   = WRONG_VALUE;
double g_last_prc_hi = WRONG_VALUE;
int    g_last_bar_hi = -1;

int    g_last_proc_pivot_bar = -1;

//+------------------------------------------------------------------+
//| Resilient Indicator Subwindow Locator                            |
//+------------------------------------------------------------------+
int GetIndicatorSubwindow()
  {
   if(g_indicator_shortname != "")
     {
      int subwin = ChartWindowFind(0, g_indicator_shortname);
      if(subwin >= 0)
         return subwin;
     }

   int total_windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 1; w < total_windows; w++)
     {
      int total_indicators = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total_indicators; i++)
        {
         string ind_name = ChartIndicatorName(0, w, i);
         if(StringFind(ind_name, "Chaos Weighted Stochastic") >= 0 || (g_indicator_shortname != "" && ind_name == g_indicator_shortname))
            return w;
        }
     }

   if(total_windows > InpInstanceID)
      return InpInstanceID;
   if(total_windows > 1)
      return 1;

   return -1;
  }

//+------------------------------------------------------------------+
//| Clean Chart Graphical Objects with Isolated Namespace            |
//+------------------------------------------------------------------+
void CleanUp()
  {
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
//| Reset Divergence State Registers                                 |
//+------------------------------------------------------------------+
void ResetDivergenceRegisters()
  {
   g_last_proc_pivot_bar = -1;
   g_last_bar_lo         = -1;
   g_last_bar_hi         = -1;
   g_last_k_lo           = WRONG_VALUE;
   g_last_k_hi           = WRONG_VALUE;
   g_last_prc_lo         = WRONG_VALUE;
   g_last_prc_hi         = WRONG_VALUE;
   g_divergences_ready   = false;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
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

// 2. Build Fully Isolated Deterministic Instance Namespace
   g_prefix = StringFormat("CWSTOCH_%I64d_%s_%d_%d_%d_%d_",
                           ChartID(),
                           EnumToString(g_calc_timeframe),
                           InpKPeriod,
                           InpSlowingPeriod,
                           InpDisorderLength,
                           InpInstanceID);
   CleanUp();

   g_data_ready        = false;
   g_data_synced       = false;
   g_htf_count         = 0;
   g_last_htf_time     = 0;

   ResetDivergenceRegisters();

// 3. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);

   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   ArrayInitialize(BufferK, 50.0);
   ArrayInitialize(BufferD, 50.0);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorK);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthK);

// Configure %D Signal Line
   if(!InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorD);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleD);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthD);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   g_calc = new CChaosWeightedStochastic_Calculator();
   if(CheckPointer(g_calc) == POINTER_INVALID ||
      !g_calc.Init(InpKPeriod, InpSlowingPeriod, InpDPeriod, InpDMAType, InpDisorderLength, InpSensitivity, InpCandleSource))
     {
      Print("Critical Error: Failed to initialize CChaosWeightedStochastic_Calculator.");
      return INIT_FAILED;
     }

   string ha_str   = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string inst_str = (InpInstanceID > 1) ? StringFormat(" #%d", InpInstanceID) : "";
   g_indicator_shortname = StringFormat("Chaos Weighted Stoch%s%s(%d,%d,%d)%s", ha_str, tf_str, InpKPeriod, InpSlowingPeriod, InpDPeriod, inst_str);
   IndicatorSetString(INDICATOR_SHORTNAME, g_indicator_shortname);

// 5. Background Timer for MTF synchronization
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

   CleanUp();

   if(CheckPointer(g_calc) != POINTER_INVALID)
     {
      delete g_calc;
      g_calc = NULL;
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Process Non-Repainting Divergences on %K                         |
//+------------------------------------------------------------------+
bool ProcessDivergences(const int total_bars, const int prev_calc,
                        const datetime &t_arr[], const double &h_arr[], const double &l_arr[],
                        const double &k_arr[])
  {
   if(!InpShowDivLines)
      return true;

   int d = InpDivStrength;
   int subwin = GetIndicatorSubwindow();
   if(subwin < 0)
      return false;

   int max_eval = total_bars - d - 1;
   int min_eval = MathMax(d * 2, (prev_calc > 0 && g_divergences_ready ? prev_calc - d - 2 : d * 2));

   if(prev_calc == 0 || !g_divergences_ready)
      ResetDivergenceRegisters();

   for(int bar = min_eval; bar <= max_eval; bar++)
     {
      if(bar <= g_last_proc_pivot_bar)
         continue;

      int pBar = bar;
      double k_val = k_arr[pBar];
      if(k_val == EMPTY_VALUE)
         continue;

      // 1. Pivot Low Inspection
      bool is_p_low = true;
      for(int j = 1; j <= d; j++)
        {
         if(k_arr[pBar - j] <= k_val || k_arr[pBar + j] < k_val)
           {
            is_p_low = false;
            break;
           }
        }

      if(is_p_low)
        {
         if(g_last_bar_lo != -1 && (pBar - g_last_bar_lo <= 120))
           {
            // Regular Bullish Divergence: Lower Price Low + Higher Stochastic Low
            if(k_val > g_last_k_lo && l_arr[pBar] < g_last_prc_lo)
              {
               string line_name = StringFormat("%sBL_%I64d", g_prefix, (long)t_arr[pBar]);
               ObjectCreate(0, line_name, OBJ_TREND, subwin, t_arr[g_last_bar_lo], g_last_k_lo, t_arr[pBar], k_val);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBullDivColor);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
              }
           }
         g_last_k_lo   = k_val;
         g_last_prc_lo = l_arr[pBar];
         g_last_bar_lo = pBar;
        }

      // 2. Pivot High Inspection
      bool is_p_high = true;
      for(int j = 1; j <= d; j++)
        {
         if(k_arr[pBar - j] >= k_val || k_arr[pBar + j] > k_val)
           {
            is_p_high = false;
            break;
           }
        }

      if(is_p_high)
        {
         if(g_last_bar_hi != -1 && (pBar - g_last_bar_hi <= 120))
           {
            // Regular Bearish Divergence: Higher Price High + Lower Stochastic High
            if(k_val < g_last_k_hi && h_arr[pBar] > g_last_prc_hi)
              {
               string line_name = StringFormat("%sSL_%I64d", g_prefix, (long)t_arr[pBar]);
               ObjectCreate(0, line_name, OBJ_TREND, subwin, t_arr[g_last_bar_hi], g_last_k_hi, t_arr[pBar], k_val);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBearDivColor);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
              }
           }
         g_last_k_hi   = k_val;
         g_last_prc_hi = h_arr[pBar];
         g_last_bar_hi = pBar;
        }

      g_last_proc_pivot_bar = bar;
     }

   g_divergences_ready = true;
   return true;
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
   int warmup = g_calc ? g_calc.GetWarmupBars() : 25;
   int required_bars = warmup + InpDivStrength * 2 + 5;
   if(rates_total < required_bars || !g_calc)
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
      // 1. Calculate Chaos-Weighted Stochastic %K and %D
      g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD, InpHistoryBars);

      // 2. Process Native Chart Divergences
      if(ProcessDivergences(rates_total, prev_calculated, time, high, low, BufferK))
         ChartRedraw(0);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = required_bars + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform full history sync once
   if(htf_updated || prev_calculated == 0 || !g_divergences_ready)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars_mtf)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 2000);

      if(ArraySize(h_time) != g_htf_count)
        {
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
        }

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

      // Compute HTF Pure %K and %D
      g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_k, h_res_d, InpHistoryBars);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferK[i] = 50.0;
            BufferD[i] = 50.0;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferK[i] = h_res_k[htf_ptr];
         BufferD[i] = InpShowSignal ? h_res_d[htf_ptr] : EMPTY_VALUE;
        }

      // TRUE MTF DIVERGENCES: Evaluated in the clean HTF domain
      if(ProcessDivergences(g_htf_count, 0, h_time, h_high, h_low, h_res_k))
         ChartRedraw(0);

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update forming candle in RAM!
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

         g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_k, h_res_d, InpHistoryBars);
        }
     }

// Instant Binary Search for Forming Block Start
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Vectorized Assignment across forming block
   double k_val = h_res_k[live_idx];
   double d_val = InpShowSignal ? h_res_d[live_idx] : EMPTY_VALUE;

   for(int i = start; i < rates_total; i++)
     {
      BufferK[i] = k_val;
      BufferD[i] = d_val;
     }

   if(!g_divergences_ready)
     {
      if(ProcessDivergences(g_htf_count, 0, h_time, h_high, h_low, h_res_k))
         ChartRedraw(0);
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = g_calc ? g_calc.GetWarmupBars() : 25;
   int required_bars_mtf = warmup + InpDivStrength * 2 + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars_mtf, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
