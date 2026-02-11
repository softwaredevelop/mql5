//+------------------------------------------------------------------+
//|                                               SpreadCost_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.01" // Fixed Point conversion logic
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
// Color Index: 0=Cheap(Green), 1=Normal(Gray), 2=Expensive(Red)
#property indicator_color1  clrLime, clrGray, clrRed
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
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufCost, INDICATOR_DATA);
   SetIndexBuffer(1, BufColors, INDICATOR_COLOR_INDEX);

   string name = StringFormat("SpreadCost(ATR%d)", InpATRPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 1); // Display as 15.2 %

   g_atr = new CATRCalculator();
   if(!g_atr.Init(InpATRPeriod, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_atr) == POINTER_DYNAMIC)
      delete g_atr;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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

// DEBUG: Check spread data quality (only once per bar to avoid spam)
   static datetime last_print = 0;
   if(time[rates_total-1] != last_print)
     {
      double test_spread = (double)spread[rates_total-1];
      PrintFormat("DEBUG [%s %s]: Bars=%d, Spread[Last]=%.1f, Point=%.5f",
                  _Symbol, EnumToString(Period()), rates_total, test_spread, Point());
      last_print = time[rates_total-1];
     }

// 1. Calculate ATR (Returns Price Value, e.g. 50.5)
   double atr_buf[];
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpATRPeriod;

// Pre-fetch Point value (Processor efficiency)
   double pt = Point();

   for(int i = start; i < rates_total; i++)
     {
      double current_atr_price = atr_buf[i];

      // spread[] is in Points (Integer). Convert to Price.
      // Example: Index Spread = 20 points. Point = 0.5. Spread Value = 10.0
      double current_spread_price = (double)spread[i] * pt;

      if(current_atr_price > 0.000001)
        {
         // Formula: (Spread Value / ATR Value) * 100
         double cost_pct = (current_spread_price / current_atr_price) * 100.0;

         BufCost[i] = cost_pct;

         if(cost_pct <= InpCheapLevel)
            BufColors[i] = 0.0;
         else
            if(cost_pct >= InpExpensiveLevel)
               BufColors[i] = 2.0;
            else
               BufColors[i] = 1.0;
        }
      else
        {
         BufCost[i] = 0.0;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
