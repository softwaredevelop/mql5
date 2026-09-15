//+------------------------------------------------------------------+
//|                                           RVScore_Widget_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.00"
#property description "Rolling Volume-Weighted Z-Score (RV-Score) Chart HUD Widget."
#property description "Displays real-time stationary RV-Score telemetry in the bottom-left corner with 7-zone thermal matrix."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Included Core Suite Frameworks
#include <MyIncludes\RVScore_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Candle Source Enum
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Standard OHLC Data
   CANDLE_HEIKIN_ASHI    // Heikin Ashi Smoothed Data
  };
#endif

//--- Inputs
input group "--- Heads-Up Display Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe            = PERIOD_M15;        // Target Higher Timeframe (MTF)
input int                       InpRefreshSeconds       = 3;                 // Background Timer Fallback (Seconds)

input group "--- Rolling VWAP Engine ---"
input ENUM_ROLLING_TYPE         InpRollingType          = ROLLING_BARS;      // Rolling Window Type
input int                       InpRollingWindow        = 144;               // Rolling Window (Bars or Minutes)
input int                       InpSigmaPeriod          = 20;                // Volatility Lookback (Sigma)

input group "--- Calculation Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;       // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;   // Candle Source

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (Sigma Multiples) ---"
input double                    InpLevelFlowHigh        = 1.5;               // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow         = -1.5;              // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh      = 2.0;               // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow       = -2.0;              // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh     = 2.5;               // High Extreme Level (Bullish Exhaustion)
input double                    InpLevelExtremeLow      = -2.5;              // Low Extreme Level (Bearish Exhaustion)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Widget Placement (Pixels) ---"
input int                       InpTableX               = 20;                // Widget X Offset (From Left)
input int                       InpTableY               = 30;                // Widget Y Offset (From Bottom)
input int                       InpFontSize             = 9;                 // UI Font Size

//--- Global HUD State Variables
string g_prefix         = "";
bool   g_updating       = false;
ulong  g_last_update_ms = 0; // Throttle timestamp

//+------------------------------------------------------------------+
//| Heap-Free RV-Score Calculation for Widget Telemetry              |
//+------------------------------------------------------------------+
double GetRVScoreValue(const string symbol, const ENUM_TIMEFRAMES tf)
  {
// 1. Calculate Required Lookback History Dynamically
   int required_bars = 50;

   if(InpRollingType == ROLLING_BARS)
     {
      required_bars = InpRollingWindow + InpSigmaPeriod + 10;
     }
   else // ROLLING_TIME
     {
      int tf_sec = PeriodSeconds(tf);
      if(tf_sec < 1)
         tf_sec = 60;

      int bars_in_time = (int)(((long)InpRollingWindow * 60) / tf_sec) + 10;
      required_bars = bars_in_time + InpSigmaPeriod + 10;
     }

   required_bars = MathMin(required_bars, 3000); // Enterprise memory safeguard

// 2. Asynchronous Data Readiness Verification
   if(!CDataSync::EnsureHTFDataReady(symbol, tf, required_bars))
      return EMPTY_VALUE;

   int htf_bars = iBars(symbol, tf);
   if(htf_bars < required_bars)
      return EMPTY_VALUE;

   int count = MathMin(htf_bars, required_bars);

// 3. Fetch Pricing & Volume Caches
   double   h_open[], h_high[], h_low[], h_close[];
   long     h_tick_vol[], h_vol[];
   datetime h_time[];

   ArrayResize(h_open,     count);
   ArraySetAsSeries(h_open,     false);
   ArrayResize(h_high,     count);
   ArraySetAsSeries(h_high,     false);
   ArrayResize(h_low,      count);
   ArraySetAsSeries(h_low,      false);
   ArrayResize(h_close,    count);
   ArraySetAsSeries(h_close,    false);
   ArrayResize(h_tick_vol, count);
   ArraySetAsSeries(h_tick_vol, false);
   ArrayResize(h_vol,      count);
   ArraySetAsSeries(h_vol,      false);
   ArrayResize(h_time,     count);
   ArraySetAsSeries(h_time,     false);

   if(CopyTime(symbol,       tf, 0, count, h_time)     != count ||
      CopyOpen(symbol,       tf, 0, count, h_open)     != count ||
      CopyHigh(symbol,       tf, 0, count, h_high)     != count ||
      CopyLow(symbol,        tf, 0, count, h_low)      != count ||
      CopyClose(symbol,      tf, 0, count, h_close)    != count ||
      CopyTickVolume(symbol, tf, 0, count, h_tick_vol) != count)
     {
      return EMPTY_VALUE;
     }

   long vol_limit = (long)SymbolInfoDouble(symbol, SYMBOL_VOLUME_LIMIT);
   if(vol_limit > 0)
      CopyRealVolume(symbol, tf, 0, count, h_vol);
   else
      ArrayCopy(h_vol, h_tick_vol, 0, 0, count);

// 4. Heap-Free Stack Calculator Execution (Zero Leaks, Deterministic Lifecycle)
   CRVScoreCalculator calc;
   bool is_ha = (InpCandleSource == CANDLE_HEIKIN_ASHI);

   if(!calc.Init(InpSigmaPeriod, InpRollingType, InpRollingWindow, InpVolumeType, is_ha))
      return EMPTY_VALUE;

   double h_res[];
   ArrayResize(h_res, count);
   ArraySetAsSeries(h_res, false);
   ArrayInitialize(h_res, 0.0);

   calc.Calculate(count, 0, h_time, h_open, h_high, h_low, h_close, h_tick_vol, h_vol, h_res);

   return h_res[count - 1];
  }

