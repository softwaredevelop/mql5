//+------------------------------------------------------------------+
//|                                    Bollinger_Bands_Fibonacci.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Bollinger Bands with deviations based on Fibonacci Ratios."
#property description "Includes a selectable price source with Heikin Ashi options."

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

#include <MyIncludes\Bollinger_Bands_Fibonacci_Calculator.mqh>

//--- Plot 1: Upper Band 3
#property indicator_label1  "Upper Band 3"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_DOT
#property indicator_width1  1
//--- Plot 2: Upper Band 2
#property indicator_label2  "Upper Band 2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1
//--- Plot 3: Upper Band 1
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDimGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
//--- Plot 4: Centerline
#property indicator_label4  "Centerline"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrangeRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
//--- Plot 5: Lower Band 1
#property indicator_label5  "Lower Band 1"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDimGray
#property indicator_style5  STYLE_DOT
#property indicator_width5  1
//--- Plot 6: Lower Band 2
#property indicator_label6  "Lower Band 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrGray
#property indicator_style6  STYLE_DOT
#property indicator_width6  1
//--- Plot 7: Lower Band 3
#property indicator_label7  "Lower Band 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrSilver
#property indicator_style7  STYLE_DOT
#property indicator_width7  1

//--- Input Parameters ---
input int                      InpPeriod    = 20;
input ENUM_MA_METHOD           InpMethodMA  = MODE_SMA;
input group "Fibonacci Ratios"
input double                   InpFibRatio1 = 1.618;
input double                   InpFibRatio2 = 2.618;
input double                   InpFibRatio3 = 4.236;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double BuffUpper3[], BuffUpper2[], BuffUpper1[], BuffCenter[], BuffLower1[], BuffLower2[], BuffLower3[];

//--- Global calculator object ---
CBollingerBandsFibonacciCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BuffUpper3, INDICATOR_DATA);
   SetIndexBuffer(1, BuffUpper2, INDICATOR_DATA);
   SetIndexBuffer(2, BuffUpper1, INDICATOR_DATA);
   SetIndexBuffer(3, BuffCenter, INDICATOR_DATA);
   SetIndexBuffer(4, BuffLower1, INDICATOR_DATA);
   SetIndexBuffer(5, BuffLower2, INDICATOR_DATA);
   SetIndexBuffer(6, BuffLower3, INDICATOR_DATA);

   ArraySetAsSeries(BuffUpper3, false);
   ArraySetAsSeries(BuffUpper2, false);
   ArraySetAsSeries(BuffUpper1, false);
   ArraySetAsSeries(BuffCenter, false);
   ArraySetAsSeries(BuffLower1, false);
   ArraySetAsSeries(BuffLower2, false);
   ArraySetAsSeries(BuffLower3, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBollingerBandsFibonacciCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB Fibo HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CBollingerBandsFibonacciCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB Fibo(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpFibRatio1, InpFibRatio2, InpFibRatio3, InpMethodMA))
     {
      Print("Failed to initialize Bollinger Bands Fibonacci Calculator.");
      return(INIT_FAILED);
     }

   for(int i=0; i<7; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod - 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      ENUM_APPLIED_PRICE price_type;
      if(InpSourcePrice <= PRICE_HA_CLOSE)
         price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
      else
         price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

      g_calculator.Calculate(rates_total, price_type, open, high, low, close,
                             BuffCenter, BuffUpper1, BuffLower1, BuffUpper2, BuffLower2, BuffUpper3, BuffLower3);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
