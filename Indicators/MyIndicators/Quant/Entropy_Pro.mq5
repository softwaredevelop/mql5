//+------------------------------------------------------------------+
//|                                                  Entropy_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.30" // Fixed: 0.0 Baseline Anchor, 3-Color Slot Allocation & Dual Visual Mode
#property description "Institutional Sample Entropy (SampEn) with Multi-Timeframe Support."
#property description "Measures market structural order. Low = Clean Trend / Squeeze, High = Chaotic Noise."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Horizontal Visual Levels Declarations
#property indicator_level1 0.8
#property indicator_level2 1.3
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot 1: Entropy Main Plot (Pre-allocating 3 color slots is MANDATORY in MT5!)
#property indicator_label1  "SampEn"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDeepSkyBlue, clrGold, clrCrimson
#property indicator_style1  STYLE_SOLID

// Plot 2: Entropy Signal Line
#property indicator_label2  "Signal EMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSlateGray
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Entropy_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Visual Style Selector
enum ENUM_ENTROPY_VISUAL
  {
   VISUAL_HISTOGRAM, // Dynamic Color Histogram (Anchored strictly at 0.0)
   VISUAL_LINE       // Dynamic Color Line (Clean Continuous Curve)
  };

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "--- Entropy Settings ---"
input int                       InpPeriod         = 50;                  // Analysis Window (N, recommended 40-80)
input int                       InpDim            = 2;                   // Pattern Length (m)
input double                    InpTol            = 0.30;                // Tolerance Multiplier (r * StdDev)
input ENUM_ENTROPY_MODE         InpEntropyMode    = ENTROPY_DETRENDED;   // Calculation Mode (Detrended preserves trends!)
input ENUM_APPLIED_PRICE        InpPrice          = PRICE_CLOSE;         // Applied Price
input int                       InpHistoryBars    = 1000;                // History Bars Limit (0 = Full Chart)

input group "--- Regime Thresholds ---"
input double                    InpLevelOrder     = 0.8;                 // Order Threshold (Below = Trend / Squeeze)
input double                    InpLevelChaos     = 1.3;                 // Chaos Threshold (Above = Noise / Chop)

input group "--- Visual Appearance ---"
input ENUM_ENTROPY_VISUAL       InpVisualType     = VISUAL_HISTOGRAM;    // Display Mode (Histogram vs Line)
input color                     InpColorOrder     = clrDeepSkyBlue;      // Low Entropy / Order (Trend / Squeeze)
input color                     InpColorNeutral   = clrGold;             // Normal Entropy (Transition Equilibrium)
input color                     InpColorChaos     = clrCrimson;          // High Entropy / Chaos (Noise / Chop)
input int                       InpWidthPlot      = 2;                   // Main Plot Width

input group "--- Signal Line Settings ---"
input bool                      InpShowSignal     = true;                // Display Signal Line on Chart
input int                       InpSignalPeriod   = 9;                   // Signal Smoothing EMA Period
input color                     InpColorSignal    = clrSlateGray;        // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;         // Signal Line Style
input int                       InpWidthSignal    = 1;                   // Signal Line Width

//--- Visual Indicator Buffers
double BufEn[];
double BufCol[];
double BufSignal[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_en[];
datetime h_time[];

//--- Global Objects & State Management
CEntropyCalculator *g_calc = NULL;

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
   SetIndexBuffer(0, BufEn,     INDICATOR_DATA);
   SetIndexBuffer(1, BufCol,    INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufEn,     false);
   ArraySetAsSeries(BufCol,    false);
   ArraySetAsSeries(BufSignal, false);

   ArrayInitialize(BufEn,     EMPTY_VALUE);
   ArrayInitialize(BufCol,    0.0);
   ArrayInitialize(BufSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

// 3. Anchor Subwindow Base strictly at 0.0 (Prevents floating histogram!)
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);

// 4. Configure Dynamic Plot Type (Histogram vs Line)
   if(InpVisualType == VISUAL_HISTOGRAM)
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   else
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPlot);

// Pre-allocate and assign the 3 color table slots
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorOrder);   // Color Index 0: Order
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorNeutral); // Color Index 1: Transition
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorChaos);   // Color Index 2: Chaos

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

// Configure Dynamic Horizontal Threshold Levels
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelOrder);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelChaos);

