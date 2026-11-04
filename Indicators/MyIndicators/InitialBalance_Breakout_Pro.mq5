//+------------------------------------------------------------------+
//|                                  InitialBalance_Breakout_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.40" // Consolidated Unified Extension Architecture
#property description "Institutional Initial Balance (IB) Breakout & Statistical Open Forecast Suite."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Bullish Breakout Arrow
#property indicator_label1  "Bullish Breakout"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrForestGreen
#property indicator_width1  2

//--- Plot 2: Bearish Breakout Arrow
#property indicator_label2  "Bearish Breakout"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

//--- Core Mathematical Engine
#include <MyIncludes\InitialBalance_Engine.mqh>

//--- Input Parameters ---
input group "=== Session & Multi-Instance Identity ==="
input string              InpSessionName       = "London";           // Session / Instance Tag (e.g. London, NY)
input bool                InpAutoSession       = false;              // Auto Session (First bar of day)
input int                 InpIBDurationMinutes = 60;                 // IB Duration in Minutes
input string              InpManualIBStart     = "09:00";            // Manual IB Start Time (HH:MM)
input string              InpManualIBEnd       = "10:00";            // Manual IB End Time (HH:MM)
input string              InpManualSessionEnd  = "17:30";            // Manual Breakout Window End (HH:MM)

input group "=== Initial Balance Base Styling ==="
input int                 InpIBWidth           = 2;                  // IB Lines Width
input ENUM_LINE_STYLE     InpIBStyle           = STYLE_SOLID;        // IB Lines Style
input color               InpIBColorTop        = clrForestGreen;     // IB High Line Color
input color               InpIBColorBottom     = clrCrimson;         // IB Low Line Color
input bool                InpShowIBBox         = true;               // Display IB Formation Box
input color               InpIBBoxColor        = clrLightSlateGray;  // IB Range Box Color
input bool                InpShowIBMidline     = true;               // Display IB Midline (50% Equilibrium)
input int                 InpIBMidWidth        = 1;                  // Midline Width
input ENUM_LINE_STYLE     InpIBMidStyle        = STYLE_DASH;         // Midline Style
input color               InpIBMidColor        = clrGold;            // Midline Color

input group "=== Range Extensions Styling ==="
input bool                InpShowTopExt        = true;               // Display Top Extensions
input bool                InpShowBottomExt     = true;               // Display Bottom Extensions
input int                 InpExtCount          = 1;                  // Number of Extension Levels (Count, 1 = Single)
input double              InpExtPercent        = 50.0;               // Step Percentage (% of IB Range per Level)
input int                 InpExtWidth          = 1;                  // Extension Lines Width
input ENUM_LINE_STYLE     InpExtStyle          = STYLE_DASH;         // Extension Lines Style
input color               InpExtColorTop       = clrForestGreen;     // Top Extensions Color
input color               InpExtColorBottom    = clrCrimson;         // Bottom Extensions Color

input group "=== Fibonacci Equilibrium Levels Styling ==="
input bool                InpShowFibos         = true;               // Display Fibonacci Levels
input bool                InpFiboReverse       = false;              // Reverse Fibonacci Direction
input int                 InpFiboWidth         = 1;                  // Fibonacci Lines Width
input ENUM_LINE_STYLE     InpFiboStyle         = STYLE_DOT;          // Fibonacci Lines Style
input color               InpFiboColor         = clrSilver;          // Fibonacci Lines Color

input group "=== Statistical Forecast Styling ==="
input bool                InpShowForecast      = true;               // Display Statistical Forecast
input ENUM_FORECAST_MODE  InpForecastMode      = FORECAST_PREV_OPEN; // Forecast Model
input int                 InpForecastMemory    = 10;                 // Historical Sample Size
input double              InpForecastMult      = 1.0;                // Forecast Range Multiplier
input int                 InpForecastWidth     = 1;                  // Forecast Lines Width
input ENUM_LINE_STYLE     InpForecastStyle     = STYLE_DASHDOT;      // Forecast Lines Style
input color               InpForecastTopColor  = clrMediumSeaGreen;  // Forecast Top Color
input color               InpForecastBotColor  = clrIndianRed;       // Forecast Bottom Color