//+------------------------------------------------------------------+
//| CreateButton (HUD Flat Element Primitive)                        |
//+------------------------------------------------------------------+
void CreateButton(const string name, const string text, const int x, const int y, const int w, const int h, const color bg_color, const color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Fixed Lower-Left Anchor
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0,  name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| RenderRVScoreCell (Dynamic 7-Zone Super-Thermal Palette)         |
//+------------------------------------------------------------------+
void RenderRVScoreCell(const string symbol, const double val, const int x, const int y, const int w, const int h)
  {
   string name = g_prefix + "_" + symbol + "_RVScore";
   string text = "";
   color  bg_color = clrWhite;
   color  text_color = clrBlack;

   if(val == EMPTY_VALUE)
     {
      text = "Sync...";
      bg_color = clrWhite;
      text_color = clrSilver;
     }
   else
     {
      text = DoubleToString(val, 2) + " σ";

      // Symmetrical 7-Zone Super-Thermal Matrix
      if(val >= InpLevelExtremeHigh)
        {
         bg_color   = clrMidnightBlue; // Bull Extreme -> Liquidity Exhaustion Climax
         text_color = clrWhite;
        }
      else
         if(val >= InpLevelClimaxHigh)
           {
            bg_color   = clrDeepSkyBlue;  // Bull Climax
            text_color = clrWhite;
           }
         else
            if(val >= InpLevelFlowHigh)
              {
               bg_color   = clrLightSkyBlue; // Bull Flow Expansion
               text_color = clrBlack;
              }
            else
               if(val <= InpLevelExtremeLow)
                 {
                  bg_color   = clrDarkRed;      // Bear Extreme -> Panic Capitulation Floor
                  text_color = clrWhite;
                 }
               else
                  if(val <= InpLevelClimaxLow)
                    {
                     bg_color   = clrOrangeRed;    // Bear Climax
                     text_color = clrWhite;
                    }
                  else
                     if(val <= InpLevelFlowLow)
                       {
                        bg_color   = clrCoral;        // Bear Flow Expansion
                        text_color = clrBlack;
                       }
                     else
                       {
                        bg_color   = clrWhite;        // Stationary Equilibrium / Noise Zone
                        text_color = clrDarkGray;
                       }
     }

   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderDashboard (HUD Layout Engine)                              |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating)
      return;

   g_updating = true;

   int col_w_sym = 100;
   int col_w_rv  = 90;
   int row_h     = 22;

   string sym = _Symbol;

// 1. Render Table Header (Placed above baseline Y - Y grows upwards)
   int header_y = InpTableY + row_h + 2;
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   CreateButton(g_prefix + "H_Sym", "Symbol (" + tf_name + ")", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_RVS", "RV-Score", InpTableX + col_w_sym + 2, header_y, col_w_rv, row_h, clrDarkSlateGray, clrWhite);

// 2. Render Data Row (Placed at baseline Y)
   int row_y = InpTableY;
   CreateButton(g_prefix + "_SymLbl_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

// Calculate and Render RV-Score cell
   double rv_val = GetRVScoreValue(sym, InpTimeframe);
   RenderRVScoreCell(sym, rv_val, InpTableX + col_w_sym + 2, row_y, col_w_rv, row_h);

   ChartRedraw(0);
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_updating       = false;
   g_last_update_ms = 0;
   g_prefix         = StringFormat("RVSW_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   RenderDashboard();

   EventSetTimer(InpRefreshSeconds);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation iteration                           |
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
// GUI Throttling: Enforce maximum 5 UI updates per second (200ms)
   ulong current_ms = GetTickCount64();
   if(current_ms - g_last_update_ms >= 200)
     {
      g_last_update_ms = current_ms;
      RenderDashboard();
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization & Fallback Daemon)   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderDashboard();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
