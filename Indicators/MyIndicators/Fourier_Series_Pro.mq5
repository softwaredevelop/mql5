//+------------------------------------------------------------------+
//|                                           Fourier_Series_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Optimized for incremental calculation
#property description "John Ehlers' Fourier Series Model of the Market."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Wave
#property indicator_label1  "Wave"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: ROC
#property indicator_label2  "ROC"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Fourier_Series_Calculator.mqh>

enum ENUM_PRICE_SOURCE { SOURCE_STANDARD, SOURCE_HEIKIN_ASHI };

//--- Input Parameters ---
input int               InpFundamentalPeriod = 20;    // Fundamental Period
input double            InpBandwidth         = 0.1;   // Bandwidth for filters
input bool              InpShowROC           = true;  // Show Rate of Change line
input ENUM_PRICE_SOURCE InpSource            = SOURCE_STANDARD;

//--- Indicator Buffers ---
double    BufferWave[];
double    BufferROC[];

//--- Global calculator object ---
CFourierSeriesCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWave, INDICATOR_DATA);
   SetIndexBuffer(1, BufferROC,  INDICATOR_DATA);
   ArraySetAsSeries(BufferWave, false);
   ArraySetAsSeries(BufferROC,  false);

// Hide ROC if not requested
   if(!InpShowROC)
      PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSource == SOURCE_HEIKIN_ASHI)
     {
      g_calculator = new CFourierSeriesCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fourier HA(%d)", InpFundamentalPeriod));
     }
   else
     {
      g_calculator = new CFourierSeriesCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Fourier(%d)", InpFundamentalPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFundamentalPeriod, InpBandwidth))
     {
      Print("Failed to initialize Fourier Series Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFundamentalPeriod * 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpFundamentalPeriod * 2 + 2);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   g_calculator.Calculate(rates_total, prev_calculated, PRICE_MEDIAN, open, high, low, close, BufferWave, BufferROC);

   if(!InpShowROC)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufferROC[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