input group "=== Signals & Chart Hygiene ==="
input bool                InpShowBreakoutArrows= true;               // Display Breakout Signal Arrows
input int                 InpDisplaySessions   = 1;                  // Display Last X Sessions on Chart

//--- Indicator Output Buffers
double BufferBreakoutUp[];
double BufferBreakoutDown[];

//--- Engine Instance & Deterministic Object Prefix
CInitialBalanceEngine g_engine;
string                g_prefix = "";

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Timeframe Integrity Guard: IB requires sub-hourly resolution
   int period_min = PeriodSeconds() / 60;
   if(period_min >= InpIBDurationMinutes || Period() >= PERIOD_H1)
     {
      PrintFormat("Configuration Error: Current chart timeframe (%s) must be strictly smaller than IB Duration (%d min).",
                  EnumToString(Period()), InpIBDurationMinutes);
      return INIT_PARAMETERS_INCORRECT;
     }

// 2. Bind Output Buffers
   SetIndexBuffer(0, BufferBreakoutUp,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferBreakoutDown, INDICATOR_DATA);

   ArraySetAsSeries(BufferBreakoutUp,   false);
   ArraySetAsSeries(BufferBreakoutDown, false);

// Configure Arrow Codes (Wingdings: 233 = Arrow Up, 234 = Arrow Down)
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Initialize Mathematical Engine
   if(!g_engine.Init(InpAutoSession,
                     InpManualIBStart,
                     InpManualIBEnd,
                     InpManualSessionEnd,
                     InpIBDurationMinutes,
                     InpForecastMode,
                     InpForecastMemory,
                     InpForecastMult))
     {
      Print("Critical Error: Failed to initialize Initial Balance Engine.");
      return INIT_FAILED;
     }

// 4. Deterministic Multi-Instance Chart Object Namespace
   g_prefix = StringFormat("IB_%I64d_%s_", ChartID(), InpSessionName);

   string short_name = StringFormat("IB_Pro(%s_%dmin)", InpSessionName, InpIBDurationMinutes);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name + " Bull");
   PlotIndexSetString(1, PLOT_LABEL, short_name + " Bear");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Strict Object Hygiene: Clean up ONLY this session instance's graphics
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Helper: Draw or Update Horizontal Trendline                      |
//+------------------------------------------------------------------+
void DrawLevel(const string name, const datetime t1, const datetime t2, const double price,
               const color c, const ENUM_LINE_STYLE style, const int width)
  {
   string obj_name = g_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_TREND, 0, t1, price, t2, price);
      ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
     }
   else
     {
      ObjectMove(0, obj_name, 0, t1, price);
      ObjectMove(0, obj_name, 1, t2, price);
     }

   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, obj_name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, width);
  }

//+------------------------------------------------------------------+
//| Helper: Draw or Update Background Range Box                      |
//+------------------------------------------------------------------+
void DrawBox(const string name, const datetime t1, const datetime t2, const double top, const double bottom, const color c)
  {
   string obj_name = g_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, t1, top, t2, bottom);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
     }
   else
     {
      ObjectMove(0, obj_name, 0, t1, top);
      ObjectMove(0, obj_name, 1, t2, bottom);
     }

   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, c);
  }

