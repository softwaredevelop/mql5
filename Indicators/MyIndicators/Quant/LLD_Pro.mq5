//+------------------------------------------------------------------+
//|                                                      LLD_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.60" // Added real-time tick-by-tick calculations
#property description "Lead-Lag Dominance Index (LLDI) with live-updating tick engines"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: Lead-Lag Dominance Index (LLDI)
#property indicator_label1  "LLDI"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrCrimson, clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 2: Optimal Lead Lag (OLL)
#property indicator_label2  "Optimal Lag"
#property indicator_type2   DRAW_NONE  // Hidden from chart scale, fully active in Data Window/Tooltips

#include <MyIncludes\LLD_Calculator.mqh>

//--- Input Parameters ---
input string            InpSecondSymbol   = "BTCUSD"; // Comparison Symbol
input int               InpWindowSize     = 50;       // Rolling Correlation Window (Bars)
input int               InpMaxLag         = 10;       // Maximum Phase Shift (Lags)

//--- Buffers ---
double    BufferLLDI[];
double    BufferColors[];
double    BufferLag[];

//--- Aligned secondary symbol close prices array
double    g_close_B[];

//--- Calculator Engine Pointer
CLeadLagDominanceCalculator *g_calculator;

//--- Global states for weekend/asynchronous loading
bool      g_data_synced = false;
string    g_obj_prefix  = "";

//+------------------------------------------------------------------+
//| EnsureDataReady (Aggressive history sync helper)                 |
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

   if(copied < required_bars)
     {
      int series_bars = (int)SeriesInfoInteger(symbol, timeframe, SERIES_BARS_COUNT);
      PrintFormat("LLD Pro: Syncing %s %s... Copied: %d/%d. Available in Terminal: %d",
                  symbol, EnumToString(timeframe), copied, required_bars, series_bars);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| UpdateStatusLabel                                                |
//| Renders an institutional colored text summary with live precision|
//+------------------------------------------------------------------+
void UpdateStatusLabel(int subwindow, double last_lldi, double last_lag)
  {
   string name = g_obj_prefix + "Status";

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, subwindow, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 15);
      ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
     }

   string dominance_text = "";
   color text_color = clrGray;

//--- Convert double values to strings first (guarantees 100% stable MT5 output)
   string str_lag = DoubleToString(MathAbs(last_lag), 0);
   string str_strength = DoubleToString(MathAbs(last_lldi), 4);

   if(last_lldi > 0.02)
     {
      dominance_text = StringFormat("REGIME: %s LEADS %s | Lead Time: %s bars | Strength: %s",
                                    InpSecondSymbol, _Symbol, str_lag, str_strength);
      text_color = clrDodgerBlue;
     }
   else
      if(last_lldi < -0.02)
        {
         dominance_text = StringFormat("REGIME: %s LEADS %s | Lead Time: %s bars | Strength: %s",
                                       _Symbol, InpSecondSymbol, str_lag, str_strength);
         text_color = clrCrimson;
        }
      else
        {
         dominance_text = StringFormat("REGIME: SYMMETRICAL / CO-DEPENDENT | Difference: %s", str_strength);
         text_color = clrGray;
        }

   ObjectSetString(0, name, OBJPROP_TEXT, dominance_text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_synced = false;
   g_obj_prefix = StringFormat("LLD_%x_", ChartID());

//--- Bind indicator buffers
   SetIndexBuffer(0, BufferLLDI, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferLag, INDICATOR_DATA);

   ArraySetAsSeries(BufferLLDI, false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferLag, false);

//--- Clean stale objects
   ObjectsDeleteAll(0, g_obj_prefix);

//--- Dynamic Engine Allocation
   g_calculator = new CLeadLagDominanceCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpWindowSize, InpMaxLag))
     {
      Print("LLD System: Failed to initialize Engine.");
      return(INIT_FAILED);
     }

//--- Check secondary symbol parameter
   if(InpSecondSymbol == "" || InpSecondSymbol == NULL)
     {
      Print("LLD System: Invalid secondary comparison symbol.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("LLDI(%s, %d, %d)", InpSecondSymbol, InpWindowSize, InpMaxLag);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

//--- Initialize 1-second timer for weekend/async chart refreshes
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_obj_prefix);

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
     }
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
//--- Ensure secondary symbol history is ready
   int required_bars = InpWindowSize + InpMaxLag + 5;
   if(!EnsureDataReady(InpSecondSymbol, _Period, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick or timer event
     }

   g_data_synced = true;

//--- 1. Bulletproof iClose & iBarShift Time Synchronization Loop
   ArrayResize(g_close_B, rates_total);

   int loop_start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start < 0)
      loop_start = 0;

   for(int i = loop_start; i < rates_total; i++)
     {
      int shift = iBarShift(InpSecondSymbol, _Period, time[i], false);
      if(shift >= 0)
        {
         g_close_B[i] = iClose(InpSecondSymbol, _Period, shift);
        }
      else
        {
         g_close_B[i] = (i > 0) ? g_close_B[i-1] : close[i];
        }
     }

//--- 2. Fix: Force incremental update on the current live bar on every single tick
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Run mathematical engine calculations
   if(!g_calculator.CalculateDominance(rates_total, start_index, close, g_close_B, BufferLLDI, BufferLag))
     {
      return 0;
     }

//--- 3. Colorize the histogram based on Dominance regime
   int start_pos = InpWindowSize + InpMaxLag + 1;
   int loop_start_color = MathMax(start_pos, prev_calculated - 1);

   for(int i = loop_start_color; i < rates_total; i++)
     {
      if(BufferLLDI[i] > 0.02)
        {
         BufferColors[i] = 0.0; // Index 0: DodgerBlue (Second Symbol leads)
        }
      else
         if(BufferLLDI[i] < -0.02)
           {
            BufferColors[i] = 1.0; // Index 1: Crimson (Chart Symbol leads)
           }
         else
           {
            BufferColors[i] = 2.0; // Index 2: Gray (Tied / Symmetrical)
           }
     }

//--- 4. Update status label with precise real-time values
   int subwindow = ChartWindowFind();
   if(subwindow >= 0 && rates_total > 0)
     {
      UpdateStatusLabel(subwindow, BufferLLDI[rates_total - 1], BufferLag[rates_total - 1]);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//| Handles weekend loading checks and force-redraws when ready      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_data_synced)
     {
      int required_bars = InpWindowSize + InpMaxLag + 5;
      if(EnsureDataReady(InpSecondSymbol, _Period, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
