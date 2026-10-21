//+------------------------------------------------------------------+
//|                                                     RVOL_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Enterprise Edition: Strict Real Volume Validation, Mute-on-Missing & Expert Logging
#property description "Relative Volume Indicator (RVOL) with Unified Native & MTF Support."
#property description "Highlights institutional activity spikes > 2.0 with strict broker volume capability validation."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1 1.00
#property indicator_level2 2.00
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot 1: RVOL Main Plot (Pre-allocated 3 color slots)
#property indicator_label1  "RVOL"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrDodgerBlue, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: RVOL Signal Line
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Visual Style Selector
enum ENUM_RVOL_VISUAL
  {
   VISUAL_RVOL_LINE,      // Dynamic Multi-Color Line (Clean Continuous Curve)
   VISUAL_RVOL_HISTOGRAM  // Dynamic Color Histogram (Anchored at 0.0 baseline)
  };

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe         = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

input group "--- RVOL Engine Settings ---"
input int                       InpPeriod            = 20;                     // Baseline Average Volume Period
input ENUM_APPLIED_VOLUME       InpVolumeType        = VOLUME_TICK;            // Volume Type (Tick or Real Volume)
input int                       InpHistoryBars       = 1000;                   // History Bars Limit (0 = Full Chart)

input group "--- Activity Thresholds ---"
input double                    InpThresholdNormal   = 1.00;                   // Above Average Activity Threshold
input double                    InpThresholdHigh     = 2.00;                   // Institutional Activity Spike Threshold

input group "--- Visual Appearance ---"
input ENUM_RVOL_VISUAL          InpVisualType        = VISUAL_RVOL_HISTOGRAM;  // Display Mode (Line vs Histogram)
input color                     InpColorLow          = clrGray;                // Low Volume (< 1.00)
input color                     InpColorNormal       = clrDodgerBlue;          // Normal Volume (1.00 - 2.00)
input color                     InpColorHigh         = clrOrangeRed;           // Institutional Spike (> 2.00)
input int                       InpWidthPlot         = 2;                      // Main Plot Width

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal        = true;                   // Display Signal Line
input int                       InpSignalPeriod      = 9;                      // Signal Smoothing Period
input ENUM_MA_TYPE              InpSignalType        = EMA;                    // Signal Line MA Type (Engine Standard)
input color                     InpColorSignal       = clrMagenta;             // Signal Line Color (Universal Contrast)
input ENUM_LINE_STYLE           InpStyleSignal       = STYLE_SOLID;            // Signal Line Style
input int                       InpWidthSignal       = 2;                      // Signal Line Width

//--- Visual Indicator Buffers
double BufferRVOL[];
double BufferColors[];
double BufferSignal[];

