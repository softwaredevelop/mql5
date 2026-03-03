//+------------------------------------------------------------------+
//|                                         TSI_MTF_Simple_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "TSI Hist"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver

#include <MyIncludes\TSI_Calculator.mqh>

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT;
input int InpSlow = 25;
input int InpFast = 13;
input int InpSig  = 13;
// No complex enum, just standard logic inside
input ENUM_APPLIED_PRICE InpPrice = PRICE_CLOSE;

double BufHist[];
double h_o[], h_h[], h_l[], h_c[];
datetime h_t[];
double h_m[], h_s[], h_o_val[];

CTSICalculator *g_calc;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufHist, INDICATOR_DATA);
   g_calc = new CTSICalculator();
// Standard EMA
   g_calc.Init(InpSlow, EMA, InpFast, EMA, InpSig, EMA);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int r) { delete g_calc; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev, const datetime &time[], const double &o[], const double &h[], const double &l[], const double &c[], const long &v[], const long &vl[], const int &s[])
  {
   int tf_bars = iBars(_Symbol, InpTimeframe);
   if(tf_bars < InpSlow+InpFast+100)
      return 0;
   int count = MathMin(tf_bars, 3000); // Optimization

   ArraySetAsSeries(h_t, false);
   ArraySetAsSeries(h_c, false);
   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_t)!=count)
      return 0;
// Only need Close for TSI Standard
   if(CopyClose(_Symbol, InpTimeframe, 0, count, h_c)!=count)
      return 0;

   if(ArraySize(h_o_val)!=count)
     {
      ArrayResize(h_m,count);
      ArrayResize(h_s,count);
      ArrayResize(h_o_val,count);
     }

// Calc on HTF using Close
   g_calc.Calculate(count, 0, InpPrice, h_c, h_c, h_c, h_c, h_m, h_s, h_o_val);

   int start = (prev > 0) ? prev - 1 : 0;
   for(int i=start; i<rates_total; i++)
     {
      int shift = iBarShift(_Symbol, InpTimeframe, time[i], false);
      if(shift>=0)
        {
         int idx = count - 1 - shift;
         if(idx>=0 && idx<count)
            BufHist[i] = h_o_val[idx];
        }
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
