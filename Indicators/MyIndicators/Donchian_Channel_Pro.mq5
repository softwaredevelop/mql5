//+------------------------------------------------------------------+
//|                                         Donchian_Channel_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Clean Extreme Price Architecture (Standard vs Heikin Ashi)
#property description "Institutional Donchian Channel with Asymmetric Bands, MTF Fast-Path, and Heikin Ashi."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot Declarations ---
#property indicator_label1  "Upper Channel"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Middle Channel"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "Lower Channel"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Included Engines & Core Tools ---
#include <MyIncludes\Donchian_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;            // Calculation Timeframe (Current or HTF)

input group "=== Donchian Core Settings ==="
input int                       InpUpperPeriod    = 20;                        // Upper Band Period (Breakout Lookback)
input int                       InpLowerPeriod    = 20;                        // Lower Band Period (Asymmetric Lookback)
input int                       InpBarOffset      = 1;                         // Lookback Offset (1 = Breakout, 0 = Real-Time)
input ENUM_DONCHIAN_PRICE_TYPE  InpPriceType      = PRICE_DONCHIAN_STANDARD;   // Price Source (Standard vs Heikin Ashi)

input group "=== Visual Settings - Upper Band ==="
input color                     InpColorUpper     = clrDodgerBlue;             // Upper Line Color
input ENUM_LINE_STYLE           InpStyleUpper     = STYLE_SOLID;               // Upper Line Style
input int                       InpWidthUpper     = 2;                         // Upper Line Width

input group "=== Visual Settings - Middle Band ==="
input color                     InpColorMiddle    = clrDarkGray;               // Middle Line Color
input ENUM_LINE_STYLE           InpStyleMiddle    = STYLE_DOT;                 // Middle Line Style
input int                       InpWidthMiddle    = 1;                         // Middle Line Width

input group "=== Visual Settings - Lower Band ==="
input color                     InpColorLower     = clrDodgerBlue;             // Lower Line Color
input ENUM_LINE_STYLE           InpStyleLower     = STYLE_SOLID;               // Lower Line Style
input int                       InpWidthLower     = 2;                         // Lower Line Width

//--- Indicator Output Buffers ---
double BufferUpper[];
double BufferMiddle[];
double BufferLower[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_upper[], h_res_middle[], h_res_lower[];
datetime h_time[];

//--- Global Objects & State Management ---
CDonchianCalculator *g_calculator     = NULL;
bool                g_is_mtf_mode     = false;
ENUM_TIMEFRAMES     g_calc_timeframe;
bool                g_data_ready      = false;
bool                g_data_synced     = false;
int                 g_htf_count       = 0;
datetime            g_last_htf_time   = 0;

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
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferMiddle, INDICATOR_DATA);
   SetIndexBuffer(2, BufferLower,  INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferMiddle, false);
   ArraySetAsSeries(BufferLower,  false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorUpper);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleUpper);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthUpper);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMiddle);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMiddle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMiddle);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorLower);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleLower);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthLower);

   int draw_begin = MathMax(InpUpperPeriod, InpLowerPeriod) + InpBarOffset;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   g_calculator = new CDonchianCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpUpperPeriod, InpLowerPeriod, InpBarOffset, InpPriceType))
     {
      Print("Critical Error: Failed to initialize Donchian Calculator Engine.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpPriceType == PRICE_DONCHIAN_HEIKIN_ASHI) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Donchian Pro%s%s(%d,%d,Offset %d)",
                                    ha_tag, tf_str, InpUpperPeriod, InpLowerPeriod, InpBarOffset);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("Upper(%d)", InpUpperPeriod));
   PlotIndexSetString(1, PLOT_LABEL, "Median");
   PlotIndexSetString(2, PLOT_LABEL, StringFormat("Lower(%d)", InpLowerPeriod));

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
   int warmup = MathMax(InpUpperPeriod, InpLowerPeriod) + InpBarOffset + 5;
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
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close,
                             BufferUpper, BufferMiddle, BufferLower);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = MathMax(InpUpperPeriod, InpLowerPeriod) + InpBarOffset + 10;
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
         ArrayResize(h_time,       g_htf_count, 2048);
         ArrayResize(h_open,       g_htf_count, 2048);
         ArrayResize(h_high,       g_htf_count, 2048);
         ArrayResize(h_low,        g_htf_count, 2048);
         ArrayResize(h_close,      g_htf_count, 2048);
         ArrayResize(h_res_upper,  g_htf_count, 2048);
         ArrayResize(h_res_middle, g_htf_count, 2048);
         ArrayResize(h_res_lower,  g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_res_upper,  false);
         ArraySetAsSeries(h_res_middle, false);
         ArraySetAsSeries(h_res_lower,  false);
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

      // Compute HTF Donchian on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close,
                             h_res_upper, h_res_middle, h_res_lower);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferUpper[i]  = EMPTY_VALUE;
            BufferMiddle[i] = EMPTY_VALUE;
            BufferLower[i]  = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferUpper[i]  = h_res_upper[htf_ptr];
         BufferMiddle[i] = h_res_middle[htf_ptr];
         BufferLower[i]  = h_res_lower[htf_ptr];
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
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close,
                                h_res_upper, h_res_middle, h_res_lower);
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

   double val_upper  = h_res_upper[live_idx];
   double val_middle = h_res_middle[live_idx];
   double val_lower  = h_res_lower[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferUpper[i]  = val_upper;
      BufferMiddle[i] = val_middle;
      BufferLower[i]  = val_lower;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpUpperPeriod, InpLowerPeriod) + InpBarOffset + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
