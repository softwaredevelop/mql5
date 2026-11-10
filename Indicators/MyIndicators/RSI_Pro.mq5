//+------------------------------------------------------------------+
//|                                                    RSI_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "6.10" // Enterprise Edition: Pure Geometric Divergence Engine (Arrow-Free)
#property description "Professional RSI Suite with 14 MA Types, Bollinger Bands, Heikin Ashi, MTF, and Dual-Chart Divergences."

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
#include <MyIncludes\Divergence_Engine.mqh>
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

input group "=== Divergence Engine Settings ==="
input bool                      InpEnableDivergence = true;          // Enable Divergence Scanner
input ENUM_DIV_FILTER_MODE      InpDivMode          = DIV_FILTER_BOTH;// Divergence Mode (Regular, Hidden, Both)
input int                       InpPivotLeftBars    = 3;             // Pivot Left Confirmation Bars
input int                       InpPivotRightBars   = 2;             // Pivot Right Confirmation Bars
input int                       InpMinDistance      = 5;             // Min Pivot Distance (Bars)
input int                       InpMaxDistance      = 60;            // Max Pivot Distance (Bars)
input bool                      InpDrawSubwindowLines= true;         // Draw Divergence Lines on RSI Subwindow
input bool                      InpDrawMainChartLines= true;         // Draw Divergence Lines on Main Price Chart

input group "=== Divergence Visual Settings ==="
input color                     InpColorRegBull     = clrDeepSkyBlue;// Regular Bullish Divergence Color
input color                     InpColorRegBear     = clrCrimson;    // Regular Bearish Divergence Color
input color                     InpColorHidBull     = clrDodgerBlue; // Hidden Bullish Divergence Color
input color                     InpColorHidBear     = clrOrangeRed;  // Hidden Bearish Divergence Color
input int                       InpDivLineWidth     = 1;             // Divergence Line Width
input ENUM_LINE_STYLE           InpDivLineStyle     = STYLE_SOLID;   // Divergence Line Style

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Visual Settings (Core Lines) ==="
input color                     InpColorRSI         = clrDodgerBlue; // RSI Line Color
input ENUM_LINE_STYLE           InpStyleRSI         = STYLE_SOLID;   // RSI Line Style
input int                       InpWidthRSI         = 1;             // RSI Line Width
input color                     InpColorMA          = clrOrangeRed;  // Signal MA Color
input ENUM_LINE_STYLE           InpStyleMA          = STYLE_DOT;     // Signal MA Style
input int                       InpWidthMA          = 1;             // Signal MA Width
input color                     InpColorBandsUpper  = clrGray;        // Upper Band Color
input color                     InpColorBandsLower  = clrGray;        // Lower Band Color
input ENUM_LINE_STYLE           InpStyleBands       = STYLE_DOT;     // Bands Line Style
input int                       InpWidthBands       = 1;             // Bands Line Width

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
CDivergenceEngine  g_divergence_engine;
string             g_indicator_shortname = "";
string             g_prefix          = "";
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

// 3. Configure Plot Visual Attributes
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorRSI);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleRSI);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthRSI);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMA);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMA);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBandsUpper);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleBands);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthBands);

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
      else
        {
         PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
        }

// 5. Initialize Calculators & Divergence Engine
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

   if(InpEnableDivergence)
     {
      g_divergence_engine.Init(InpPivotLeftBars, InpPivotRightBars, InpMinDistance, InpMaxDistance, InpDivMode);
     }

// 6. Formatting Names and Namespaces
   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   g_indicator_shortname = StringFormat("RSI Pro%s%s(%d)", ha_tag, tf_str, InpPeriodRSI);

   IndicatorSetString(INDICATOR_SHORTNAME, g_indicator_shortname);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("RSI(%d)", InpPeriodRSI));
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Signal MA(%d)", InpPeriodMA));
   PlotIndexSetString(2, PLOT_LABEL, "Upper Band");
   PlotIndexSetString(3, PLOT_LABEL, "Lower Band");

   g_prefix = StringFormat("RSI_Div_%I64d_", ChartID());

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

// Clean up all program-owned divergence graphical objects
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);

   if(CheckPointer(g_calculator) != POINTER_INVALID && g_calculator != NULL)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Helper: Draw Divergence Trendline on Subwindow or Main Chart     |
//+------------------------------------------------------------------+
void DrawDivergenceLine(const string name, const int window,
                        const datetime t1, const double val1,
                        const datetime t2, const double val2,
                        const color c, const ENUM_LINE_STYLE style, const int width)
  {
   string obj_name = g_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_TREND, window, t1, val1, t2, val2);
      ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
     }
   else
     {
      ObjectMove(0, obj_name, 0, t1, val1);
      ObjectMove(0, obj_name, 1, t2, val2);
     }

   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, obj_name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, width);
  }

//+------------------------------------------------------------------+
//| Helper: Locate Indicator Subwindow Resiliently                   |
//+------------------------------------------------------------------+
int GetSubwindow(void)
  {
   int subwin = ChartWindowFind(0, g_indicator_shortname);
   if(subwin < 0)
      subwin = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL) > 1 ? 1 : 0;
   return subwin;
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
   int required_bars = InpPeriodRSI + InpPeriodMA + InpMaxDistance + 10;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

// EXACT MATHEMATICAL APPLIED PRICE MAPPING
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

      // Divergence Scanning and Pure Geometric Projection
      if(InpEnableDivergence)
        {
         int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
         if(prev_calculated == 0)
           {
            g_divergence_engine.Reset();
            ObjectsDeleteAll(0, g_prefix);
            start = 0;
           }

         int subwin = -1;
         if(InpDrawSubwindowLines)
            subwin = GetSubwindow();

         for(int i = start; i < rates_total; i++)
           {
            SDivergenceEvent div_event;
            if(g_divergence_engine.ProcessBar(i, rates_total, time, high, low, BufferRSI, div_event))
              {
               color line_color = clrGray;
               string type_str  = "";

               switch(div_event.type)
                 {
                  case DIV_REGULAR_BULLISH:
                     line_color = InpColorRegBull;
                     type_str   = "RegBull";
                     break;

                  case DIV_REGULAR_BEARISH:
                     line_color = InpColorRegBear;
                     type_str   = "RegBear";
                     break;

                  case DIV_HIDDEN_BULLISH:
                     line_color = InpColorHidBull;
                     type_str   = "HidBull";
                     break;

                  case DIV_HIDDEN_BEARISH:
                     line_color = InpColorHidBear;
                     type_str   = "HidBear";
                     break;

                  default:
                     break;
                 }

               string tag = StringFormat("%s_%I64d", type_str, (long)div_event.curr_pivot.time);

               // 1. Draw line on RSI Subwindow
               if(InpDrawSubwindowLines && subwin >= 0)
                 {
                  DrawDivergenceLine("Osc_" + tag, subwin,
                                     div_event.prev_pivot.time, div_event.prev_pivot.osc_value,
                                     div_event.curr_pivot.time, div_event.curr_pivot.osc_value,
                                     line_color, InpDivLineStyle, InpDivLineWidth);
                 }

               // 2. Draw line on Price Main Chart
               if(InpDrawMainChartLines)
                 {
                  DrawDivergenceLine("Price_" + tag, 0,
                                     div_event.prev_pivot.time, div_event.prev_pivot.price,
                                     div_event.curr_pivot.time, div_event.curr_pivot.price,
                                     line_color, InpDivLineStyle, InpDivLineWidth);
                 }
              }
           }
        }

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

      // TWO-POINTER CHRONOLOGICAL SWEEP
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