//--- Volume Caches (Persistent Memory to Eliminate Heap-Thrashing)
long   m_vol_long[];
double g_double_volume[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_vol_long[];
double   h_double_vol[];
double   h_res_rvol[];
double   h_res_sig[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CRelativeVolumeCalculator *g_calculator        = NULL;
CMovingAverageCalculator  *g_signal_calculator = NULL;

bool            g_is_mtf_mode        = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready         = false;
bool            g_data_synced        = false;
int             g_htf_count          = 0;
datetime        g_last_htf_time      = 0;
bool            g_real_vol_missing   = false; // Safety lock for missing exchange volume

//+------------------------------------------------------------------+
//| Helper: Strictly Validate Broker Real Volume Support             |
//+------------------------------------------------------------------+
bool ValidateRealVolumeSupport(const string sym, const ENUM_TIMEFRAMES tf)
  {
   long vol_limit = (long)SymbolInfoDouble(sym, SYMBOL_VOLUME_LIMIT);

   long check_rv[5];
   int copied = CopyRealVolume(sym, tf, 0, 5, check_rv);
   bool positive_real_vol = false;

   for(int i = 0; i < copied; i++)
     {
      if(check_rv[i] > 0)
        {
         positive_real_vol = true;
         break;
        }
     }

   if(vol_limit <= 0 && !positive_real_vol)
      return false; // Real volume is physically unsupported by broker feed

   return true;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready       = false;
   g_data_synced      = false;
   g_htf_count        = 0;
   g_last_htf_time    = 0;
   g_real_vol_missing = false;

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

// 2. Strict Real Volume Broker Validation
   if(InpVolumeType == VOLUME_REAL)
     {
      if(!ValidateRealVolumeSupport(_Symbol, g_calc_timeframe))
        {
         g_real_vol_missing = true;
         PrintFormat("CRITICAL WARNING [RVOL Pro]: Real Volume (InpVolumeType = VOLUME_REAL) is NOT supported by broker feed for '%s'! Indicator muted to prevent misleading data. Switch to VOLUME_TICK.",
                     _Symbol);
        }
     }

// 3. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufferRVOL,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferRVOL,   false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferSignal, false);

   ArrayInitialize(BufferRVOL,   EMPTY_VALUE);
   ArrayInitialize(BufferColors, 0.0);
   ArrayInitialize(BufferSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Anchor Subwindow Base strictly at 0.0
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);

// 5. Configure Visual Appearance & Plot Type
   if(InpVisualType == VISUAL_RVOL_HISTOGRAM)
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   else
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPlot);

// Pre-allocate and assign 3 dynamic color slots
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorLow);    // Slot 0: Below Average (< 1.00)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorNormal); // Slot 1: Active Normal (1.00 - 2.00)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorHigh);   // Slot 2: Institutional Spike (> 2.00)

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
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpThresholdNormal);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpThresholdHigh);

// 6. Initialize Core RVOL Calculator Engine
   g_calculator = new CRelativeVolumeCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Critical Error: Failed to initialize CRelativeVolumeCalculator.");
      return INIT_FAILED;
     }

