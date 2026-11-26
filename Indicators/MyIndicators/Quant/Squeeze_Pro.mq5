//+------------------------------------------------------------------+
//|                                                  Squeeze_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "4.00" // Enterprise Edition: Independent ATR Period, Two-Pointer MTF Fast-Path & Fixed HA Pipeline
#property description "Professional Volatility Squeeze Indicator (John Carter's TTM Squeeze Model) with MTF Fast-Path."
#property description "Features independent ATR Period, Hybrid ATR Source, 4-Color LinReg Momentum, and Synthetic Heikin Ashi."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: TTM Linear Regression Momentum Histogram
#property indicator_label1  "Momentum"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLightSkyBlue, clrDeepSkyBlue, clrOrangeRed, clrCoral
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Squeeze State Dots (On Zero Baseline)
#property indicator_label2  "Squeeze State"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrLime, clrRed // 0 = Lime (Fired / No Squeeze), 1 = Red (Squeeze Active)
#property indicator_width2  2

//--- Included Engines & Core Tools ---
#include <MyIncludes\Squeeze_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "=== Squeeze Core Settings ==="
input int                       InpPeriod         = 20;                  // Bollinger & KC Basis Period
input double                    InpBBMult         = 2.0;                 // Bollinger Bands Multiplier (Sigma)
input int                       InpAtrPeriod      = 20;                  // Keltner Channel ATR Period
input double                    InpKCMult         = 1.5;                 // Keltner Channel Multiplier (ATR)
input ENUM_ATR_SOURCE           InpAtrSource      = ATR_SOURCE_STANDARD; // Keltner ATR Source (Standard / Hybrid HA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;     // Global Price Source (Standard / HA)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Momentum Settings (Linear Regression) ==="
input int                       InpMomPeriod      = 20;                  // Linear Regression Momentum Period

input group "=== Visual Settings - Momentum Histogram ==="
input color                     InpColorBullExp   = clrLightSkyBlue;     // Bullish Expanding Color
input color                     InpColorBullDec   = clrDeepSkyBlue;      // Bullish Decelerating Color
input color                     InpColorBearExp   = clrOrangeRed;        // Bearish Expanding Color
input color                     InpColorBearDec   = clrCoral;            // Bearish Decelerating Color
input int                       InpHistWidth      = 2;                   // Histogram Bar Width

input group "=== Visual Settings - Squeeze Dots ==="
input color                     InpColorSqzOff    = clrLime;             // Squeeze Fired / OFF Color (Action)
input color                     InpColorSqzOn     = clrRed;              // Squeeze Active / ON Color (Compression)
input int                       InpDotSize        = 2;                   // Zero Dot Size

//--- Indicator Output Buffers ---
double BufferMom[];
double BufferMomColor[];
double BufferSqueeze[];
double BufferSqueezeColors[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_mom[], h_res_mom_col[];
double   h_res_sqz_val[], h_res_sqz_col[];
datetime h_time[];

//--- Global Objects & State Management ---
CSqueezeCalculator *g_calculator     = NULL;
bool               g_is_mtf_mode     = false;
ENUM_TIMEFRAMES    g_calc_timeframe;
bool               g_data_ready      = false;
bool               g_data_synced     = false;
int                g_htf_count       = 0;
datetime           g_last_htf_time   = 0;

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
   SetIndexBuffer(0, BufferMom,           INDICATOR_DATA);
   SetIndexBuffer(1, BufferMomColor,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSqueeze,       INDICATOR_DATA);
   SetIndexBuffer(3, BufferSqueezeColors, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferMom,           false);
   ArraySetAsSeries(BufferMomColor,      false);
   ArraySetAsSeries(BufferSqueeze,       false);
   ArraySetAsSeries(BufferSqueezeColors, false);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorBullExp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorBullDec);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorBearExp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, InpColorBearDec);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpHistWidth);

   PlotIndexSetInteger(1, PLOT_ARROW, 159); // Solid circle/dot character
   PlotIndexSetInteger(1, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, InpColorSqzOff);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, InpColorSqzOn);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpDotSize);

   int warmup = MathMax(MathMax(InpPeriod, InpAtrPeriod), InpPeriod + InpMomPeriod);
   int draw_begin = warmup;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

// 4. Initialize Core Squeeze Engine (7-Param Init with Independent ATR Period & Source)
   g_calculator = new CSqueezeCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpBBMult, InpAtrPeriod, InpKCMult, InpAtrSource, InpMomPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Squeeze Calculator Engine.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string atr_tag = (InpAtrSource == ATR_SOURCE_HEIKIN_ASHI) ? "/HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";

   string short_name = StringFormat("Squeeze Pro%s%s(%d, BB:%.1f, ATR%s:%d x%.1f)",
                                    ha_tag, tf_str,
                                    InpPeriod, InpBBMult, atr_tag, InpAtrPeriod, InpKCMult);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Momentum");
   PlotIndexSetString(1, PLOT_LABEL, "Squeeze State");

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
   int warmup = MathMax(MathMax(InpPeriod, InpAtrPeriod), InpPeriod + InpMomPeriod) + 5;
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
                             BufferMom, BufferMomColor, BufferSqueeze, BufferSqueezeColors);
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
         ArrayResize(h_time,        g_htf_count, 2048);
         ArrayResize(h_open,        g_htf_count, 2048);
         ArrayResize(h_high,        g_htf_count, 2048);
         ArrayResize(h_low,         g_htf_count, 2048);
         ArrayResize(h_close,       g_htf_count, 2048);
         ArrayResize(h_res_mom,     g_htf_count, 2048);
         ArrayResize(h_res_mom_col, g_htf_count, 2048);
         ArrayResize(h_res_sqz_val, g_htf_count, 2048);
         ArrayResize(h_res_sqz_col, g_htf_count, 2048);

         ArraySetAsSeries(h_time,        false);
         ArraySetAsSeries(h_open,        false);
         ArraySetAsSeries(h_high,        false);
         ArraySetAsSeries(h_low,         false);
         ArraySetAsSeries(h_close,       false);
         ArraySetAsSeries(h_res_mom,     false);
         ArraySetAsSeries(h_res_mom_col, false);
         ArraySetAsSeries(h_res_sqz_val, false);
         ArraySetAsSeries(h_res_sqz_col, false);
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

      // Compute HTF Squeeze Values on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close,
                             h_res_mom, h_res_mom_col, h_res_sqz_val, h_res_sqz_col);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferMom[i]           = 0.0;
            BufferMomColor[i]      = 0.0;
            BufferSqueeze[i]       = 0.0;
            BufferSqueezeColors[i] = 0.0;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferMom[i]           = h_res_mom[htf_ptr];
         BufferMomColor[i]      = h_res_mom_col[htf_ptr];
         BufferSqueeze[i]       = 0.0;
         BufferSqueezeColors[i] = h_res_sqz_col[htf_ptr];
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
                                h_res_mom, h_res_mom_col, h_res_sqz_val, h_res_sqz_col);
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

   double val_mom     = h_res_mom[live_idx];
   double val_mom_col = h_res_mom_col[live_idx];
   double val_sqz_col = h_res_sqz_col[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferMom[i]           = val_mom;
      BufferMomColor[i]      = val_mom_col;
      BufferSqueeze[i]       = 0.0;
      BufferSqueezeColors[i] = val_sqz_col;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(MathMax(InpPeriod, InpAtrPeriod), InpPeriod + InpMomPeriod) + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
