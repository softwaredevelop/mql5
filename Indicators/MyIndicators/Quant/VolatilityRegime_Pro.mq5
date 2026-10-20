//+------------------------------------------------------------------+
//|                                         VolatilityRegime_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.40" // Enterprise Edition: Robust CalculateOnArray Offset Alignment & Zero MTF Crashes
#property description "Institutional Volatility Regime (Expansion vs Contraction Ratio)."
#property description "Driven by unified CMovingAverageCalculator and CATRCalculator with full MTF Fast-Path."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1 0.75
#property indicator_level2 1.00
#property indicator_level3 1.50
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot 1: Volatility Ratio Plot (Pre-allocated 4 color slots)
#property indicator_label1  "Vola Ratio"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrGray, clrLime, clrDarkOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Volatility Signal Line
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Visual Style Selector
enum ENUM_VOLA_VISUAL
  {
   VISUAL_VOLA_LINE,      // Dynamic Multi-Color Line (Clean Continuous Curve)
   VISUAL_VOLA_HISTOGRAM  // Dynamic Color Histogram (Anchored at 0.0 baseline)
  };

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

input group "--- Volatility Engine Settings ---"
input int                       InpPeriodFast     = 5;                      // Short-term ATR Period
input int                       InpPeriodSlow     = 50;                     // Long-term Baseline ATR Period
input ENUM_CANDLE_SOURCE        InpCandleSource   = CANDLE_STANDARD;        // Candle Source (Standard vs Heikin Ashi)
input int                       InpHistoryBars    = 1000;                   // History Bars Limit (0 = Full Chart)

input group "--- Regime Thresholds ---"
input double                    InpLevelSqueeze   = 0.75;                   // Squeeze Threshold (Below = Extreme Coiling)
input double                    InpLevelExpansion = 1.00;                   // Expansion Baseline (Above = Trend/Breakout)
input double                    InpLevelClimax    = 1.50;                   // Climax Threshold (Above = Volatility Blowout)

input group "--- Visual Appearance ---"
input ENUM_VOLA_VISUAL          InpVisualType     = VISUAL_VOLA_HISTOGRAM;  // Display Mode (Line vs Histogram)
input color                     InpColorSqueeze   = clrDodgerBlue;          // Squeeze Color (< 0.75)
input color                     InpColorQuiet     = clrGray;                // Quiet / Contraction Color (0.75 - 1.00)
input color                     InpColorExpand    = clrLime;                // Expansion Color (1.00 - 1.50)
input color                     InpColorClimax    = clrDarkOrange;          // Climax / Blowout Color (> 1.50)
input int                       InpWidthPlot      = 2;                      // Main Plot Width

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal     = true;                   // Display Signal Line
input int                       InpSignalPeriod   = 9;                      // Signal Smoothing Period
input ENUM_MA_TYPE              InpSignalType     = EMA;                    // Signal Line MA Type (SMA, EMA, SMMA, LWMA, DEMA, TEMA, VWMA)
input color                     InpColorSignal    = clrMagenta;             // Signal Line Color (Universal Contrast)
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;            // Signal Line Style
input int                       InpWidthSignal    = 2;                      // Signal Line Width

//--- Visual Indicator Buffers
double BufRatio[];
double BufColors[];
double BufSignal[];

//--- Volume Cache (For Engine Calculation)
double g_double_volume[];

//--- Persistent Native Calculation Registers (Zero Heap Thrashing!)
double m_atr_fast[];
double m_atr_slow[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
double   h_double_vol[];
double   h_atr_fast[];
double   h_atr_slow[];
double   h_res_ratio[];
double   h_res_sig[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CATRCalculator           *g_atr_fast          = NULL;
CATRCalculator           *g_atr_slow          = NULL;
CMovingAverageCalculator *g_signal_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

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
   SetIndexBuffer(0, BufRatio,  INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufRatio,  false);
   ArraySetAsSeries(BufColors, false);
   ArraySetAsSeries(BufSignal, false);

   ArrayInitialize(BufRatio,  EMPTY_VALUE);
   ArrayInitialize(BufColors, 0.0);
   ArrayInitialize(BufSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 3. Configure Visual Appearance & Plot Type
   if(InpVisualType == VISUAL_VOLA_HISTOGRAM)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      IndicatorSetDouble(INDICATOR_MINIMUM, 0.0); // Baseline anchored at 0.0
     }
   else
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
     }

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPlot);

