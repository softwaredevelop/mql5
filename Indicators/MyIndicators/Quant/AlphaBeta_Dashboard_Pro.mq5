//+------------------------------------------------------------------+
//|                                     AlphaBeta_Dashboard_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Fixed window alignment and self-reference routing
#property description "Interactive Alpha & Beta Performance Heatmap Scanner."
#property description "Click on any Symbol button to instantly switch the chart."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <MyIncludes\MathStatistics_Calculator.mqh>

//--- Input Parameters ---
input string            InpCustomSymbols  = "";              // Custom Symbols (Comma separated, empty for Market Watch)
input int               InpMaxSymbols     = 15;              // Maximum Symbols to display
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_H1;       // Target Timeframe (Recommended: PERIOD_H1)
input int               InpLookback       = 60;              // Rolling Lookback Window (Bars)
input string            InpBenchmark      = "US500";         // Global Equity Benchmark
input string            InpForexBench     = "DX";            // Forex Benchmark (Dollar Index)
input int               InpTableX         = 20;              // Table X Offset (Pixels)
input int               InpTableY         = 60;              // Table Y Offset (Pixels)
input int               InpFontSize       = 9;               // UI Font Size
input int               InpRefreshSeconds = 3;               // Background Timer Fallback (Seconds)

//--- Global Variables ---
string                     g_symbols[];
int                        g_symbols_total   = 0;
string                     g_prefix          = "";
bool                       g_updating        = false;
ulong                      g_last_update_ms  = 0; // Throttle timestamp
CMathStatisticsCalculator *g_stats           = NULL;

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
//| GetAlphaBeta                                                     |
//| Fully synchronized and window-aligned calculation                |
//+------------------------------------------------------------------+
bool GetAlphaBeta(string symbol, ENUM_TIMEFRAMES tf, int lookback, double &out_alpha, double &out_beta)
  {
// FIXED: Window size matches exactly 'lookback' to ensure 100% data alignment with standard indicator
   int required_bars = lookback;

   if(!EnsureDataReady(symbol, tf, required_bars))
      return false;

   bool is_forex = IsForexPair(symbol);
   string bench = is_forex ? InpForexBench : InpBenchmark;

// FIXED: Self-Reference protection. If symbol is its own benchmark, return baseline CAPM values
   if(symbol == bench)
     {
      out_alpha = 0.0;
      out_beta = 1.0;
      return true;
     }

   if(!EnsureDataReady(bench, tf, required_bars))
      return false;

   double close_A[];
   datetime times[];

   ArrayResize(close_A, required_bars);
   ArrayResize(times, required_bars);

   if(CopyClose(symbol, tf, 0, required_bars, close_A) != required_bars ||
      CopyTime(symbol, tf, 0, required_bars, times) != required_bars)
      return false;

// High-performance chronological alignment for the benchmark close prices
   double close_B[];
   ArrayResize(close_B, required_bars);

   for(int i = 0; i < required_bars; i++)
     {
      int shift = iBarShift(bench, tf, times[i], false);
      if(shift >= 0)
        {
         close_B[i] = iClose(bench, tf, shift);
        }
      else
        {
         close_B[i] = (i > 0) ? close_B[i-1] : close_A[i];
        }
     }

// Calculate stationary log returns
   double ret_A[], ret_B[];
   g_stats.ComputeReturns(close_A, ret_A);
   g_stats.ComputeReturns(close_B, ret_B);

// Calculate Beta
   out_beta = g_stats.CalculateBeta(ret_A, ret_B);

// Calculate cumulative returns for Alpha
   int n = ArraySize(close_A);
   double a_tot = (close_A[n-1] - close_A[0]) / close_A[0];
   double b_tot = (close_B[n-1] - close_B[0]) / close_B[0];

// Calculate Alpha
   out_alpha = g_stats.CalculateAlpha(a_tot, b_tot, out_beta);

   return true;
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
//| RenderDashboard                                                  |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating || g_symbols_total <= 0)
      return;

   g_updating = true;

   int col_w_sym = 104;
   int col_w_val = 80;
   int row_h     = 22;

//--- 1. Render Table Header
   int header_y = InpTableY;
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   CreateButton(g_prefix + "H_Sym", "Symbol (" + tf_name + ")", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_Alpha", "Alpha (" + (string)InpLookback + ")", InpTableX + col_w_sym + 2, header_y, col_w_val, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_Beta", "Beta (" + (string)InpLookback + ")", InpTableX + col_w_sym + col_w_val + 4, header_y, col_w_val, row_h, clrDarkSlateGray, clrWhite);

//--- 2. Loop and Calculate each asset row
   for(int r = 0; r < g_symbols_total; r++)
     {
      string sym = g_symbols[r];
      int row_y = InpTableY + row_h + 2 + (r * (row_h + 2));

      // Symbol Button (Clickable chart switcher)
      CreateButton(g_prefix + "_SymBtn_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

      double alpha = EMPTY_VALUE;
      double beta  = EMPTY_VALUE;

      // Calculate single-point Alpha/Beta for the current bar in micro-seconds
      bool calculated = GetAlphaBeta(sym, InpTimeframe, InpLookback, alpha, beta);

      // Render Alpha and Beta cells with precise styling
      RenderAlphaCell(sym, alpha, calculated, InpTableX + col_w_sym + 2, row_y, col_w_val, row_h);
      RenderBetaCell(sym, beta, calculated, InpTableX + col_w_sym + col_w_val + 4, row_y, col_w_val, row_h);
     }

   ChartRedraw();
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| RenderAlphaCell                                                  |
//+------------------------------------------------------------------+
void RenderAlphaCell(string symbol, double val, bool calculated, int x, int y, int w, int h)
  {
   string name = g_prefix + "_" + symbol + "_Alpha";
   string text = "";
   color  bg_color = clrWhite;
   color  text_color = clrBlack;

   if(!calculated || val == EMPTY_VALUE)
     {
      text = "Sync...";
      bg_color = clrWhite;
      text_color = clrSilver;
     }
   else
     {
      text = DoubleToString(val, 4);

      if(val > 0.0001)
        {
         bg_color = clrLimeGreen; // Positive Alpha (Excess returns)
         text_color = clrBlack;
        }
      else
         if(val < -0.0001)
           {
            bg_color = clrCrimson;   // Negative Alpha (Underperformance)
            text_color = clrWhite;
           }
         else
           {
            bg_color = clrWhite;     // Symmetrical/Neutral
            text_color = clrDarkGray;
           }
     }
   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderBetaCell                                                   |
//+------------------------------------------------------------------+
void RenderBetaCell(string symbol, double val, bool calculated, int x, int y, int w, int h)
  {
   string name = g_prefix + "_" + symbol + "_Beta";
   string text = "";
   color  bg_color = clrWhite;
   color  text_color = clrBlack;

   if(!calculated || val == EMPTY_VALUE)
     {
      text = "Sync...";
      bg_color = clrWhite;
      text_color = clrSilver;
     }
   else
     {
      text = DoubleToString(val, 2);

      if(val > 1.20)
        {
         bg_color = clrOrangeRed;    // High Beta (Aggressive sensitivity)
         text_color = clrWhite;
        }
      else
         if(val < 0.80)
           {
            bg_color = clrLightSkyBlue; // Low Beta (Defensive/uncorrelated)
            text_color = clrBlack;
           }
         else
           {
            bg_color = clrGold;         // Neutral Beta (Market matching)
            text_color = clrBlack;
           }
     }
   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_updating = false;
   g_last_update_ms = 0;
   g_prefix = StringFormat("ABD_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   g_stats = new CMathStatisticsCalculator();
   if(CheckPointer(g_stats) == POINTER_INVALID)
     {
      return INIT_FAILED;
     }

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

   if(CheckPointer(g_stats) == POINTER_DYNAMIC)
     {
      delete g_stats;
     }
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
//| IsForexPair                                                      |
//+------------------------------------------------------------------+
bool IsForexPair(string sym)
  {
   if(sym == InpBenchmark || sym == InpForexBench)
      return false;

   if(StringFind(sym, "USD") != -1 || StringFind(sym, "EUR") != -1 ||
      StringFind(sym, "GBP") != -1 || StringFind(sym, "JPY") != -1 ||
      StringFind(sym, "CHF") != -1 || StringFind(sym, "AUD") != -1 ||
      StringFind(sym, "CAD") != -1 || StringFind(sym, "NZD") != -1 ||
      StringFind(sym, "XAU") != -1 || StringFind(sym, "XAG") != -1)
     {
      if(StringFind(sym, "XTI") != -1)
         return false;
      if(StringFind(sym, "UKO") != -1)
         return false;
      if(StringFind(sym, "USO") != -1)
         return false;
      if(StringFind(sym, "BTC") != -1)
         return false;
      if(StringFind(sym, "ETH") != -1)
         return false;
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
