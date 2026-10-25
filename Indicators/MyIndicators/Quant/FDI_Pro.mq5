//+------------------------------------------------------------------+
//|                                                      FDI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.40" // Enterprise Edition: MovingAverage_Engine Integration & Heikin Ashi Pipeline
#property description "Fractal Dimension Index (FDI) with High-Performance Multi-Timeframe Engine."
#property description "Features unified MovingAverage_Engine Signal Line and full Heikin Ashi price routing."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1 1.45
#property indicator_level2 1.50
#property indicator_level3 1.55
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot 1: FDI Main Plot (Pre-allocated 3 color slots)
#property indicator_label1  "FDI"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDeepSkyBlue, clrGold, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: FDI Signal Line (High-contrast Magenta overlay)
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\FDI_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Visual Style Selector
enum ENUM_FDI_VISUAL
  {
   VISUAL_FDI_LINE,       // Dynamic Multi-Color Line (Clean Continuous Curve)
   VISUAL_FDI_HISTOGRAM   // Dynamic Color Histogram
  };

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe         = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

input group "--- FDI Settings ---"
input int                       InpPeriod            = 30;                     // Analysis Window (N, recommended 20-50)
input ENUM_FDI_METHOD           InpMethod            = FDI_NORMALIZED_BROWNIAN;// Calculation Method (Brownian = True 1.50 baseline)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource       = PRICE_CLOSE_STD;        // Price Source (Standard / Heikin Ashi)
input int                       InpHistoryBars       = 1000;                   // History Bars Limit (0 = Full Chart)

input group "--- Regime Thresholds ---"
input bool                      InpAutoThresholds    = true;                   // Auto-Adapt Thresholds to chosen Period & Method
input double                    InpLevelTrend        = 1.45;                   // Manual Trend Threshold (if Auto is false)
input double                    InpLevelChop         = 1.55;                   // Manual Chop Threshold (if Auto is false)

input group "--- Visual Appearance ---"
input ENUM_FDI_VISUAL           InpVisualType        = VISUAL_FDI_LINE;        // Display Mode (Line vs Histogram)
input color                     InpColorTrend        = clrDeepSkyBlue;         // Persistent Trend (Order)
input color                     InpColorRandom       = clrGold;                // Random Walk Equilibrium
input color                     InpColorChop         = clrCrimson;             // Anti-persistent Chop (Chaos)
input int                       InpWidthPlot         = 2;                      // Main Plot Width

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal        = true;                   // Display Signal Line
input int                       InpSignalPeriod      = 9;                      // Signal Smoothing Period
input ENUM_MA_TYPE              InpSignalType        = EMA;                    // Signal Line MA Type (Engine Standard)
input color                     InpColorSignal       = clrMagenta;             // Signal Line Color (Universal Contrast)
input ENUM_LINE_STYLE           InpStyleSignal       = STYLE_SOLID;            // Signal Line Style
input int                       InpWidthSignal       = 2;                      // Signal Line Width

input group "--- Multi-Instance Settings ---"
input int                       InpInstanceID        = 1;                      // Unique Instance ID (for multiple indicators on 1 chart)

//--- Visual Indicator Buffers
double BufFDI[];
double BufColor[];
double BufSignal[];

//--- Volume Cache (For Engine Calculation)
double g_double_volume[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
double   h_double_vol[];
double   h_res_fdi[];
double   h_res_sig[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CFDICalculator           *g_calc              = NULL;
CMovingAverageCalculator *g_signal_calculator = NULL;
string                    g_prefix            = "";

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

double          g_level_trend   = 1.45;
double          g_level_random  = 1.50;
double          g_level_chop    = 1.55;

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
   g_prefix = StringFormat("FDI_%I64d_%s_%d_%d_",
                           ChartID(),
                           EnumToString(g_calc_timeframe),
                           InpPeriod,
                           InpInstanceID);
   ObjectsDeleteAll(0, g_prefix);

   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 3. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufFDI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufColor,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufFDI,    false);
   ArraySetAsSeries(BufColor,  false);
   ArraySetAsSeries(BufSignal, false);

   ArrayInitialize(BufFDI,    EMPTY_VALUE);
   ArrayInitialize(BufColor,  0.0);
   ArrayInitialize(BufSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

// 4. Initialize Core Calculation Engine
   g_calc = new CFDICalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpMethod, InpPriceSource))
     {
      Print("Critical Error: Failed to initialize CFDICalculator.");
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

// 6. Auto-Calibrate Thresholds to the Exact Theoretical Distribution
   if(InpAutoThresholds)
     {
      g_level_random = g_calc.GetTheoreticalRandomWalkD();
      g_level_trend  = g_level_random - 0.05;
      g_level_chop   = g_level_random + 0.05;
     }
   else
     {
      g_level_trend  = InpLevelTrend;
      g_level_random = 1.50;
      g_level_chop   = InpLevelChop;
     }

// Configure Visual Appearance & Plot Type
   if(InpVisualType == VISUAL_FDI_HISTOGRAM)
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   else
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPlot);

