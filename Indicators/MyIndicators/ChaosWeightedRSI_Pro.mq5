//+------------------------------------------------------------------+
//|                                         ChaosWeightedRSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.50" // Enterprise Edition: Multi-Instance Namespace Isolation & Subwindow Auto-Binding
#property description "Chaos Weighted RSI with Central Fractal Engine & Clean MTF Subwindow Trendlines."
#property description "Features authentic Higher Timeframe divergence detection with persistent timeframe-switch rendering."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1      70.0
#property indicator_level2      50.0
#property indicator_level3      30.0
#property indicator_levelcolor  clrSilver
#property indicator_levelstyle  STYLE_DOT
#property indicator_minimum    0.0
#property indicator_maximum    100.0

// Plot 1: Clean Monochrome WRSI Line
#property indicator_label1  "Chaos Weighted RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Optional Moving Average Signal Line
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\ChaosWeightedRSI_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe        = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "=== RSI & Chaos Settings ==="
input int                       InpRSILength        = 14;                  // Base RSI Length
input int                       InpDisorderLength   = 20;                  // Disorder Lookback (FDI Period)
input double                    InpSensitivity      = 1.0;                 // Chaos Dampening Sensitivity (0.1 - 5.0)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource      = PRICE_CLOSE_STD;     // Applied Price (Standard / Heikin Ashi)
input int                       InpHistoryBars      = 1000;                // History Bars Limit (0 = Full Chart)

input group "=== Visuals ==="
input color                     InpColorRSI         = clrDodgerBlue;       // RSI Line Color
input int                       InpWidthRSI         = 2;                   // RSI Line Width

input group "=== Signal Line Settings ==="
input bool                      InpShowSignal       = false;               // Display Signal Line (Optional)
input int                       InpSignalPeriod     = 9;                   // Signal Smoothing Period
input ENUM_MA_TYPE              InpSignalType       = EMA;                 // Signal Line MA Type (Engine Standard)
input color                     InpColorSignal      = clrMagenta;          // Signal Line Color (Universal Contrast)
input ENUM_LINE_STYLE           InpStyleSignal      = STYLE_SOLID;         // Signal Line Style
input int                       InpWidthSignal      = 2;                   // Signal Line Width

input group "=== Divergence Settings ==="
input bool                      InpShowDivLines     = true;                // Draw Divergence Lines in Subwindow
input int                       InpDivStrength      = 15;                  // Divergence Pivot Strength (Confirm Bars)
input color                     InpBullDivColor     = clrMediumSeaGreen;   // Bullish Divergence Line Color
input color                     InpBearDivColor     = clrCrimson;          // Bearish Divergence Line Color

input group "=== Multi-Instance Settings ==="
input int                       InpInstanceID       = 1;                   // Unique Instance ID (for multiple indicators on 1 chart)

//--- Visual Indicator Buffers
double BufferWRSI[];
double BufferSignal[];

