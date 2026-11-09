//+------------------------------------------------------------------+
//|                                                    RSI_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "5.10" // Enterprise Edition: Fully Configurable Visual Styling Panel
#property description "Professional RSI Suite with 14 MA Types, Bollinger Bands, Heikin Ashi, and Native MTF."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_minimum 0.0
#property indicator_maximum 100.0
#property indicator_level1  30.0
#property indicator_level2  50.0
#property indicator_level3  70.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Included Engines & Core Tools ---
#include <MyIncludes\RSI_Pro_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Plot Declarations ---
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE

#property indicator_label2  "Signal MA"
#property indicator_type2   DRAW_LINE

#property indicator_label3  "Upper Band"
#property indicator_type3   DRAW_LINE

#property indicator_label4  "Lower Band"
#property indicator_type4   DRAW_LINE

//--- Enum for Display Mode
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_RSI_ONLY,        // RSI Only
   DISPLAY_RSI_AND_MA,      // RSI + Moving Average Signal
   DISPLAY_RSI_AND_BANDS    // RSI + MA Signal + Bollinger Bands
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== RSI Core Settings ==="
input int                       InpPeriodRSI    = 14;                // RSI Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "=== Overlay & Volatility Settings ==="
input ENUM_DISPLAY_MODE         InpDisplayMode  = DISPLAY_RSI_AND_BANDS; // Display Layers
input int                       InpPeriodMA     = 20;                // Signal MA Period
input ENUM_MA_TYPE              InpMethodMA     = SMA;               // Signal MA Algorithm (14 Pluggable Models)
input double                    InpBandsDev     = 2.0;               // Bollinger Dispersion Multiplier

input group "=== RSI Visual Settings ==="
input color                     InpColorRSI     = clrDodgerBlue;     // RSI Line Color
input ENUM_LINE_STYLE           InpStyleRSI     = STYLE_SOLID;       // RSI Line Style
input int                       InpWidthRSI     = 1;                 // RSI Line Width

input group "=== Signal MA Visual Settings ==="
input color                     InpColorMA      = clrOrangeRed;      // Signal MA Color
input ENUM_LINE_STYLE           InpStyleMA      = STYLE_DOT;         // Signal MA Style
input int                       InpWidthMA      = 1;                 // Signal MA Width

input group "=== Bollinger Bands Visual Settings ==="
input color                     InpColorBandsUpper = clrGray;        // Upper Band Color
input color                     InpColorBandsLower = clrGray;        // Lower Band Color
input ENUM_LINE_STYLE           InpStyleBands   = STYLE_DOT;         // Bands Line Style
input int                       InpWidthBands   = 1;                 // Bands Line Width

//--- Indicator Output Buffers ---
double BufferRSI[];
double BufferSignalMA[];
double BufferUpperBand[];
double BufferLowerBand[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_rsi[], h_ma[], h_upper[], h_lower[];
datetime h_time[];

//--- Global Objects & State Management ---
CRSIProCalculator *g_calculator     = NULL;
bool               g_is_mtf_mode    = false;
ENUM_TIMEFRAMES    g_calc_timeframe;
bool               g_data_ready     = false;
bool               g_data_synced    = false;
int                g_htf_count      = 0;
datetime           g_last_htf_time  = 0;

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
   SetIndexBuffer(0, BufferRSI,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalMA,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferUpperBand, INDICATOR_DATA);
   SetIndexBuffer(3, BufferLowerBand, INDICATOR_DATA);

   ArraySetAsSeries(BufferRSI,       false);
   ArraySetAsSeries(BufferSignalMA,  false);
   ArraySetAsSeries(BufferUpperBand, false);
   ArraySetAsSeries(BufferLowerBand, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Configure Visual Properties Dynamically from Inputs
// Plot 0: RSI Line
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorRSI);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleRSI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthRSI);

// Plot 1: Signal MA
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMA);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMA);

// Plot 2: Upper Band
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBandsUpper);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleBands);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthBands);

// Plot 3: Lower Band
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBandsLower);
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpStyleBands);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpWidthBands);

// 4. Draw Type Visibility Switching based on Display Mode
   if(InpDisplayMode == DISPLAY_RSI_ONLY)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
      if(InpDisplayMode == DISPLAY_RSI_AND_MA)
        {
         PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
         PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
        }
      else // DISPLAY_RSI_AND_BANDS
        {
         PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
        }

// 5. Draw Begin Alignment
   int draw_begin = InpPeriodRSI + InpPeriodMA - 1;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_is_mtf_mode ? 0 : InpPeriodRSI);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);

// 6. Initialize Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CRSIProCalculator_HA();
   else
      g_calculator = new CRSIProCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, InpBandsDev))
     {
      Print("Critical Error: Failed to initialize RSI Pro Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("RSI Pro%s%s(%d, %s %d)", ha_tag, tf_str, InpPeriodRSI, EnumToString(InpMethodMA), InpPeriodMA);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("RSI(%d)", InpPeriodRSI));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Signal MA(%d)", InpPeriodMA));
   PlotIndexSetString(2, PLOT_LABEL, "Upper Band");
   PlotIndexSetString(3, PLOT_LABEL, "Lower Band");

// 7. Background MTF Sync Daemon
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
   int required_bars = InpPeriodRSI + InpPeriodMA + 5;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
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
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                             BufferRSI, BufferSignalMA, BufferUpperBand, BufferLowerBand);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = InpPeriodRSI + InpPeriodMA + 10;
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

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,  g_htf_count);
         ArrayResize(h_open,  g_htf_count);
         ArrayResize(h_high,  g_htf_count);
         ArrayResize(h_low,   g_htf_count);
         ArrayResize(h_close, g_htf_count);
         ArrayResize(h_rsi,   g_htf_count);
         ArrayResize(h_ma,    g_htf_count);
         ArrayResize(h_upper, g_htf_count);
         ArrayResize(h_lower, g_htf_count);

         ArraySetAsSeries(h_time,  false);
         ArraySetAsSeries(h_open,  false);
         ArraySetAsSeries(h_high,  false);
         ArraySetAsSeries(h_low,   false);
         ArraySetAsSeries(h_close, false);
         ArraySetAsSeries(h_rsi,   false);
         ArraySetAsSeries(h_ma,    false);
         ArraySetAsSeries(h_upper, false);
         ArraySetAsSeries(h_lower, false);
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

      // Compute HTF RSI + Overlays on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close,
                             h_rsi, h_ma, h_upper, h_lower);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferRSI[i]       = EMPTY_VALUE;
            BufferSignalMA[i]  = EMPTY_VALUE;
            BufferUpperBand[i] = EMPTY_VALUE;
            BufferLowerBand[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferRSI[i]       = h_rsi[htf_ptr];
         BufferSignalMA[i]  = h_ma[htf_ptr];
         BufferUpperBand[i] = h_upper[htf_ptr];
         BufferLowerBand[i] = h_lower[htf_ptr];
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
                                h_rsi, h_ma, h_upper, h_lower);
        }
     }

// Binary Search for forming bar block
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

   double val_rsi   = h_rsi[live_idx];
   double val_ma    = h_ma[live_idx];
   double val_upper = h_upper[live_idx];
   double val_lower = h_lower[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferRSI[i]       = val_rsi;
      BufferSignalMA[i]  = val_ma;
      BufferUpperBand[i] = val_upper;
      BufferLowerBand[i] = val_lower;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpPeriodRSI + InpPeriodMA + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