//+------------------------------------------------------------------+
//| Render Visual Levels for Recent Sessions                         |
//+------------------------------------------------------------------+
void RenderVisuals(void)
  {
   int total_sessions = g_engine.GetSessionsCount();
   if(total_sessions <= 0)
      return;

   int start_idx = MathMax(0, total_sessions - InpDisplaySessions);

   for(int s = start_idx; s < total_sessions; s++)
     {
      SIBSession sess;
      if(!g_engine.GetSession(s, sess))
         continue;

      string tag = StringFormat("S%d_", s);
      datetime t_start = sess.startTime;
      datetime t_end   = sess.sessionEndTime;
      datetime t_ib    = sess.isIbClosed ? sess.ibEndTime : t_end;

      double range = sess.top - sess.bottom;

      // 1. Initial Balance Formation Rectangle
      if(InpShowIBBox)
         DrawBox(tag + "Box", t_start, t_ib, sess.top, sess.bottom, InpIBBoxColor);

      // 2. IB High and Low Baseline Lines
      DrawLevel(tag + "Top", t_start, t_end, sess.top, InpIBColorTop, InpIBStyle, InpIBWidth);
      DrawLevel(tag + "Bot", t_start, t_end, sess.bottom, InpIBColorBottom, InpIBStyle, InpIBWidth);

      // 3. Initial Balance Midline (50% Equilibrium)
      if(InpShowIBMidline && range > 0.0)
        {
         double mid_price = (sess.top + sess.bottom) * 0.5;
         DrawLevel(tag + "Mid", t_start, t_end, mid_price, InpIBMidColor, InpIBMidStyle, InpIBMidWidth);
        }

      // 4. Consolidated Range Extensions Grid (Single & Multi-Tier)
      if(range > 0.0 && InpExtCount > 0 && (InpShowTopExt || InpShowBottomExt))
        {
         double step = (InpExtPercent * 0.01) * range;
         int max_levels = MathMin(MathMax(1, InpExtCount), 15); // Safety clamp: 1 to 15 levels

         for(int k = 1; k <= max_levels; k++)
           {
            if(InpShowTopExt)
              {
               double top_ext = sess.top + (k * step);
               DrawLevel(tag + StringFormat("Ext_Top_%d", k), t_start, t_end, top_ext, InpExtColorTop, InpExtStyle, InpExtWidth);
              }

            if(InpShowBottomExt)
              {
               double bot_ext = sess.bottom - (k * step);
               DrawLevel(tag + StringFormat("Ext_Bot_%d", k), t_start, t_end, bot_ext, InpExtColorBottom, InpExtStyle, InpExtWidth);
              }
           }
        }

      // 5. Fibonacci Equilibrium Lines (Extended across the breakout window)
      if(InpShowFibos && range > 0.0)
        {
         double fibs[] = {0.236, 0.382, 0.500, 0.618, 0.786};
         for(int f = 0; f < 5; f++)
           {
            double f_lvl = InpFiboReverse ? (sess.bottom + fibs[f] * range) : (sess.top - fibs[f] * range);
            DrawLevel(tag + StringFormat("Fib_%d", f), t_start, t_end, f_lvl, InpFiboColor, InpFiboStyle, InpFiboWidth);
           }
        }

      // 6. Statistical Forecast Lines
      if(InpShowForecast && sess.forecastTop > 0.0 && sess.forecastBottom > 0.0)
        {
         DrawLevel(tag + "FcastTop", t_start, t_end, sess.forecastTop, InpForecastTopColor, InpForecastStyle, InpForecastWidth);
         DrawLevel(tag + "FcastBot", t_start, t_end, sess.forecastBottom, InpForecastBotColor, InpForecastStyle, InpForecastWidth);
        }
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
   if(rates_total < 10)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Cold Start: Reset Engine on full re-index
   if(prev_calculated == 0)
     {
      g_engine.Reset();
      ArrayInitialize(BufferBreakoutUp,   EMPTY_VALUE);
      ArrayInitialize(BufferBreakoutDown, EMPTY_VALUE);
      ObjectsDeleteAll(0, g_prefix);
      start = 0;
     }

// O(1) Incremental Calculation Pipeline
   for(int i = start; i < rates_total; i++)
     {
      BufferBreakoutUp[i]   = EMPTY_VALUE;
      BufferBreakoutDown[i] = EMPTY_VALUE;

      bool bull_breakout = false;
      bool bear_breakout = false;

      g_engine.ProcessBar(time[i], open[i], high[i], low[i], close[i], bull_breakout, bear_breakout);

      // Signal Emissions onto Buffers (if enabled)
      if(InpShowBreakoutArrows)
        {
         if(bull_breakout)
            BufferBreakoutUp[i] = low[i] - 5 * _Point;

         if(bear_breakout)
            BufferBreakoutDown[i] = high[i] + 5 * _Point;
        }
     }

// Visual Rendering: Throttled to prevent DirectX flushes on every tick
   static ulong last_render_ms = 0;
   ulong cur_ms = GetTickCount64();
   if(cur_ms - last_render_ms >= 200 || prev_calculated == 0)
     {
      RenderVisuals();
      last_render_ms = cur_ms;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
