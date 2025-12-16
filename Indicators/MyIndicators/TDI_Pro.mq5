//+------------------------------------------------------------------+
//|                                                       TDI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.10" // Optimized for incremental calculation
#property description "Professional Trader's Dynamic Index (TDI) with selectable"
#property description "price source (Standard or Heikin Ashi)."

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 32.0
#property indicator_level2 50.0
#property indicator_level3 68.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\TDI_Calculator.mqh>

//--- Plot Properties ---
#property indicator_label1  "Price Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_label3  "Base Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_label4  "Upper Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1
#property indicator_label5  "Lower Band"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- Input Parameters ---
input int                       InpRsiPeriod      = 13;
input int                       InpPriceLinePeriod  = 2;
input int                       InpSignalLinePeriod = 7;
input int                       InpBaseLinePeriod   = 34;
input double                    InpBandsDeviation   = 1.618;
//--- CORRECTED: Use the correct enum member for the default value ---
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferPriceLine[], BufferSignalLine[], BufferBaseLine[], BufferUpperBand[], BufferLowerBand[];

//--- Global calculator object (as a base class pointer) ---
CTDICalculator *g_calculator;

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

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CTDICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TDI HA(%d)", InpRsiPeriod));
     }
   else
     {
      g_calculator = new CTDICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TDI(%d)", InpRsiPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpRsiPeriod, InpPriceLinePeriod, InpSignalLinePeriod, InpBaseLinePeriod, InpBandsDeviation))
     {
      Print("Failed to initialize TDI Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpRsiPeriod + InpBaseLinePeriod;
   for(int i=0; i<5; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, draw_begin);

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
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferPriceLine, BufferSignalLine, BufferBaseLine, BufferUpperBand, BufferLowerBand);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