// Pre-allocate and assign 4 dynamic color slots
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorSqueeze); // Slot 0: Deep Squeeze (< 0.75)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorQuiet);   // Slot 1: Quiet / Contraction (0.75 - 1.00)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorExpand);  // Slot 2: Active Expansion (1.00 - 1.50)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, InpColorClimax);  // Slot 3: Volatility Climax (>= 1.50)

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
     }

// Configure Dynamic Threshold Levels on Subwindow
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelSqueeze);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelExpansion);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelClimax);

// 4. Initialize Core ATR Engines (Standard or Heikin Ashi)
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_atr_fast = new CATRCalculator_HA();
      g_atr_slow = new CATRCalculator_HA();
     }
   else
     {
      g_atr_fast = new CATRCalculator();
      g_atr_slow = new CATRCalculator();
     }

   if(CheckPointer(g_atr_fast) == POINTER_INVALID || CheckPointer(g_atr_slow) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to instantiate ATR Calculators.");
      return INIT_FAILED;
     }

   if(!g_atr_fast.Init(InpPeriodFast, ATR_POINTS) || !g_atr_slow.Init(InpPeriodSlow, ATR_POINTS))
     {
      Print("Critical Error: Failed to initialize ATR Calculators.");
      return INIT_FAILED;
     }