// 7. Initialize Unified Moving Average Engine for Signal Line
   if(InpShowSignal)
     {
      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Critical Error: Failed to initialize CMovingAverageCalculator for Signal Line.");
         return INIT_FAILED;
        }
     }

   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string vol_str  = (InpVolumeType == VOLUME_REAL) ? "RealVol" : "TickVol";
   string ma_str   = EnumToString(InpSignalType);

   string name;
   if(g_real_vol_missing)
      name = StringFormat("RVOL%s [NO REAL VOLUME AVAILABLE ON BROKER FEED]", tf_str);
   else
      name = StringFormat("RVOL%s(%d|%s|%s %d)", tf_str, InpPeriod, vol_str, ma_str, InpSignalPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 8. Background Timer for MTF synchronization
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
// Guard 1: Mute immediately if Real Volume was requested but is not provided by broker
   if(g_real_vol_missing)
     {
      for(int i = 0; i < rates_total; i++)
        {
         BufferRVOL[i]   = EMPTY_VALUE;
         BufferColors[i] = 0.0;
         BufferSignal[i] = EMPTY_VALUE;
        }
      return rates_total;
     }

   int warmup = InpPeriod + 2;
   int required_bars = warmup + InpSignalPeriod + 10;
   if(rates_total < required_bars || !g_calculator)
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
      // Safe allocation of persistent volume buffers
      if(ArraySize(m_vol_long) != rates_total)
        {
         ArrayResize(m_vol_long,       rates_total);
         ArrayResize(g_double_volume,  rates_total);
         ArraySetAsSeries(m_vol_long,       false);
         ArraySetAsSeries(g_double_volume,  false);
        }

      int start_sync = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

      for(int i = start_sync; i < rates_total; i++)
        {
         // Strictly use requested volume type (No silent fallback!)
         m_vol_long[i]      = (InpVolumeType == VOLUME_REAL) ? (long)volume[i] : (long)tick_volume[i];
         g_double_volume[i] = (double)m_vol_long[i];
        }

      // 1. Calculate RVOL via Engine
      g_calculator.Calculate(rates_total, prev_calculated, m_vol_long, BufferRVOL, InpHistoryBars);

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
            BufferRVOL[i]   = EMPTY_VALUE;
            BufferColors[i] = 0.0;
            BufferSignal[i] = EMPTY_VALUE;
           }
        }

      // 2. Color Mapping
      for(int i = start; i < rates_total; i++)
        {
         double rvol = BufferRVOL[i];
         if(rvol == EMPTY_VALUE)
           {
            BufferColors[i] = 0.0;
            continue;
           }

         if(rvol >= InpThresholdHigh)
            BufferColors[i] = 2.0; // Institutional Spike (OrangeRed)
         else
            if(rvol >= InpThresholdNormal)
               BufferColors[i] = 1.0; // Active Normal (DodgerBlue)
            else
               BufferColors[i] = 0.0; // Below Average (Gray)
        }

      // 3. Compute Signal Line via Unified CalculateOnArray Engine with exact actual_start offset
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferRVOL, g_double_volume, BufferSignal, actual_start);
        }
      else
        {
         for(int i = start_sync; i < rates_total; i++)
            BufferSignal[i] = EMPTY_VALUE;
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
         ArrayResize(h_vol_long,   g_htf_count);
         ArrayResize(h_double_vol, g_htf_count);
         ArrayResize(h_res_rvol,   g_htf_count);
         ArrayResize(h_res_sig,    g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol_long,   false);
         ArraySetAsSeries(h_double_vol, false);
         ArraySetAsSeries(h_res_rvol,   false);
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
         h_vol_long[i]   = (InpVolumeType == VOLUME_REAL) ? (long)htf_bulk_rates[i].real_volume : (long)htf_bulk_rates[i].tick_volume;
         h_double_vol[i] = (double)h_vol_long[i];
        }

      // Compute HTF RVOL Values
      g_calculator.Calculate(g_htf_count, 0, h_vol_long, h_res_rvol, InpHistoryBars);

      // Compute HTF Signal Line via Unified Engine with exact persistent volume buffer
      if(InpShowSignal && g_signal_calculator != NULL)
        {
         int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res_rvol, h_double_vol, h_res_sig, htf_actual_start);
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
            BufferRVOL[i]   = EMPTY_VALUE;
            BufferColors[i] = 0.0;
            BufferSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double rvol = h_res_rvol[htf_ptr];
         BufferRVOL[i] = rvol;

         if(rvol == EMPTY_VALUE)
           {
            BufferColors[i] = 0.0;
           }
         else
           {
            if(rvol >= InpThresholdHigh)
               BufferColors[i] = 2.0;
            else
               if(rvol >= InpThresholdNormal)
                  BufferColors[i] = 1.0;
               else
                  BufferColors[i] = 0.0;
           }

         BufferSignal[i] = (InpShowSignal && h_res_sig[htf_ptr] != EMPTY_VALUE) ? h_res_sig[htf_ptr] : EMPTY_VALUE;
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

         h_vol_long[live_idx]   = (InpVolumeType == VOLUME_REAL) ? (long)htf_rate[0].real_volume : (long)htf_rate[0].tick_volume;
         h_double_vol[live_idx] = (double)h_vol_long[live_idx];

         // Mock incremental calculation strictly on forming HTF bar
         h_res_rvol[live_idx] = g_calculator.CalculateSingle(g_htf_count, h_vol_long, live_idx);

         if(InpShowSignal && g_signal_calculator != NULL)
           {
            int htf_actual_start = (InpHistoryBars > 0) ? MathMax(warmup, g_htf_count - InpHistoryBars) : warmup;
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res_rvol, h_double_vol, h_res_sig, htf_actual_start);
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
   double rvol_val = h_res_rvol[live_idx];
   double col_val  = 0.0;
   double sig_val  = InpShowSignal ? h_res_sig[live_idx] : EMPTY_VALUE;

   if(rvol_val != EMPTY_VALUE)
     {
      if(rvol_val >= InpThresholdHigh)
         col_val = 2.0;
      else
         if(rvol_val >= InpThresholdNormal)
            col_val = 1.0;
         else
            col_val = 0.0;
     }

   for(int i = start; i < rates_total; i++)
     {
      BufferRVOL[i]   = rvol_val;
      BufferColors[i] = col_val;
      BufferSignal[i] = sig_val;
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
