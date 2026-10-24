//+------------------------------------------------------------------+
//|                                         ChaosWeightedRSI_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.30" // Enterprise Edition: True MTF-Space Divergences & Zero-Lag Chronological Projection
#property description "Chaos Weighted RSI with Fractal Dimension Modulation & Clean Divergence Trendlines."
#property description "Features authentic Higher Timeframe divergence detection projected seamlessly onto execution charts."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

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

#include <MyIncludes\ChaosWeightedRSI_Calculator.mqh>
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

input group "=== Divergence Settings ==="
input bool                      InpShowDivLines     = true;                // Draw Divergence Lines in Subwindow
input int                       InpDivStrength      = 15;                  // Divergence Pivot Strength (Confirm Bars)
input color                     InpBullDivColor     = clrMediumSeaGreen;   // Bullish Divergence Line Color
input color                     InpBearDivColor     = clrCrimson;          // Bearish Divergence Line Color

//--- Visual Indicator Buffer (Single Pure Line)
double BufferWRSI[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_wrsi[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CChaosWeightedRSI_Calculator *g_calc   = NULL;
string                        g_prefix = "";

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//--- Divergence Internal Tracking Registers
double g_last_rsi_lo  = WRONG_VALUE;
double g_last_prc_lo  = WRONG_VALUE;
int    g_last_bar_lo  = -1;

double g_last_rsi_hi  = WRONG_VALUE;
double g_last_prc_hi  = WRONG_VALUE;
int    g_last_bar_hi  = -1;

int    g_last_proc_pivot_bar = -1;

//+------------------------------------------------------------------+
//| Clean Chart Graphical Objects with Isolated Namespace            |
//+------------------------------------------------------------------+
void CleanUp()
  {
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_prefix = StringFormat("CWRSI_%I64d_", ChartID());
   CleanUp();

   g_data_ready          = false;
   g_data_synced         = false;
   g_htf_count           = 0;
   g_last_htf_time       = 0;

   g_last_rsi_lo         = WRONG_VALUE;
   g_last_prc_lo         = WRONG_VALUE;
   g_last_bar_lo         = -1;
   g_last_rsi_hi         = WRONG_VALUE;
   g_last_prc_hi         = WRONG_VALUE;
   g_last_bar_hi         = -1;
   g_last_proc_pivot_bar = -1;

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

// 2. Setup Single Clean Buffer
   SetIndexBuffer(0, BufferWRSI, INDICATOR_DATA);
   ArraySetAsSeries(BufferWRSI, false);
   ArrayInitialize(BufferWRSI, 50.0);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorRSI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthRSI);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 3. Initialize Core Calculator Engine
   g_calc = new CChaosWeightedRSI_Calculator();
   if(CheckPointer(g_calc) == POINTER_INVALID ||
      !g_calc.Init(InpRSILength, InpDisorderLength, InpSensitivity, InpPriceSource))
     {
      Print("Critical Error: Failed to initialize CChaosWeightedRSI_Calculator.");
      return INIT_FAILED;
     }

   string ha_str  = (InpPriceSource <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string name    = StringFormat("Chaos Weighted RSI%s%s(%d,%d)", ha_str, tf_str, InpRSILength, InpDisorderLength);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 4. Background Timer for MTF synchronization
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
//| Process Non-Repainting Divergences with Absolute Time Coordinates |
//+------------------------------------------------------------------+
void ProcessDivergences(const int total_bars, const int prev_calc,
                        const datetime &t_arr[], const double &h_arr[], const double &l_arr[],
                        const double &rsi_arr[])
  {
   if(!InpShowDivLines)
      return;

   int d = InpDivStrength;
   int subwin = ChartWindowFind();
   if(subwin < 0)
      return;

   int max_eval = total_bars - d - 1;
   int min_eval = MathMax(d * 2, (prev_calc > 0 ? prev_calc - d - 2 : d * 2));

   if(prev_calc == 0)
     {
      g_last_proc_pivot_bar = -1;
      g_last_bar_lo         = -1;
      g_last_bar_hi         = -1;
      g_last_rsi_lo         = WRONG_VALUE;
      g_last_rsi_hi         = WRONG_VALUE;
      g_last_prc_lo         = WRONG_VALUE;
      g_last_prc_hi         = WRONG_VALUE;
     }

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
            // Regular Bullish Divergence: Lower Price Low + Higher RSI Low
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
            // Regular Bearish Divergence: Higher Price High + Lower RSI High
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
   int required_bars = MathMax(InpRSILength, InpDisorderLength) + InpDivStrength * 2 + 5;
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
      // 1. Compute Chaos-Weighted RSI with Strict State Preservation
      g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, BufferWRSI, InpHistoryBars);

      // 2. Process Native Chart Divergences
      ProcessDivergences(rates_total, prev_calculated, time, high, low, BufferWRSI);

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

      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,     g_htf_count);
         ArrayResize(h_open,     g_htf_count);
         ArrayResize(h_high,     g_htf_count);
         ArrayResize(h_low,      g_htf_count);
         ArrayResize(h_close,    g_htf_count);
         ArrayResize(h_res_wrsi, g_htf_count);

         ArraySetAsSeries(h_time,     false);
         ArraySetAsSeries(h_open,     false);
         ArraySetAsSeries(h_high,     false);
         ArraySetAsSeries(h_low,      false);
         ArraySetAsSeries(h_close,    false);
         ArraySetAsSeries(h_res_wrsi, false);
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

      // Compute HTF Pure WRSI on HTF Series
      g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_wrsi, InpHistoryBars);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferWRSI[i] = 50.0;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferWRSI[i] = h_res_wrsi[htf_ptr];
        }

      // TRUE MTF DIVERGENCES: Evaluated strictly in the clean, unstepped HTF domain!
      // Uses true HTF Highs/Lows and anchors lines directly to HTF timestamps!
      ProcessDivergences(g_htf_count, 0, h_time, h_high, h_low, h_res_wrsi);

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

         g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_wrsi, InpHistoryBars);
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

   for(int i = start; i < rates_total; i++)
     {
      BufferWRSI[i] = wrsi_val;
     }

// Note: MTF Divergences require confirmed pivots (d bars in the past),
// hence they execute deterministically on HTF bar closure (Mode 2A). Zero CPU churn on live ticks!

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = MathMax(InpRSILength, InpDisorderLength) + InpDivStrength * 2 + 5;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
