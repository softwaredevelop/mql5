//+------------------------------------------------------------------+
//|                                        VScore_Dashboard_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Single-Column Multi-Asset V-Score Scanner with 7-Zone Thermal Matrix
#property description "Minimalist and Live-Updating V-Score Multi-Asset Thermal Scanner."
#property description "Features 3-decimal precision, heap-free execution, and 1-click chart switching."

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
input group "--- Asset Selection Settings ---"
input string            InpCustomSymbols        = "";                    // Custom Symbols (Comma separated, empty for Market Watch)
input int               InpMaxSymbols           = 15;                    // Maximum Symbols to display
input int               InpRefreshSeconds       = 3;                     // Background Timer Fallback (Seconds)

input group "--- V-Score Settings ---"
input ENUM_TIMEFRAMES   InpTimeframe            = PERIOD_M15;            // Target Timeframe
input int               InpPeriod               = 20;                    // V-Score Period (Sigma)
input ENUM_VWAP_PERIOD  InpVWAPReset            = PERIOD_SESSION;        // VWAP Anchor Reset
input int               InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string            InpCustomSessionStart   = "09:30";               // Start time (HH:MM) for Custom Session
input string            InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

input group "--- Calculation Settings ---"
input ENUM_APPLIED_VOLUME InpVolumeType         = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE  InpCandleSource       = CANDLE_STANDARD;       // Candle Source

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (Sigma Units) ---"
input double            InpLevelFlowHigh        = 1.5;                   // High Warning Level (Bullish Flow)
input double            InpLevelFlowLow         = -1.5;                  // Low Warning Level (Bearish Flow)
input double            InpLevelClimaxHigh      = 2.0;                   // High Climax Level (Bullish Climax)
input double            InpLevelClimaxLow       = -2.0;                  // Low Climax Level (Bearish Climax)
input double            InpLevelExtremeHigh     = 2.5;                   // High Extreme Level (Bullish Exhaustion)
input double            InpLevelExtremeLow      = -2.5;                  // Low Extreme Level (Bearish Exhaustion)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Dashboard Placement (Pixels) ---"
input int               InpTableX               = 20;                    // Table X Offset (From Left)
input int               InpTableY               = 50;                    // Table Y Offset (From Top)
input int               InpFontSize             = 9;                     // UI Font Size

//--- Global Variables ---
string g_symbols[];
int    g_symbols_total  = 0;
string g_prefix         = "";
bool   g_updating       = false;
ulong  g_last_update_ms = 0;

//+------------------------------------------------------------------+
//| Heap-Free V-Score Calculation Engine                             |
//+------------------------------------------------------------------+
double GetVScoreValue(const string symbol, const ENUM_TIMEFRAMES tf, const ENUM_VWAP_PERIOD reset, const int period)
  {
// 1. Dynamic Lookback History Sizing
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
//| Parse Symbols from Input String or Market Watch                  |
//+------------------------------------------------------------------+
void ParseSymbols()
  {
   ArrayFree(g_symbols);

   if(InpCustomSymbols != "" && InpCustomSymbols != NULL)
     {
      string temp[];
      int split = StringSplit(InpCustomSymbols, ',', temp);
      int valid_count = 0;

      for(int i = 0; i < split; i++)
        {
         string sym = temp[i];
         StringTrimLeft(sym);
         StringTrimRight(sym);
         if(sym != "" && SymbolInfoInteger(sym, SYMBOL_SELECT) != 0)
           {
            ArrayResize(g_symbols, valid_count + 1);
            g_symbols[valid_count] = sym;
            valid_count++;
           }
         if(valid_count >= InpMaxSymbols)
            break;
        }
      g_symbols_total = valid_count;
     }
   else
     {
      int total = SymbolsTotal(true);
      int count = 0;
      for(int i = 0; i < total; i++)
        {
         string sym = SymbolName(i, true);
         if(sym != "" && sym != NULL)
           {
            ArrayResize(g_symbols, count + 1);
            g_symbols[count] = sym;
            count++;
           }
         if(count >= InpMaxSymbols)
            break;
        }
      g_symbols_total = count;
     }
  }

//+------------------------------------------------------------------+
//| CreateButton (Dashboard Cell)                                    |
//+------------------------------------------------------------------+
void CreateButton(const string name, const string text, const int x, const int y, const int w, const int h, const color bg_color, const color text_color, const bool selectable=false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0,  name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
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
//| RenderCell (7-Zone Super-Thermal Palette with 3 Decimals)        |
//+------------------------------------------------------------------+
void RenderCell(const string symbol, const double val, const int x, const int y, const int w, const int h)
  {
   string name = g_prefix + "_" + symbol + "_Val";
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
      text = DoubleToString(val, 2);

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
//| RenderDashboard (Single-Column Layout Engine)                    |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating || g_symbols_total <= 0)
      return;

   g_updating = true;

   int col_w_sym = 100;
   int col_w_val = 90;
   int row_h     = 22;

// 1. Render Table Header
   int header_y = InpTableY;
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   CreateButton(g_prefix + "H_Sym", "Symbol", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_Val", "V-Score (" + tf_name + ")", InpTableX + col_w_sym + 2, header_y, col_w_val, row_h, clrDarkSlateGray, clrWhite);

// 2. Loop and Calculate each Asset Row (Growing Downwards)
   for(int r = 0; r < g_symbols_total; r++)
     {
      string sym = g_symbols[r];
      int row_y = InpTableY + row_h + 2 + (r * (row_h + 2));

      // Clickable Symbol Button (Chart Switcher)
      CreateButton(g_prefix + "_SymBtn_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack, true);

      // Get exact real-time V-Score
      double val = GetVScoreValue(sym, InpTimeframe, InpVWAPReset, InpPeriod);

      // Render the thermal cell
      RenderCell(sym, val, InpTableX + col_w_sym + 2, row_y, col_w_val, row_h);
     }

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
   g_prefix = StringFormat("VSD_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   ParseSymbols();
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
// Rate throttling: Max 5 scans per second (200ms)
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
//| OnChartEvent (Interactive 1-Click Chart Switcher)                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam, g_prefix) == 0 && StringFind(sparam, "_SymBtn_") != -1)
        {
         string symbol = ObjectGetString(0, sparam, OBJPROP_TEXT);
         if(symbol != "" && symbol != NULL)
           {
            ChartSetSymbolPeriod(0, symbol, _Period);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw(0);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
