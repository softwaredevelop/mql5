//+------------------------------------------------------------------+
//|                                             PairsTrading_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with fixed window scale and 5-zone thermal histogram
#property description "Universal Dynamic Cointegration (Z-Score) Monitor."
#property description "Default: Brent (UKOIL) vs WTI (USOIL) relative value trader."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- FIXED: Standardized window limits to prevent single-spike scale squishing!
#property indicator_minimum -3.5
#property indicator_maximum 3.5

//--- Institutional Levels Configuration (Perfect alignment under fixed scale)
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5
#property indicator_level4 -1.5
#property indicator_level5 -2.0
#property indicator_level6 -2.5

#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Color Histogram (5-Zone Thermal Palette)
#property indicator_label1  "Spread Z-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// 5-Color Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bull Flow         (Coral - warning)
// 2: Bull Extreme      (OrangeRed - Sell Spread zone)
// 3: Bear Flow         (LightSkyBlue - warning)
// 4: Bear Extreme      (DeepSkyBlue - Buy Spread zone)
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\PairsTrading_Calculator.mqh>

//--- Input Parameters
input string            InpSymbolA      = "UKOIL";  // Symbol A (Brent Proxy, e.g. UKOIL or BRENT)
input string            InpSymbolB      = "USOIL";  // Symbol B (WTI Proxy, e.g. USOIL or WTI)
input int               InpLookback     = 120;      // Rolling OLS Regression Window (Bars)

//--- Buffers
double ExtZScoreBuffer[];
double ExtColorsBuffer[];

//--- Aligned price arrays
double g_sync_close_A[];
double g_sync_close_B[];

//--- Global Engine
CPairsTradingCalculator *g_calc;
bool                     g_data_synced = false;

//+------------------------------------------------------------------+
//| EnsureDataReady (Multi-symbol history sync helper)               |
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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_synced = false;

   SetIndexBuffer(0, ExtZScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtZScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

// Configure shortname dynamically
   string short_name = StringFormat("PairsTrade Pro(%s vs %s, %d)", InpSymbolA, InpSymbolB, InpLookback);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CPairsTradingCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpLookback))
     {
      Print("Error: Failed to initialize PairsTrading Calculator.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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
   int required_bars = InpLookback + 10;

//--- Ensure both symbol histories are fully loaded in the terminal
   if(!EnsureDataReady(InpSymbolA, _Period, required_bars) ||
      !EnsureDataReady(InpSymbolB, _Period, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- 1. Advanced Bar-Time Synchronization & Alignment Loop (O(1) incremental)
   ArrayResize(g_sync_close_A, rates_total);
   ArrayResize(g_sync_close_B, rates_total);

   int loop_start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start < 0)
      loop_start = 0;

   for(int i = loop_start; i < rates_total; i++)
     {
      // Sync Symbol A Price
      int shift_A = iBarShift(InpSymbolA, _Period, time[i], false);
      if(shift_A >= 0)
         g_sync_close_A[i] = iClose(InpSymbolA, _Period, shift_A);
      else
         g_sync_close_A[i] = (i > 0) ? g_sync_close_A[i-1] : close[i];

      // Sync Symbol B Price
      int shift_B = iBarShift(InpSymbolB, _Period, time[i], false);
      if(shift_B >= 0)
         g_sync_close_B[i] = iClose(InpSymbolB, _Period, shift_B);
      else
         g_sync_close_B[i] = (i > 0) ? g_sync_close_B[i-1] : close[i];
     }

//--- 2. Calculate the rolling OLS Cointegration Z-Score
   int calc_start = (prev_calculated == 0) ? InpLookback : prev_calculated - 1;
   if(calc_start < InpLookback)
      calc_start = InpLookback;

   for(int i = calc_start; i < rates_total; i++)
     {
      double z = g_calc.CalculateZScore(rates_total, i, g_sync_close_A, g_sync_close_B);
      ExtZScoreBuffer[i] = z;

      //--- 3. 5-Zone Thermal Color Mapping
      if(z >= 2.0)
         ExtColorsBuffer[i] = 2.0; // Index 2: OrangeRed (Sell Spread - Short A, Long B)
      else
         if(z >= 1.5)
            ExtColorsBuffer[i] = 1.0; // Index 1: Coral (Sell Warning)
         else
            if(z <= -2.0)
               ExtColorsBuffer[i] = 4.0; // Index 4: DeepSkyBlue (Buy Spread - Long A, Short B)
            else
               if(z <= -1.5)
                  ExtColorsBuffer[i] = 3.0; // Index 3: LightSkyBlue (Buy Warning)
               else
                  ExtColorsBuffer[i] = 0.0; // Index 0: Gray (Neutral Noise)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
