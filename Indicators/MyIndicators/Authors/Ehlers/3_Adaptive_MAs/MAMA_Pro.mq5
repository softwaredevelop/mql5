//+------------------------------------------------------------------+
//|                                                      MAMA_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.00" // Enterprise Edition: Two-Pointer MTF Fast-Path, Fixed HA Price Offsets & Full Styling Panel
#property description "John Ehlers' MESA Adaptive Moving Average (MAMA) and FAMA with Native MTF Fast-Path."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MAMA Line
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: FAMA Line
#property indicator_label2  "FAMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\MAMA_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== MAMA Core Settings ==="
input double                    InpFastLimit    = 0.5;               // Fast Limit for Alpha
input double                    InpSlowLimit    = 0.05;              // Slow Limit for Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "=== Visual Settings - MAMA Line ==="
input bool                      InpShowMAMA     = true;              // Display MAMA Line
input color                     InpColorMAMA    = clrRed;            // MAMA Line Color
input ENUM_LINE_STYLE           InpStyleMAMA    = STYLE_SOLID;       // MAMA Line Style
input int                       InpWidthMAMA    = 2;                 // MAMA Line Width

input group "=== Visual Settings - FAMA Line ==="
input bool                      InpShowFAMA     = true;              // Display FAMA Line
input color                     InpColorFAMA    = clrDodgerBlue;     // FAMA Line Color
input ENUM_LINE_STYLE           InpStyleFAMA    = STYLE_SOLID;       // FAMA Line Style
input int                       InpWidthFAMA    = 1;                 // FAMA Line Width

//--- Indicator Output Buffers ---
double BufferMAMA[];
double BufferFAMA[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_mama[], h_res_fama[];
datetime h_time[];

//--- Global Objects & State Management ---
CMAMACalculator *g_calculator     = NULL;
bool             g_is_mtf_mode    = false;
ENUM_TIMEFRAMES  g_calc_timeframe;
bool             g_data_ready     = false;
bool             g_data_synced    = false;
int              g_htf_count      = 0;
datetime         g_last_htf_time  = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Direction Guard
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
   SetIndexBuffer(0, BufferMAMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA, INDICATOR_DATA);

   ArraySetAsSeries(BufferMAMA, false);
   ArraySetAsSeries(BufferFAMA, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling & Visibility Switching
   if(InpShowMAMA)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorMAMA);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleMAMA);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthMAMA);
     }
   else
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   if(InpShowFAMA)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorFAMA);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleFAMA);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthFAMA);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   int draw_begin = 50;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMAMACalculator_HA();
   else
      g_calculator = new CMAMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Critical Error: Failed to initialize MAMA Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("MAMA Pro%s%s(%.2f,%.2f)", ha_tag, tf_str, InpFastLimit, InpSlowLimit);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "MAMA");
   PlotIndexSetString(1, PLOT_LABEL, "FAMA");

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
   if(rates_total < 50 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

// EXACT MATHEMATICAL APPLIED PRICE MAPPING (Eliminates Off-by-One Mismatch)
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)InpSourcePrice) - 1) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMAMA, BufferFAMA);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = 60;
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
         ArrayResize(h_time,     g_htf_count, 2048);
         ArrayResize(h_open,     g_htf_count, 2048);
         ArrayResize(h_high,     g_htf_count, 2048);
         ArrayResize(h_low,      g_htf_count, 2048);
         ArrayResize(h_close,    g_htf_count, 2048);
         ArrayResize(h_res_mama, g_htf_count, 2048);
         ArrayResize(h_res_fama, g_htf_count, 2048);

         ArraySetAsSeries(h_time,     false);
         ArraySetAsSeries(h_open,     false);
         ArraySetAsSeries(h_high,     false);
         ArraySetAsSeries(h_low,      false);
         ArraySetAsSeries(h_close,    false);
         ArraySetAsSeries(h_res_mama, false);
         ArraySetAsSeries(h_res_fama, false);
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

      // Compute HTF MAMA & FAMA on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close,
                             h_res_mama, h_res_fama);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferMAMA[i] = EMPTY_VALUE;
            BufferFAMA[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferMAMA[i] = h_res_mama[htf_ptr];
         BufferFAMA[i] = h_res_fama[htf_ptr];
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
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close,
                                h_res_mama, h_res_fama);
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

   double val_mama = h_res_mama[live_idx];
   double val_fama = h_res_fama[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferMAMA[i] = val_mama;
      BufferFAMA[i] = val_fama;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = 60 + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
