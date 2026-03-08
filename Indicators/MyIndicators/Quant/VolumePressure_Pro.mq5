//+------------------------------------------------------------------+
//|                                           VolumePressure_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volume Pressure (Tick Delta Proxy)."
#property description "Measures buying/selling pressure within the candle (-1 to +1)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Plot: Histogram
#property indicator_label1  "V_PRES"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Bear(Red), Bull(Green)
#property indicator_color1  clrRed, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\VolumePressure_Calculator.mqh>

//--- Parameters
input int      InpSmoothPeriod   = 1;   // Smoothing (1 = Raw)

//--- Buffers
double BufVal[];
double BufCol[];

//--- Object
CVolumePressureCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVal, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string name = (InpSmoothPeriod > 1) ? StringFormat("V_PRES(EMA%d)", InpSmoothPeriod) : "V_PRES(Raw)";
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// Fixed range for clear reading
   IndicatorSetDouble(INDICATOR_MINIMUM, -1.1);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.1);

   g_calc = new CVolumePressureCalculator();
   if(!g_calc.Init(InpSmoothPeriod))
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
   if(rates_total < 2)
      return 0;

// 1. Calculate
   g_calc.Calculate(rates_total, prev_calculated, high, low, close, BufVal);

// 2. Color Logic
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double val = BufVal[i];
      if(val >= 0)
         BufCol[i] = 1.0; // Lime
      else
         BufCol[i] = 0.0; // Red
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