//--- Volume Cache (For Engine Calculation)
double g_double_volume[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
double   h_double_vol[];
double   h_res_wrsi[];
double   h_res_sig[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CChaosWeightedRSI_Calculator *g_calc              = NULL;
CMovingAverageCalculator     *g_signal_calculator = NULL;
string                        g_prefix            = "";
string                        g_indicator_shortname = "";

bool            g_is_mtf_mode        = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready         = false;
bool            g_data_synced        = false;
int             g_htf_count          = 0;
datetime        g_last_htf_time      = 0;
bool            g_divergences_ready  = false; // State-guard for timeframe-switch resilience

//--- Divergence Internal Tracking Registers
double g_last_rsi_lo  = WRONG_VALUE;
double g_last_prc_lo  = WRONG_VALUE;
int    g_last_bar_lo  = -1;

double g_last_rsi_hi  = WRONG_VALUE;
double g_last_prc_hi  = WRONG_VALUE;
int    g_last_bar_hi  = -1;

int    g_last_proc_pivot_bar = -1;

//+------------------------------------------------------------------+
//| Resilient Indicator Subwindow Locator                            |
//+------------------------------------------------------------------+
int GetIndicatorSubwindow()
  {
// 1. Try finding by unique shortname
   if(g_indicator_shortname != "")
     {
      int subwin = ChartWindowFind(0, g_indicator_shortname);
      if(subwin >= 0)
         return subwin;
     }

// 2. Fallback: Search all chart subwindows for matching indicator name fragment
   int total_windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 1; w < total_windows; w++)
     {
      int total_indicators = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total_indicators; i++)
        {
         string ind_name = ChartIndicatorName(0, w, i);
         if(StringFind(ind_name, "Chaos Weighted RSI") >= 0 || (g_indicator_shortname != "" && ind_name == g_indicator_shortname))
            return w;
        }
     }

// 3. Fallback: Return subwindow matching instance ID if available
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
   g_last_rsi_lo         = WRONG_VALUE;
   g_last_rsi_hi         = WRONG_VALUE;
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
   g_prefix = StringFormat("CWRSI_%I64d_%s_%d_%d_%d_",
                           ChartID(),
                           EnumToString(g_calc_timeframe),
                           InpRSILength,
                           InpDisorderLength,
                           InpInstanceID);
   CleanUp();

   g_data_ready        = false;
   g_data_synced       = false;
   g_htf_count         = 0;
   g_last_htf_time     = 0;

   ResetDivergenceRegisters();

// 3. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufferWRSI,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferWRSI,   false);
   ArraySetAsSeries(BufferSignal, false);

   ArrayInitialize(BufferWRSI,   50.0);
   ArrayInitialize(BufferSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorRSI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthRSI);

// Configure Signal Line Visibility & Style
   if(!InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignal);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSignal);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSignal);

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize CMovingAverageCalculator for Signal Line.");
         return INIT_FAILED;
        }
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   g_calc = new CChaosWeightedRSI_Calculator();
   if(CheckPointer(g_calc) == POINTER_INVALID ||
      !g_calc.Init(InpRSILength, InpDisorderLength, InpSensitivity, InpPriceSource))
     {
      Print("Critical Error: Failed to initialize CChaosWeightedRSI_Calculator.");
      return INIT_FAILED;
     }

   string ha_str   = (InpPriceSource <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string inst_str = (InpInstanceID > 1) ? StringFormat(" #%d", InpInstanceID) : "";
   g_indicator_shortname = StringFormat("Chaos Weighted RSI%s%s(%d,%d)%s", ha_str, tf_str, InpRSILength, InpDisorderLength, inst_str);
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
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      delete g_signal_calculator;
      g_signal_calculator = NULL;
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Process Non-Repainting Divergences with Absolute Time Coordinates |
//+------------------------------------------------------------------+
bool ProcessDivergences(const int total_bars, const int prev_calc,
                        const datetime &t_arr[], const double &h_arr[], const double &l_arr[],
                        const double &rsi_arr[])
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
      double rsi_val = rsi_arr[pBar];
      if(rsi_val == EMPTY_VALUE)
         continue;

      // 1. Pivot Low Inspection
      bool is_p_low = true;
      for(int j = 1; j <= d; j++)
        {
         if(rsi_arr[pBar - j] <= rsi_val || rsi_arr[pBar + j] < rsi_val)
           {
            is_p_low = false;
            break;
           }
        }

      if(is_p_low)
        {
         if(g_last_bar_lo != -1 && (pBar - g_last_bar_lo <= 120))
           {
            // Regular Bullish Divergence
            if(rsi_val > g_last_rsi_lo && l_arr[pBar] < g_last_prc_lo)
              {
               string line_name = StringFormat("%sBL_%I64d", g_prefix, (long)t_arr[pBar]);
               ObjectCreate(0, line_name, OBJ_TREND, subwin, t_arr[g_last_bar_lo], g_last_rsi_lo, t_arr[pBar], rsi_val);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBullDivColor);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
              }
           }
         g_last_rsi_lo = rsi_val;
         g_last_prc_lo = l_arr[pBar];
         g_last_bar_lo = pBar;
        }

      // 2. Pivot High Inspection
      bool is_p_high = true;
      for(int j = 1; j <= d; j++)
        {
         if(rsi_arr[pBar - j] >= rsi_val || rsi_arr[pBar + j] > rsi_val)
           {
            is_p_high = false;
            break;
           }
        }

      if(is_p_high)
        {
         if(g_last_bar_hi != -1 && (pBar - g_last_bar_hi <= 120))
           {
            // Regular Bearish Divergence
            if(rsi_val < g_last_rsi_hi && h_arr[pBar] > g_last_prc_hi)
              {
               string line_name = StringFormat("%sSL_%I64d", g_prefix, (long)t_arr[pBar]);
               ObjectCreate(0, line_name, OBJ_TREND, subwin, t_arr[g_last_bar_hi], g_last_rsi_hi, t_arr[pBar], rsi_val);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, InpBearDivColor);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
              }
           }
         g_last_rsi_hi = rsi_val;
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
      if(ArraySize(g_double_volume) != rates_total)
        {
         ArrayResize(g_double_volume, rates_total);
         ArraySetAsSeries(g_double_volume, false);
        }

      int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      if(volume_limit > 0)
        {
         for(int i = start_sync; i < rates_total; i++)
            g_double_volume[i] = (double)volume[i];
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            g_double_volume[i] = (double)tick_volume[i];
        }

      // 1. Compute Chaos-Weighted RSI
      g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, BufferWRSI, InpHistoryBars);

      int actual_start = warmup;
      if(InpHistoryBars > 0 && prev_calculated == 0)
        {
         int limit_start = rates_total - InpHistoryBars;
         if(limit_start > actual_start)
            actual_start = limit_start;
        }

      // 2. Compute Optional Signal MA Line
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferWRSI, g_double_volume, BufferSignal, actual_start);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufferSignal[i] = EMPTY_VALUE;
        }

      // 3. Process Native Chart Divergences
      if(ProcessDivergences(rates_total, prev_calculated, time, high, low, BufferWRSI))
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
         ArrayResize(h_time,       g_htf_count);
         ArrayResize(h_open,       g_htf_count);
         ArrayResize(h_high,       g_htf_count);
         ArrayResize(h_low,        g_htf_count);
         ArrayResize(h_close,      g_htf_count);
         ArrayResize(h_tick_vol,   g_htf_count);
         ArrayResize(h_vol,        g_htf_count);
         ArrayResize(h_double_vol, g_htf_count);
         ArrayResize(h_res_wrsi,   g_htf_count);
         ArrayResize(h_res_sig,    g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_tick_vol,   false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_double_vol, false);
         ArraySetAsSeries(h_res_wrsi,   false);
         ArraySetAsSeries(h_res_sig,    false);
        }

      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]       = htf_bulk_rates[i].time;
         h_open[i]       = htf_bulk_rates[i].open;
         h_high[i]       = htf_bulk_rates[i].high;
         h_low[i]        = htf_bulk_rates[i].low;
         h_close[i]      = htf_bulk_rates[i].close;
         h_tick_vol[i]   = htf_bulk_rates[i].tick_volume;
         h_vol[i]        = (long)htf_bulk_rates[i].real_volume;
         h_double_vol[i] = (h_vol[i] > 0) ? (double)h_vol[i] : (double)h_tick_vol[i];
        }

      // Compute HTF Pure WRSI on HTF Series
      g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_wrsi, InpHistoryBars);

      // Compute HTF Signal Line via Unified Engine
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_wrsi, h_double_vol, h_res_sig, htf_actual_start);
        }

      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferWRSI[i]   = 50.0;
            BufferSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferWRSI[i]   = h_res_wrsi[htf_ptr];
         BufferSignal[i] = (InpShowSignal && h_res_sig[htf_ptr] != EMPTY_VALUE) ? h_res_sig[htf_ptr] : EMPTY_VALUE;
        }

      // TRUE MTF DIVERGENCES: With resilient retry until confirmed drawn
      if(ProcessDivergences(g_htf_count, 0, h_time, h_high, h_low, h_res_wrsi))
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
         h_time[live_idx]       = htf_rate[0].time;
         h_open[live_idx]       = htf_rate[0].open;
         h_high[live_idx]       = htf_rate[0].high;
         h_low[live_idx]        = htf_rate[0].low;
         h_close[live_idx]      = htf_rate[0].close;
         h_tick_vol[live_idx]   = htf_rate[0].tick_volume;
         h_vol[live_idx]        = (long)htf_rate[0].real_volume;
         h_double_vol[live_idx] = (h_vol[live_idx] > 0) ? (double)h_vol[live_idx] : (double)h_tick_vol[live_idx];

         g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_wrsi, InpHistoryBars);

         if(InpShowSignal && g_signal_calculator != NULL)
           {
            int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_wrsi, h_double_vol, h_res_sig, htf_actual_start);
           }
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
   double wrsi_val = h_res_wrsi[live_idx];
   double sig_val  = InpShowSignal ? h_res_sig[live_idx] : EMPTY_VALUE;

   for(int i = start; i < rates_total; i++)
     {
      BufferWRSI[i]   = wrsi_val;
      BufferSignal[i] = sig_val;
     }

// Retry divergence rendering on live ticks if window indexing was delayed during TF switch
   if(!g_divergences_ready)
     {
      if(ProcessDivergences(g_htf_count, 0, h_time, h_high, h_low, h_res_wrsi))
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