// 5. Initialize Calculation Engine
   g_calc = new CEntropyCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpDim, InpTol, InpEntropyMode))
     {
      Print("Critical Error: Failed to initialize CEntropyCalculator.");
      return INIT_FAILED;
     }

   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string mode_str = (InpEntropyMode == ENTROPY_DETRENDED) ? "Detrended" : ((InpEntropyMode == ENTROPY_LOG_RETURNS) ? "Returns" : "Raw");
   string name = StringFormat("SampEn%s(%d,m=%d,r=%.2f|%s)", tf_str, InpPeriod, InpDim, InpTol, mode_str);
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

   if(CheckPointer(g_calc) != POINTER_INVALID)
     {
      delete g_calc;
      g_calc = NULL;
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
   int required_bars = InpPeriod + InpDim + 5;
   if(rates_total < required_bars || !g_calc)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   double alpha = 2.0 / (double)(InpSignalPeriod + 1);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calc.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, BufEn, InpHistoryBars);

      int start = (prev_calculated > 0) ? (prev_calculated - 1) : required_bars;
      if(InpHistoryBars > 0 && prev_calculated == 0)
        {
         int limit_start = rates_total - InpHistoryBars;
         if(limit_start > start)
            start = limit_start;
        }

      // Dynamic Color Indexing & Signal Smoothing
      for(int i = start; i < rates_total; i++)
        {
         double en = BufEn[i];
         if(en == EMPTY_VALUE)
           {
            BufCol[i] = 1.0;
            BufSignal[i] = EMPTY_VALUE;
            continue;
           }

         // Dynamic Color Assignment across 3 active slots
         if(en < InpLevelOrder)
            BufCol[i] = 0.0; // Index 0: InpColorOrder (DeepSkyBlue)
         else
            if(en <= InpLevelChaos)
               BufCol[i] = 1.0; // Index 1: InpColorNeutral (Gold)
            else
               BufCol[i] = 2.0; // Index 2: InpColorChaos (Crimson Red)

         // Signal EMA Calculation
         if(i == start || BufSignal[i - 1] == EMPTY_VALUE)
            BufSignal[i] = en;
         else
            BufSignal[i] = BufSignal[i - 1] + alpha * (en - BufSignal[i - 1]);
        }

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

      g_htf_count = MathMin(htf_bars, 2000);

      // Reallocate persistent cache registers ONLY when capacity changes
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,     g_htf_count);
         ArrayResize(h_open,     g_htf_count);
         ArrayResize(h_high,     g_htf_count);
         ArrayResize(h_low,      g_htf_count);
         ArrayResize(h_close,    g_htf_count);
         ArrayResize(h_res_en,   g_htf_count);

         ArraySetAsSeries(h_time,     false);
         ArraySetAsSeries(h_open,     false);
         ArraySetAsSeries(h_high,     false);
         ArraySetAsSeries(h_low,      false);
         ArraySetAsSeries(h_close,    false);
         ArraySetAsSeries(h_res_en,   false);
        }

      // Atomic bulk rates copy
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

      // Compute HTF Entropy Values
      g_calc.Calculate(g_htf_count, 0, InpPrice, h_open, h_high, h_low, h_close, h_res_en, InpHistoryBars);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufEn[i]     = EMPTY_VALUE;
            BufCol[i]    = 1.0;
            BufSignal[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double en = h_res_en[htf_ptr];
         BufEn[i] = en;

         if(en == EMPTY_VALUE)
           {
            BufCol[i] = 1.0;
            BufSignal[i] = EMPTY_VALUE;
           }
         else
           {
            if(en < InpLevelOrder)
               BufCol[i] = 0.0;
            else
               if(en <= InpLevelChaos)
                  BufCol[i] = 1.0;
               else
                  BufCol[i] = 2.0;

            if(i == 0 || BufSignal[i - 1] == EMPTY_VALUE)
               BufSignal[i] = en;
            else
               BufSignal[i] = BufSignal[i - 1] + alpha * (en - BufSignal[i - 1]);
           }
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update forming candle in RAM!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         // Mock incremental calculation strictly on forming HTF bar
         g_calc.Calculate(g_htf_count, g_htf_count, InpPrice, h_open, h_high, h_low, h_close, h_res_en, InpHistoryBars);
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
   double en_val  = h_res_en[live_idx];
   double col_val = 1.0;
   if(en_val != EMPTY_VALUE)
     {
      if(en_val < InpLevelOrder)
         col_val = 0.0;
      else
         if(en_val <= InpLevelChaos)
            col_val = 1.0;
         else
            col_val = 2.0;
     }

   for(int i = start; i < rates_total; i++)
     {
      BufEn[i]  = en_val;
      BufCol[i] = col_val;

      if(i > 0 && BufSignal[i - 1] != EMPTY_VALUE && en_val != EMPTY_VALUE)
         BufSignal[i] = BufSignal[i - 1] + alpha * (en_val - BufSignal[i - 1]);
      else
         BufSignal[i] = en_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpPeriod + InpDim + 5;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