// Assign 3 dynamic color slots
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorTrend);  // Index 0: Trend (< g_level_trend)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorRandom); // Index 1: Random (g_level_trend - g_level_chop)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorChop);   // Index 2: Chop (> g_level_chop)

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
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, g_level_trend);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, g_level_random);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, g_level_chop);

   string ha_tag   = (InpPriceSource <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string meth_str = (InpMethod == FDI_NORMALIZED_BROWNIAN) ? "Brownian" : ((InpMethod == FDI_CANONICAL_SEVCIK) ? "Sevcik" : "Classic");
   string ma_str   = EnumToString(InpSignalType);
   string inst_str = (InpInstanceID > 1) ? StringFormat(" #%d", InpInstanceID) : "";
   string name     = StringFormat("FDI%s%s(%d|%s|%s %d)%s", ha_tag, tf_str, InpPeriod, meth_str, ma_str, InpSignalPeriod, inst_str);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 7. Background Timer for MTF synchronization
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

   ObjectsDeleteAll(0, g_prefix);

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
   int warmup = InpPeriod + 2;
   int required_bars = warmup + InpSignalPeriod + 10;
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
      // Prepare volume cache for Signal MA engine
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

      // 1. Calculate FDI via Engine
      g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, BufFDI, InpHistoryBars);

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
            BufFDI[i]    = EMPTY_VALUE;
            BufColor[i]  = 1.0;
            BufSignal[i] = EMPTY_VALUE;
           }
        }

      // 2. Color Mapping
      for(int i = start; i < rates_total; i++)
        {
         double fdi = BufFDI[i];
         if(fdi == EMPTY_VALUE)
           {
            BufColor[i] = 1.0;
            continue;
           }

         if(fdi < g_level_trend)
            BufColor[i] = 0.0; // Persistent Trend (DeepSkyBlue)
         else
            if(fdi <= g_level_chop)
               BufColor[i] = 1.0; // Random Walk Equilibrium (Gold)
            else
               BufColor[i] = 2.0; // Anti-persistent Chop (Crimson Red)
        }

      // 3. Compute Signal Line via Unified CalculateOnArray Engine with exact actual_start offset
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufFDI, g_double_volume, BufSignal, actual_start);
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
         ArrayResize(h_res_fdi,    g_htf_count);
         ArrayResize(h_res_sig,    g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_tick_vol,   false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_double_vol, false);
         ArraySetAsSeries(h_res_fdi,    false);
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

      // Compute HTF FDI Values
      g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_fdi, InpHistoryBars);

      // Compute HTF Signal Line via Unified Engine
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_fdi, h_double_vol, h_res_sig, htf_actual_start);
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
            BufFDI[i]    = EMPTY_VALUE;
            BufColor[i]  = 1.0;
            BufSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double fdi = h_res_fdi[htf_ptr];
         BufFDI[i]  = fdi;

         if(fdi == EMPTY_VALUE)
           {
            BufColor[i] = 1.0;
           }
         else
           {
            if(fdi < g_level_trend)
               BufColor[i] = 0.0;
            else
               if(fdi <= g_level_chop)
                  BufColor[i] = 1.0;
               else
                  BufColor[i] = 2.0;
           }

         BufSignal[i] = (InpShowSignal && h_res_sig[htf_ptr] != EMPTY_VALUE) ? h_res_sig[htf_ptr] : EMPTY_VALUE;
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

         g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_fdi, InpHistoryBars);

         if(InpShowSignal && g_signal_calculator != NULL)
           {
            int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_fdi, h_double_vol, h_res_sig, htf_actual_start);
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
   double fdi_val = h_res_fdi[live_idx];
   double col_val = 1.0;
   double sig_val = InpShowSignal ? h_res_sig[live_idx] : EMPTY_VALUE;

   if(fdi_val != EMPTY_VALUE)
     {
      if(fdi_val < g_level_trend)
         col_val = 0.0;
      else
         if(fdi_val <= g_level_chop)
            col_val = 1.0;
         else
            col_val = 2.0;
     }

   for(int i = start; i < rates_total; i++)
     {
      BufFDI[i]   = fdi_val;
      BufColor[i] = col_val;
      BufSignal[i] = sig_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpPeriod + 2;
   int required_bars_mtf = warmup + InpSignalPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars_mtf, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
