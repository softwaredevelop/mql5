//+------------------------------------------------------------------+
//|                                             Squeeze_MTF_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volatility Squeeze (Multi-Timeframe)."
#property description "Displays HTF Squeeze status on current chart."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

// Plot 1: Momentum Histogram (HTF)
#property indicator_label1  "HTF Momentum"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Squeeze Dots (HTF)
#property indicator_label2  "HTF Squeeze"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrLime, clrRed // Green=OFF, Red=ON
#property indicator_width2  3

#include <MyIncludes\Squeeze_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_H1;    // Target Timeframe
input int               InpPeriod         = 20;           // Length
input double            InpBBMult         = 2.0;          // BB Mult
input double            InpKCMult         = 1.5;          // KC Mult
input int               InpMomPeriod      = 12;           // Momentum Period
input ENUM_APPLIED_PRICE InpPrice         = PRICE_CLOSE;

//--- Buffers
double BufMom[];
double BufSqzVal[];
double BufSqzColor[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];
// HTF Results
double h_mom[], h_val[], h_col[];

CSqueezeCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufMom, INDICATOR_DATA);
   SetIndexBuffer(1, BufSqzVal, INDICATOR_DATA);
   SetIndexBuffer(2, BufSqzColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(1, PLOT_ARROW, 159); // Dot character

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("Squeeze MTF %s", tf_name);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CSqueezeCalculator();
   if(!g_calc.Init(InpPeriod, InpBBMult, InpKCMult, InpMomPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calc)==POINTER_DYNAMIC) delete g_calc; }

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
// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriod + InpMomPeriod)
      return 0;

// Fetch block
   int count = MathMin(htf_bars, 3000);

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_open, false);
   ArraySetAsSeries(h_high, false);
   ArraySetAsSeries(h_low, false);
   ArraySetAsSeries(h_close, false);

   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_time) != count)
      return 0;
   if(CopyOpen(_Symbol, InpTimeframe, 0, count, h_open) != count)
      return 0;
   if(CopyHigh(_Symbol, InpTimeframe, 0, count, h_high) != count)
      return 0;
   if(CopyLow(_Symbol, InpTimeframe, 0, count, h_low) != count)
      return 0;
   if(CopyClose(_Symbol, InpTimeframe, 0, count, h_close) != count)
      return 0;

// 2. Calc on HTF
   if(ArraySize(h_mom) != count)
     {
      ArrayResize(h_mom, count);
      ArrayResize(h_val, count);
      ArrayResize(h_col, count);
     }

   g_calc.Calculate(count, 0, InpPrice, h_open, h_high, h_low, h_close, h_mom, h_val, h_col);

// 3. Map to Current Chart
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            BufMom[i]       = h_mom[idx_htf];
            BufSqzVal[i]    = 0.0; // Dots always on zero line
            BufSqzColor[i]  = h_col[idx_htf]; // 1.0=Red(ON), 0.0=Green(OFF)
           }
         else
           {
            BufMom[i]       = EMPTY_VALUE;
            BufSqzVal[i]    = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
