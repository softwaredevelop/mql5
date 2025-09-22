//+------------------------------------------------------------------+
//|                                     Holt_Channel_HeikinAshi.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Holt's Forecast Channel on Heikin Ashi data."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#include <MyIncludes\Holt_Calculator.mqh>

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Channel (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Channel (HA)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Center Line (Holt MA)
#property indicator_label3  "Center Line (HA)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumSeaGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Input Parameters ---
input int    InpPeriod         = 20;
input double InpAlpha          = 0.1;
input double InpBeta           = 0.05;
input int    InpForecastPeriod = 5;

//--- Indicator Buffers ---
double    BufferUpperBand[];
double    BufferLowerBand[];
double    BufferCenterLine[];

//--- Global calculator object ---
CHoltMACalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferUpperBand,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLowerBand,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferCenterLine, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);
   ArraySetAsSeries(BufferCenterLine, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Channel HA(%d, %d)", InpPeriod, InpForecastPeriod));

   g_calculator = new CHoltMACalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta))
     {
      Print("Failed to initialize Holt MA HA Calculator.");
      return(INIT_FAILED);
     }
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
      double trend_buffer[], level_buffer[];
      g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferCenterLine, trend_buffer, level_buffer);

      int forecast_period = (InpForecastPeriod < 1) ? 1 : InpForecastPeriod;

      for(int i = 2; i < rates_total; i++)
        {
         BufferUpperBand[i] = level_buffer[i] + forecast_period * trend_buffer[i];
         BufferLowerBand[i] = level_buffer[i] - forecast_period * trend_buffer[i];
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
