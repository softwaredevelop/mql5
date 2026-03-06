//+------------------------------------------------------------------+
//|                                           Hurst_Exponent_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Single color line
#property description "Hurst Exponent - Fractal Market Analysis."
#property description "Supports Classic R/S and Robust DFA."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

// Levels
#property indicator_level1 0.5
#property indicator_level2 0.6
#property indicator_level3 0.4
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0.0
#property indicator_maximum 1.0

// Plot: Hurst Line (Single Color)
#property indicator_label1  "Hurst"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Hurst_Calculator.mqh>

//--- Input Parameters
input group             "Settings"
input int               InpPeriod      = 256;          // Period for Analysis
input ENUM_HURST_METHOD InpMethod      = METHOD_DFA;   // Calculation Method
input ENUM_APPLIED_PRICE InpPrice      = PRICE_CLOSE;

//--- Buffers
double BufHurst[];

//--- Objects
CHurstCalculator *g_calc;
double g_price[];

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufHurst, INDICATOR_DATA);

   string method_str = (InpMethod == METHOD_DFA) ? "DFA" : "R/S";
   string name = StringFormat("Hurst %s(%d)", method_str, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   g_calc = new CHurstCalculator();
   if(!g_calc.Init(InpPeriod, InpMethod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc)==POINTER_DYNAMIC)
      delete g_calc;
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
   if(rates_total < InpPeriod + 10)
      return 0;

   if(ArraySize(g_price) != rates_total)
      ArrayResize(g_price, rates_total);

   int start_copy = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i=start_copy; i<rates_total; i++)
     {
      switch(InpPrice)
        {
         case PRICE_CLOSE:
            g_price[i]=close[i];
            break;
         case PRICE_OPEN:
            g_price[i]=open[i];
            break;
         case PRICE_HIGH:
            g_price[i]=high[i];
            break;
         case PRICE_LOW:
            g_price[i]=low[i];
            break;
         case PRICE_MEDIAN:
            g_price[i]=(high[i]+low[i])/2;
            break;
         case PRICE_TYPICAL:
            g_price[i]=(high[i]+low[i]+close[i])/3;
            break;
         case PRICE_WEIGHTED:
            g_price[i]=(high[i]+low[i]+2*close[i])/4;
            break;
         default:
            g_price[i]=close[i];
            break;
        }
     }

   g_calc.Calculate(rates_total, prev_calculated, g_price, BufHurst);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