// 5. Initialize Unified Moving Average Engine for Signal Line
   if(InpShowSignal)
     {
      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize CMovingAverageCalculator for Signal Line.");
         return INIT_FAILED;
        }
     }

   string ha_tag   = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string ma_str   = EnumToString(InpSignalType);
   string name     = StringFormat("VolaRegime%s%s(%d/%d|%s %d)", ha_tag, tf_str, InpPeriodFast, InpPeriodSlow, ma_str, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 6. Background Timer for MTF synchronization
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

   if(CheckPointer(g_atr_fast) != POINTER_INVALID)
     {
      delete g_atr_fast;
      g_atr_fast = NULL;
     }
   if(CheckPointer(g_atr_slow) != POINTER_INVALID)
     {
      delete g_atr_slow;
      g_atr_slow = NULL;
     }
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      delete g_signal_calculator;
      g_signal_calculator = NULL;
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
   int warmup = MathMax(InpPeriodFast, InpPeriodSlow) + 2;
   int required_bars = warmup + InpSignalPeriod + 10;
   if(rates_total < required_bars || !g_atr_fast || !g_atr_slow)
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
      if(ArraySize(m_atr_fast) != rates_total)
        {
         ArrayResize(m_atr_fast, rates_total);
         ArrayResize(m_atr_slow, rates_total);
         ArraySetAsSeries(m_atr_fast, false);
         ArraySetAsSeries(m_atr_slow, false);
        }

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

      // 1. Calculate Fast and Slow ATR in O(1)
      g_atr_fast.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_fast);
      g_atr_slow.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_slow);

      int start = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
      int actual_start = warmup;

      if(InpHistoryBars > 0 && prev_calculated == 0)
        {
         int limit_start = rates_total - InpHistoryBars;
         if(limit_start > start)
           {
            start = limit_start;
            actual_start = limit_start;
           }
        }

      if(prev_calculated == 0)
        {
         for(int i = 0; i < start; i++)
           {
            BufRatio[i]  = EMPTY_VALUE;
            BufColors[i] = 1.0;
            BufSignal[i] = EMPTY_VALUE;
           }
        }

      // 2. Compute Unitless Volatility Ratio & Color Mapping
      for(int i = start; i < rates_total; i++)
        {
         double slow = m_atr_slow[i];
         double fast = m_atr_fast[i];

         if(slow > 1.0e-9)
           {
            double ratio = fast / slow;
            BufRatio[i]  = ratio;

            if(ratio < InpLevelSqueeze)
               BufColors[i] = 0.0; // Slot 0: Deep Squeeze (Blue)
            else
               if(ratio < InpLevelExpansion)
                  BufColors[i] = 1.0; // Slot 1: Normal Quiet (Gray)
               else
                  if(ratio < InpLevelClimax)
                     BufColors[i] = 2.0; // Slot 2: Active Expansion (Lime)
                  else
                     BufColors[i] = 3.0; // Slot 3: Volatility Climax (Dark Orange)
           }
         else
           {
            BufRatio[i]  = 1.0;
            BufColors[i] = 1.0;
           }
        }

      // 3. Compute Signal Line via Unified CalculateOnArray Engine with exact actual_start offset
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufRatio, g_double_volume, BufSignal, actual_start);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufSignal[i] = EMPTY_VALUE;
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = warmup + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
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
         ArrayResize(h_atr_fast,   g_htf_count);
         ArrayResize(h_atr_slow,   g_htf_count);
         ArrayResize(h_res_ratio,  g_htf_count);
         ArrayResize(h_res_sig,    g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_tick_vol,   false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_double_vol, false);
         ArraySetAsSeries(h_atr_fast,   false);
         ArraySetAsSeries(h_atr_slow,   false);
         ArraySetAsSeries(h_res_ratio,  false);
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

      g_atr_fast.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_atr_fast);
      g_atr_slow.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_atr_slow);

      for(int i = 0; i < g_htf_count; i++)
        {
         if(h_atr_slow[i] > 1.0e-9)
            h_res_ratio[i] = h_atr_fast[i] / h_atr_slow[i];
         else
            h_res_ratio[i] = 1.0;
        }

      // Compute HTF Signal Line via Unified Engine with exact persistent volume buffer
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_ratio, h_double_vol, h_res_sig, htf_actual_start);
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
            BufRatio[i]  = EMPTY_VALUE;
            BufColors[i] = 1.0;
            BufSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double ratio = h_res_ratio[htf_ptr];
         BufRatio[i]  = ratio;

         if(ratio == EMPTY_VALUE)
           {
            BufColors[i] = 1.0;
            BufSignal[i] = EMPTY_VALUE;
           }
         else
           {
            if(ratio < InpLevelSqueeze)
               BufColors[i] = 0.0;
            else
               if(ratio < InpLevelExpansion)
                  BufColors[i] = 1.0;
               else
                  if(ratio < InpLevelClimax)
                     BufColors[i] = 2.0;
                  else
                     BufColors[i] = 3.0;

            BufSignal[i] = (InpShowSignal && h_res_sig[htf_ptr] != EMPTY_VALUE) ? h_res_sig[htf_ptr] : EMPTY_VALUE;
           }
        }

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

         g_atr_fast.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_atr_fast);
         g_atr_slow.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_atr_slow);

         if(h_atr_slow[live_idx] > 1.0e-9)
            h_res_ratio[live_idx] = h_atr_fast[live_idx] / h_atr_slow[live_idx];
         else
            h_res_ratio[live_idx] = 1.0;

         // SAFE INCREMENTAL UPDATE: Passes full-size h_double_vol array! Zero out-of-bounds!
         if(InpShowSignal && g_signal_calculator != NULL)
           {
            int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_ratio, h_double_vol, h_res_sig, htf_actual_start);
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
   double ratio_val = h_res_ratio[live_idx];
   double col_val   = 1.0;
   double sig_val   = InpShowSignal ? h_res_sig[live_idx] : EMPTY_VALUE;

   if(ratio_val != EMPTY_VALUE)
     {
      if(ratio_val < InpLevelSqueeze)
         col_val = 0.0;
      else
         if(ratio_val < InpLevelExpansion)
            col_val = 1.0;
         else
            if(ratio_val < InpLevelClimax)
               col_val = 2.0;
            else
               col_val = 3.0;
     }

   for(int i = start; i < rates_total; i++)
     {
      BufRatio[i]  = ratio_val;
      BufColors[i] = col_val;
      BufSignal[i] = sig_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpPeriodFast, InpPeriodSlow) + 2;
   int required_bars_mtf = warmup + InpSignalPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars_mtf, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
