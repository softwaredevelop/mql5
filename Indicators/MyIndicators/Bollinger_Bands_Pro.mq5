//+------------------------------------------------------------------+
//|                                          Bollinger_Bands_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "A professional, unified Bollinger Bands indicator with a selectable"
#property description "price source, including a full range of Heikin Ashi prices."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Center Line (MA)
#property indicator_label3  "Centerline"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Custom Enum for Price Source, including Heikin Ashi
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices
   PRICE_HA_CLOSE = -1,
   PRICE_HA_OPEN = -2,
   PRICE_HA_HIGH = -3,
   PRICE_HA_LOW = -4,
   PRICE_HA_MEDIAN = -5,
   PRICE_HA_TYPICAL = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices
   PRICE_CLOSE_STD = PRICE_CLOSE,
   PRICE_OPEN_STD = PRICE_OPEN,
   PRICE_HIGH_STD = PRICE_HIGH,
   PRICE_LOW_STD = PRICE_LOW,
   PRICE_MEDIAN_STD = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD = PRICE_WEIGHTED
  };

//--- Input Parameters ---
input int                      InpPeriod    = 20;
input double                   InpDeviation = 2.0;
input ENUM_MA_METHOD           InpMethodMA  = MODE_SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferUpperBand[], BufferLowerBand[], BufferCenterLine[];

//--- Global calculator object (as a base class pointer) ---
CBollingerBandsCalculator *g_calculator;

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

//--- Dynamic Calculator Instantiation ---
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Check if it's any of the HA prices
     {
      g_calculator = new CBollingerBandsCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB Pro HA(%d, %.2f)", InpPeriod, InpDeviation));
     }
   else
     {
      g_calculator = new CBollingerBandsCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB Pro(%d, %.2f)", InpPeriod, InpDeviation));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpDeviation, InpMethodMA))
     {
      Print("Failed to initialize Bollinger Bands Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpPeriod - 1);

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
      //--- Convert our custom enum back to a standard ENUM_APPLIED_PRICE for the calculator
      ENUM_APPLIED_PRICE price_type;
      if(InpSourcePrice <= PRICE_HA_CLOSE)
         price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice); // Convert -1 to 1 (CLOSE), -2 to 2 (OPEN) etc.
      else
         price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

      g_calculator.Calculate(rates_total, price_type, open, high, low, close,
                             BufferCenterLine, BufferUpperBand, BufferLowerBand);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
