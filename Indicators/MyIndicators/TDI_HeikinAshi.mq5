//+------------------------------------------------------------------+
//|                                             TDI_HeikinAshi.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Trader's Dynamic Index (TDI) on Heikin Ashi data."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 32.0
#property indicator_level2 50.0
#property indicator_level3 68.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\TDI_Calculator.mqh>

//--- Plot Properties (labels changed to HA)
#property indicator_label1  "Price Line (HA)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label2  "Signal Line (HA)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_label3  "Base Line (HA)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
#property indicator_label4  "Upper Band (HA)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DASHDOT
#property indicator_width4  1
#property indicator_label5  "Lower Band (HA)"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_DASHDOT
#property indicator_width5  1

//--- Input Parameters ---
input int    InpRsiPeriod      = 13;
input int    InpPriceLinePeriod  = 2;
input int    InpSignalLinePeriod = 7;
input int    InpBaseLinePeriod   = 34;
input double InpBandsDeviation   = 1.618;

//--- Indicator Buffers ---
double    BufferPriceLine[], BufferSignalLine[], BufferBaseLine[], BufferUpperBand[], BufferLowerBand[];

//--- Global calculator object ---
CTDICalculator_HA *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPriceLine,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalLine, INDICATOR_DATA);
   SetIndexBuffer(2, BufferBaseLine,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_DATA);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_DATA);

   ArraySetAsSeries(BufferPriceLine,  false);
   ArraySetAsSeries(BufferSignalLine, false);
   ArraySetAsSeries(BufferBaseLine,   false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);

   g_calculator = new CTDICalculator_HA();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpRsiPeriod, InpPriceLinePeriod, InpSignalLinePeriod, InpBaseLinePeriod, InpBandsDeviation))
     {
      Print("Failed to initialize TDI HA Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpRsiPeriod + InpPriceLinePeriod + InpBaseLinePeriod;
   for(int i=0; i<5; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, draw_begin);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TDI_HA(%d)", InpRsiPeriod));

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
      //--- The price_type parameter is ignored by the HA calculator
      g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close,
                             BufferPriceLine, BufferSignalLine, BufferBaseLine, BufferUpperBand, BufferLowerBand);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
