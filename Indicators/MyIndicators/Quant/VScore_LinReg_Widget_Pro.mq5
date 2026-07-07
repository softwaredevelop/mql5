//+------------------------------------------------------------------+
//|                                     VScore_LinReg_Widget_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded V-Score cell color polarity to perfectly align with corrected Swapped Thermal Palette standards
#property description "Unified Volatility & Trend-Integrity Chart HUD Widget."
#property description "Displays V-Score and LinReg R2/Slope for the current symbol in the bottom-left corner."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\LinearRegression_Calculator.mqh>

//--- Input Parameters ---
input group                     "Heads-Up Display Settings"
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_M15;      // Target Higher Timeframe (MTF)
input int               InpRefreshSeconds = 3;               // Background Timer Fallback (Seconds)

input group                     "V-Score Settings"
input int                       InpVScorePeriod   = 21;              // V-Score Period
input ENUM_VWAP_PERIOD  InpVWAPReset      = PERIOD_SESSION;  // VWAP Anchor Reset

input group                     "Linear Regression Settings"
input int                       InpLinRegPeriod   = 20;              // Regression Period (N)
input double                    InpTrendLevel     = 0.7;             // Strong Trend Level (R2 Threshold)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group                     "Widget Placement (Pixels)"
input int                       InpTableX         = 20;              // Widget X Offset (From Left)
input int                       InpTableY         = 30;              // Widget Y Offset (From Bottom)
input int                       InpFontSize       = 9;               // UI Font Size

//--- Global Variables ---
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
//| GetLinRegValues                                                  |
//+------------------------------------------------------------------+
bool GetLinRegValues(string symbol, ENUM_TIMEFRAMES tf, int period, double &out_r2, double &out_slope)
  {
   int required_bars = period + 20;

   if(!EnsureDataReady(symbol, tf, required_bars))
      return false;

   int htf_bars = iBars(symbol, tf);
   if(htf_bars < required_bars)
      return false;

   int count = MathMin(htf_bars, 300);

   double h_open[], h_high[], h_low[], h_close[];
   datetime h_time[];

   ArrayResize(h_open, count);
   ArrayResize(h_high, count);
   ArrayResize(h_low, count);
   ArrayResize(h_close, count);
   ArrayResize(h_time, count);

   if(CopyTime(symbol, tf, 0, count, h_time) != count ||
      CopyOpen(symbol, tf, 0, count, h_open) != count ||
      CopyHigh(symbol, tf, 0, count, h_high) != count ||
      CopyLow(symbol, tf, 0, count, h_low) != count ||
      CopyClose(symbol, tf, 0, count, h_close) != count)
     {
      return false;
     }

   CLinearRegressionCalculator calc;
   if(!calc.Init(period))
      return false;

   double h_s[], h_r2[], h_f[];
   ArrayResize(h_s, count);
   ArrayResize(h_r2, count);
   ArrayResize(h_f, count);

   calc.CalculateState(count, 0, h_open, h_high, h_low, h_close, PRICE_CLOSE, h_s, h_r2, h_f);

   out_r2 = h_r2[count - 1];
   out_slope = h_s[count - 1];
   return true;
  }

//+------------------------------------------------------------------+
//| CreateButton                                                     |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color bg_color, color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Fixed: Lower-Left Corner for clean HUD layout
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
//| RenderVScoreCell                                                 |
//+------------------------------------------------------------------+
void RenderVScoreCell(string symbol, double val, int x, int y, int w, int h)
  {
   string name = g_prefix + "_" + symbol + "_VScore";
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
//| RenderLinRegCell                                                 |
//+------------------------------------------------------------------+
void RenderLinRegCell(string symbol, double r2_val, double slope_val, int x, int y, int w, int h)
  {
   string name = g_prefix + "_" + symbol + "_LinReg";
   string text = "";
   color  bg_color = clrWhite;
   color  text_color = clrBlack;

   if(r2_val == EMPTY_VALUE)
     {
      text = "Sync...";
      bg_color = clrWhite;
      text_color = clrSilver;
     }
   else
     {
      string arrow = (slope_val > 0.0) ? "▲ " : ((slope_val < 0.0) ? "▼ " : "■ ");
      text = arrow + DoubleToString(r2_val, 3);

      //--- Dynamic 3-Zone Thermal Palette (Chop = Gray, Weak = Orange, Strong = Lime)
      if(r2_val >= InpTrendLevel)
        {
         bg_color = clrMediumSeaGreen; // Strong Trend (Green)
         text_color = clrWhite;
        }
      else
         if(r2_val <= 0.3)
           {
            bg_color = clrSlateGray;     // Chop / Range (Gray)
            text_color = clrWhite;
           }
         else
           {
            bg_color = clrOrange;        // Weak Trend / Transition (Orange)
            text_color = clrBlack;
           }
     }
   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderDashboard                                                  |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating)
      return;

   g_updating = true;

   int col_w_sym   = 100;
   int col_w_vs    = 80;
   int col_w_lr2   = 100;
   int row_h       = 22;

   string sym = _Symbol; // Automatically lock to the current chart symbol

//--- 1. Render Table Header (Placed above the data row)
   int header_y = InpTableY + row_h + 2; // Y coordinates grow UPWARDS from bottom-left corner
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   CreateButton(g_prefix + "H_Sym", "Symbol (" + tf_name + ")", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_VS",  "V-Score", InpTableX + col_w_sym + 2, header_y, col_w_vs, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_LR2", "R2 & Slope", InpTableX + col_w_sym + col_w_vs + 4, header_y, col_w_lr2, row_h, clrDarkSlateGray, clrWhite);

//--- 2. Calculate and Render Current Row (Placed at baseline Y)
   int row_y = InpTableY;

// Symbol display (Flat/unclickable label for the active chart symbol)
   CreateButton(g_prefix + "_SymLbl_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

// Get V-Score Value
   double vs_val = GetVScoreValue(sym, InpTimeframe, InpVWAPReset, InpVScorePeriod);

// Get Linear Regression R2 and Slope Values
   double r2_val = EMPTY_VALUE;
   double slope_val = 0.0;
   GetLinRegValues(sym, InpTimeframe, InpLinRegPeriod, r2_val, slope_val);

// Render cells with synchronized layouts
   RenderVScoreCell(sym, vs_val, InpTableX + col_w_sym + 2, row_y, col_w_vs, row_h);
   RenderLinRegCell(sym, r2_val, slope_val, InpTableX + col_w_sym + col_w_vs + 4, row_y, col_w_lr2, row_h);

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
   g_prefix = StringFormat("VLW_%I64d_", ChartID()); // Unified VScore-LinReg dynamic widget prefix

   ObjectsDeleteAll(0, g_prefix);

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
