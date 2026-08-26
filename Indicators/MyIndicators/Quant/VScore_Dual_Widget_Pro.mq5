//+------------------------------------------------------------------+
//|                                         VScore_Dual_Widget_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Fully Configurable Dual-Slot HUD Telemetry with Heap-Free Execution
#property description "Dual-Timeframe Volume-Weighted Z-Score (V-Score) Chart HUD Widget."
#property description "Displays Tactical and Strategic V-Score metrics side-by-side with 7-zone thermal telemetry."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Included Engines & Core Tools
#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting candle source ---
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };
#endif

//--- Input Parameters ---
input group "--- Heads-Up Display Settings ---"
input int                       InpRefreshSeconds       = 3;                     // Background Timer Fallback (Seconds)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Slot 1: Tactical Flow (e.g. Daily / M15) ---"
input string                    InpSlot1Label           = "Daily";               // Slot 1 Custom Label
input ENUM_TIMEFRAMES           InpSlot1TF              = PERIOD_M15;            // Slot 1 Timeframe
input ENUM_VWAP_PERIOD          InpSlot1Reset           = PERIOD_SESSION;        // Slot 1 VWAP Anchor Reset
input int                       InpSlot1Period          = 20;                    // Slot 1 Volatility Period (Sigma)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Slot 2: Strategic Context (e.g. Weekly / H1) ---"
input string                    InpSlot2Label           = "Weekly";              // Slot 2 Custom Label
input ENUM_TIMEFRAMES           InpSlot2TF              = PERIOD_H1;             // Slot 2 Timeframe
input ENUM_VWAP_PERIOD          InpSlot2Reset           = PERIOD_WEEK;           // Slot 2 VWAP Anchor Reset
input int                       InpSlot2Period          = 20;                    // Slot 2 Volatility Period (Sigma)

input group "--- Calculation & Session Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;       // Candle Source
input int                       InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string                    InpCustomSessionStart   = "09:30";               // Custom Session Start (HH:MM)
input string                    InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (Sigma Units) ---"
input double                    InpLevelFlowHigh        = 1.5;                   // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow         = -1.5;                  // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh      = 2.0;                   // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow       = -2.0;                  // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh     = 2.5;                   // High Extreme Level (Bullish Exhaustion)
input double                    InpLevelExtremeLow      = -2.5;                  // Low Extreme Level (Bearish Exhaustion)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Widget Placement (Pixels) ---"
input int                       InpTableX               = 20;                    // Widget X Offset (From Left)
input int                       InpTableY               = 30;                    // Widget Y Offset (From Bottom)
input int                       InpFontSize             = 9;                     // UI Font Size

//--- Global Variables ---
string g_prefix         = "";
bool   g_updating       = false;
ulong  g_last_update_ms = 0;

//+------------------------------------------------------------------+
//| Heap-Free V-Score Calculation for Widget Slots                   |
//+------------------------------------------------------------------+
double GetVScoreValue(const string symbol, const ENUM_TIMEFRAMES tf, const ENUM_VWAP_PERIOD reset, const int period)
  {
// 1. Calculate Required Lookback Dynamically
   int tf_sec = PeriodSeconds(tf);
   if(tf_sec < 1)
      tf_sec = 60;

   int anchor_bars = 100;
   switch(reset)
     {
      case PERIOD_SESSION:
         anchor_bars = (int)(86400 / tf_sec) + 20;
         break;
      case PERIOD_WEEK:
         anchor_bars = (int)(7 * 86400 / tf_sec) + 50;
         break;
      case PERIOD_MONTH:
         anchor_bars = (int)(31 * 86400 / tf_sec) + 100;
         break;
      case PERIOD_CUSTOM_SESSION:
         anchor_bars = (int)(86400 / tf_sec) + 20;
         break;
     }

   int required_bars = period + anchor_bars;
   required_bars = MathMin(required_bars, 3000);

// 2. Data Readiness Check
   if(!CDataSync::EnsureHTFDataReady(symbol, tf, required_bars))
      return EMPTY_VALUE;

   int htf_bars = iBars(symbol, tf);
   if(htf_bars < required_bars)
      return EMPTY_VALUE;

   int count = MathMin(htf_bars, required_bars);

// 3. Fetch Price & Volume Data
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

// 4. Heap-Free Stack Calculator Execution
   CVScoreCalculator calc;
   bool is_ha = (InpCandleSource == CANDLE_HEIKIN_ASHI);
   bool init_ok = false;

   if(reset == PERIOD_CUSTOM_SESSION)
      init_ok = calc.Init(period, InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, InpTzShift, is_ha, period * 5);
   else
      init_ok = calc.Init(period, reset, InpVolumeType, InpTzShift, is_ha, period * 5);

   if(!init_ok)
      return EMPTY_VALUE;

   double h_res[];
   ArrayResize(h_res, count);
   ArraySetAsSeries(h_res, false);
   ArrayInitialize(h_res, 0.0);

   calc.Calculate(count, 0, h_time, h_open, h_high, h_low, h_close, h_tick_vol, h_vol, h_res);

   return h_res[count - 1];
  }

