//+------------------------------------------------------------------+
//|                                        VScore_Dashboard_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.30" // Fixed color polarity to perfectly align with VScore_Pro and VScore_MTF_Pro
#property description "Minimalist and Live-Updating V-Score Multi-Asset Thermal Scanner."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <MyIncludes\VScore_Calculator.mqh>

//--- Input Parameters ---
input string            InpCustomSymbols  = "";              // Custom Symbols (Comma separated, empty for Market Watch)
input int               InpMaxSymbols     = 15;              // Maximum Symbols to display
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_M15;      // Target Timeframe
input int               InpPeriod         = 21;              // V-Score Period (Matches V-Score Pro)
input ENUM_VWAP_PERIOD  InpVWAPReset      = PERIOD_SESSION;  // VWAP Anchor
input int               InpTableX         = 20;              // Table X Offset (Pixels)
input int               InpTableY         = 60;              // Table Y Offset (Pixels)
input int               InpFontSize       = 9;               // UI Font Size
input int               InpRefreshSeconds = 3;               // Background Timer Fallback (Seconds)

//--- Global Variables ---
string          g_symbols[];
int             g_symbols_total   = 0;
string          g_prefix          = "";
bool            g_updating        = false;
ulong           g_last_update_ms  = 0; // Throttle timestamp

//+------------------------------------------------------------------+
//| EnsureDataReady (History sync helper)                            |
//+------------------------------------------------------------------+
bool EnsureDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      SymbolSelect(symbol, true);
     }
   datetime times[];
   int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
   return (copied >= required_bars);
  }

//+------------------------------------------------------------------+
//| GetVScoreValue                                                   |
//+------------------------------------------------------------------+
double GetVScoreValue(string symbol, ENUM_TIMEFRAMES tf, ENUM_VWAP_PERIOD reset, int period)
  {
   int required_bars = period + 150;

   if(!EnsureDataReady(symbol, tf, required_bars))
      return EMPTY_VALUE;

   int htf_bars = iBars(symbol, tf);
   if(htf_bars < required_bars)
      return EMPTY_VALUE;

   int count = MathMin(htf_bars, 300);

   double h_open[], h_high[], h_low[], h_close[];
   long   h_vol[];
   datetime h_time[];

   ArrayResize(h_open, count);
   ArrayResize(h_high, count);
   ArrayResize(h_low, count);
   ArrayResize(h_close, count);
   ArrayResize(h_vol, count);
   ArrayResize(h_time, count);

   if(CopyTime(symbol, tf, 0, count, h_time) != count ||
      CopyOpen(symbol, tf, 0, count, h_open) != count ||
      CopyHigh(symbol, tf, 0, count, h_high) != count ||
      CopyLow(symbol, tf, 0, count, h_low) != count ||
      CopyClose(symbol, tf, 0, count, h_close) != count ||
      CopyTickVolume(symbol, tf, 0, count, h_vol) != count)
     {
      return EMPTY_VALUE;
     }

   CVScoreCalculator calc;
   if(!calc.Init(period, reset))
      return EMPTY_VALUE;

   double h_res[];
   ArrayResize(h_res, count);
   ArrayInitialize(h_res, 0.0);

   calc.Calculate(count, 0, h_time, h_open, h_high, h_low, h_close, h_vol, h_vol, h_res);

   return h_res[count - 1];
  }

//+------------------------------------------------------------------+
//| ParseSymbols                                                     |
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
//| CreateButton                                                     |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color bg_color, color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| RenderCell                                                       |
//+------------------------------------------------------------------+
void RenderCell(string symbol, double val, int x, int y, int w, int h)
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
      text = DoubleToString(val, 3);

      //--- Swapped 5-Zone Thermal Color Palette (Corrected Polarity)
      // Positive/Bullish -> Bluish / Cold
      // Negative/Bearish -> Reddish / Hot
      if(val >= 2.0)
        {
         bg_color = clrDeepSkyBlue; // Bull Extreme (Deep Blue)
         text_color = clrWhite;
        }
      else
         if(val >= 1.5)
           {
            bg_color = clrLightSkyBlue; // Bull Flow (Light Blue)
            text_color = clrBlack;
           }
         else
            if(val <= -2.0)
              {
               bg_color = clrOrangeRed;  // Bear Extreme (Dark Red)
               text_color = clrWhite;
              }
            else
               if(val <= -1.5)
                 {
                  bg_color = clrCoral;      // Bear Flow (Coral)
                  text_color = clrBlack;
                 }
               else
                 {
                  bg_color = clrWhite;      // Neutral
                  text_color = clrDarkGray;
                 }
     }
   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderDashboard                                                  |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating || g_symbols_total <= 0)
      return;

   g_updating = true;

   int col_w_sym = 100;
   int col_w_val = 80;
   int row_h     = 22;

//--- 1. Render Table Header
   int header_y = InpTableY;
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   CreateButton(g_prefix + "H_Sym", "Symbol (" + tf_name + ")", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_Val", "V-Score", InpTableX + col_w_sym + 2, header_y, col_w_val, row_h, clrDarkSlateGray, clrWhite);

//--- 2. Loop and Calculate each asset row
   for(int r = 0; r < g_symbols_total; r++)
     {
      string sym = g_symbols[r];
      int row_y = InpTableY + row_h + 2 + (r * (row_h + 2));

      // Symbol Button (Clickable chart switcher)
      CreateButton(g_prefix + "_SymBtn_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

      // Get exact real-time V-Score
      double val = GetVScoreValue(sym, InpTimeframe, InpVWAPReset, InpPeriod);

      // Render the thermal cell
      RenderCell(sym, val, InpTableX + col_w_sym + 2, row_y, col_w_val, row_h);
     }

   ChartRedraw();
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
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
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   Comment("");
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
//--- Real-time high frequency tick throttling (Max 5 updates per second / 200ms)
   ulong current_ms = GetTickCount64();
   if(current_ms - g_last_update_ms >= 200)
     {
      g_last_update_ms = current_ms;
      RenderDashboard();
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderDashboard();
  }

//+------------------------------------------------------------------+
//| OnChartEvent                                                     |
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
            ChartRedraw();
           }
        }
     }
  }
//+------------------------------------------------------------------+
