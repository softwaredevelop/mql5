//+------------------------------------------------------------------+
//|                                               SpreadCost_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.03" // Added Live Spread Fallback and Scale Guard for custom timeframes (e.g. M3)
#property description "Relative Spread Cost Indicator."
#property description "Shows Spread as a percentage of Volatility (ATR)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Levels
#property indicator_level1 10.0
#property indicator_level2 30.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Cost Histogram
#property indicator_label1  "Spread Cost %"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Color Index: 0=Cheap(MediumSeaGreen), 1=Normal(Silver), 2=Expensive(Crimson)
#property indicator_color1  clrMediumSeaGreen, clrSilver, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ATR_Calculator.mqh>

//--- Input Parameters
input int      InpATRPeriod      = 14;    // Volatility Baseline (ATR)
input double   InpCheapLevel     = 10.0;  // Cheap Threshold (%)
input double   InpExpensiveLevel = 30.0;  // Expensive Threshold (%)

//--- Buffers
double BufCost[];
double BufColors[];

//--- Calculator
CATRCalculator *g_atr;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind buffers to index mapping
   SetIndexBuffer(0, BufCost,   INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

//--- Enforce strict chronological safety (false = old to new)
   ArraySetAsSeries(BufCost,   false);
   ArraySetAsSeries(BufColors, false);

//--- Scale Guard: Fix indicator minimum to prevent separate window collapse on 0.0 values
//IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);

   string name = StringFormat("SpreadCost(ATR%d)", InpATRPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 1); // Display as 15.2 %

   g_atr = new CATRCalculator();
   if(CheckPointer(g_atr) == POINTER_INVALID || !g_atr.Init(InpATRPeriod, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_atr) != POINTER_INVALID)
      delete g_atr;
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
   if(rates_total < InpATRPeriod)
     {
      Print("SpreadCost Error: Not enough bars. Total: ", rates_total, " Required: ", InpATRPeriod);
      return 0;
     }

   if(CheckPointer(g_atr) == POINTER_INVALID)
      return 0;

//--- Force strict chronological alignment on all price and spread input arrays
   ArraySetAsSeries(time,   false);
   ArraySetAsSeries(open,   false);
   ArraySetAsSeries(high,   false);
   ArraySetAsSeries(low,    false);
   ArraySetAsSeries(close,  false);
   ArraySetAsSeries(spread, false);

//--- Query the live real-time spread as a fallback for custom timeframes (e.g. M3)
   int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

//--- DEBUG: Check spread data quality (only once per bar to avoid log spam)
   static datetime last_print = 0;
   if(time[rates_total - 1] != last_print)
     {
      double test_spread = (double)spread[rates_total - 1];
      PrintFormat("DEBUG [%s %s]: Bars=%d, Spread[Last]=%.1f, LiveSpread=%d, Point=%.5f",
                  _Symbol, EnumToString(Period()), rates_total, test_spread, current_spread, Point());
      last_print = time[rates_total - 1];
     }

//--- 1. Calculate ATR (Returns Price Value)
   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

//--- CRITICAL SAFEGUARD: Prevent fatal out-of-range crashes during history synchronization
   if(ArraySize(atr_buf) < rates_total)
     {
      return 0; // Exit safely, wait for the next tick
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpATRPeriod;
   double pt = Point();

//--- 2. Calculate Spread relative cost
   for(int i = start; i < rates_total; i++)
     {
      double current_atr_price = atr_buf[i];

      // Extract spread from array
      double sp = (double)spread[i];

      // FALLBACK LOGIC: If historical spread on the active forming bar is 0, use live spread
      if(i == rates_total - 1 && sp == 0.0 && current_spread > 0)
        {
         sp = (double)current_spread;
        }

      // Convert integer spread Points to real Price Difference
      double current_spread_price = sp * pt;

      if(current_atr_price > 1.0e-9)
        {
         // Cost Ratio Formula: (Spread Price / ATR Price) * 100.0
         double cost_pct = (current_spread_price / current_atr_price) * 100.0;

         BufCost[i] = cost_pct;

         if(cost_pct <= InpCheapLevel)
            BufColors[i] = 0.0; // Cheap (MediumSeaGreen)
         else
            if(cost_pct >= InpExpensiveLevel)
               BufColors[i] = 2.0; // Expensive (Crimson)
            else
               BufColors[i] = 1.0; // Normal (Silver)
        }
      else
        {
         BufCost[i] = 0.0;
         BufColors[i] = 1.0; // Fallback to normal
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