//+------------------------------------------------------------------+
//| CreateButton (HUD Element)                                       |
//+------------------------------------------------------------------+
void CreateButton(const string name, const string text, const int x, const int y, const int w, const int h, const color bg_color, const color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
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
//| RenderVScoreCell (Dynamic 7-Zone Super-Thermal Palette)          |
//+------------------------------------------------------------------+
void RenderVScoreCell(const string symbol, const double val, const string slot_tag, const int x, const int y, const int w, const int h)
  {
   string name = g_prefix + "_" + symbol + "_" + slot_tag;
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
         bg_color = clrMidnightBlue; // Bull Extreme (Deep Midnight Blue)
         text_color = clrWhite;
        }
      else
         if(val >= InpLevelClimaxHigh)
           {
            bg_color = clrDeepSkyBlue;  // Bull Climax (Deep Sky Blue)
            text_color = clrWhite;
           }
         else
            if(val >= InpLevelFlowHigh)
              {
               bg_color = clrLightSkyBlue; // Bull Flow (Light Blue)
               text_color = clrBlack;
              }
            else
               if(val <= InpLevelExtremeLow)
                 {
                  bg_color = clrDarkRed;      // Bear Extreme (Dark Crimson Red)
                  text_color = clrWhite;
                 }
               else
                  if(val <= InpLevelClimaxLow)
                    {
                     bg_color = clrOrangeRed;    // Bear Climax (Orange Red)
                     text_color = clrWhite;
                    }
                  else
                     if(val <= InpLevelFlowLow)
                       {
                        bg_color = clrCoral;        // Bear Flow (Coral Pink)
                        text_color = clrBlack;
                       }
                     else
                       {
                        bg_color = clrWhite;        // Neutral Range
                        text_color = clrDarkGray;
                       }
     }

   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderDashboard (Dual-Slot HUD Layout Engine)                    |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating)
      return;

   g_updating = true;

   int col_w_sym = 90;
   int col_w_vs  = 95;
   int row_h     = 22;

   string sym = _Symbol;

// 1. Render Table Header (Placed above baseline Y)
   int header_y = InpTableY + row_h + 2; // Y coordinates grow UPWARDS

   string s1_tf = StringSubstr(EnumToString(InpSlot1TF), 7);
   string s2_tf = StringSubstr(EnumToString(InpSlot2TF), 7);

   string s1_header = InpSlot1Label + " (" + s1_tf + ")";
   string s2_header = InpSlot2Label + " (" + s2_tf + ")";

   CreateButton(g_prefix + "H_Sym", "Symbol", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_S1",  s1_header, InpTableX + col_w_sym + 2, header_y, col_w_vs, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_S2",  s2_header, InpTableX + col_w_sym + col_w_vs + 4, header_y, col_w_vs, row_h, clrDarkSlateGray, clrWhite);

// 2. Render Data Row (Placed at baseline Y)
   int row_y = InpTableY;
   CreateButton(g_prefix + "_SymLbl_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

// Compute Slot 1 and Slot 2 Values
   double vs_slot1 = GetVScoreValue(sym, InpSlot1TF, InpSlot1Reset, InpSlot1Period);
   double vs_slot2 = GetVScoreValue(sym, InpSlot2TF, InpSlot2Reset, InpSlot2Period);

// Render Dual Cells side-by-side
   RenderVScoreCell(sym, vs_slot1, "Slot1", InpTableX + col_w_sym + 2, row_y, col_w_vs, row_h);
   RenderVScoreCell(sym, vs_slot2, "Slot2", InpTableX + col_w_sym + col_w_vs + 4, row_y, col_w_vs, row_h);

   ChartRedraw(0);
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_updating = false;
   g_last_update_ms = 0;
   g_prefix = StringFormat("VSDW_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   RenderDashboard();

   EventSetTimer(InpRefreshSeconds);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
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
// Tick throttling: Maximum 5 UI updates per second (200ms)
   ulong current_ms = GetTickCount64();
   if(current_ms - g_last_update_ms >= 200)
     {
      g_last_update_ms = current_ms;
      RenderDashboard();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderDashboard();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
