//+------------------------------------------------------------------+
//|                                                      MAMA_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.40" // Upgraded with 3-digit Alpha limits, optional line toggles, pointer safety and chronological safeguards
#property description "John Ehlers' MESA Adaptive Moving Average (MAMA) and FAMA."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MAMA
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: FAMA
#property indicator_label2  "FAMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\MAMA_Calculator.mqh>

//--- Input Parameters ---
input group                     "MAMA Settings"
input double                    InpFastLimit    = 0.5;             // Fast Limit for Alpha
input double                    InpSlowLimit    = 0.05;            // Slow Limit for Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Price Source

input group                     "Display Settings"
input bool                      InpShowMAMA     = true;            // Show MAMA Line?
input bool                      InpShowFAMA     = true;            // Show FAMA Line?

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferFAMA[];

//--- Global calculator object ---
CMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA,  false);
   ArraySetAsSeries(BufferFAMA,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMAMACalculator_HA();
   else
      g_calculator = new CMAMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to initialize MAMA Calculator.");
      return(INIT_FAILED);
     }

//--- Configure Display Mode for MAMA Line
   if(InpShowMAMA)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(0, PLOT_LABEL, "MAMA");
     }
   else
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(0, PLOT_LABEL, NULL);
     }

//--- Configure Display Mode for FAMA Line
   if(InpShowFAMA)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(1, PLOT_LABEL, "FAMA");
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA%s(%.2f,%.2f)", type, InpFastLimit, InpSlowLimit));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 50);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 50);
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
   if(rates_total < 50)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation with prev_calculated optimization
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMAMA, BufferFAMA);

//--- Hide MAMA line if not selected
   if(!InpShowMAMA)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferMAMA[i] = EMPTY_VALUE;
     }

//--- Hide FAMA line if not selected
   if(!InpShowFAMA)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferFAMA[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
