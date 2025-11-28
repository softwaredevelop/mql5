//+------------------------------------------------------------------+
//|                                           Laguerre_Filter_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation
#property description "John Ehlers' Laguerre Filter as a low-lag moving average."
#property description "Includes an optional FIR filter for comparison."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Laguerre Filter"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "FIR Filter"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

//--- Input Parameters ---
input double                    InpGamma        = 0.5;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input bool                      InpShowFIR      = false;

//--- Indicator Buffers ---
double    BufferFilter[];
double    BufferFIR[];

//--- Global calculator object ---
CLaguerreFilterCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferFilter, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFIR,    INDICATOR_DATA);
   ArraySetAsSeries(BufferFilter, false);
   ArraySetAsSeries(BufferFIR,    false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CLaguerreFilterCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Filter HA(%.2f)", InpGamma));
     }
   else
     {
      g_calculator = new CLaguerreFilterCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Filter(%.2f)", InpGamma));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, SOURCE_PRICE))
     {
      Print("Failed to create or initialize Laguerre Filter Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 4);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated, // <--- Now used!
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFilter, BufferFIR);

//--- Hide FIR if not requested (Optimized loop)
   if(!InpShowFIR)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferFIR[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
