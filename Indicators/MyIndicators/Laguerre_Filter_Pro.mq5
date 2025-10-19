//+------------------------------------------------------------------+
//|                                           Laguerre_Filter_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.10" // Added optional FIR comparison line
#property description "John Ehlers' Laguerre Filter as a low-lag moving average."
#property description "Includes an optional FIR filter for comparison."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Laguerre Filter
#property indicator_label1  "Laguerre Filter"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: FIR Filter (for comparison)
#property indicator_label2  "FIR Filter"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
   PRICE_HA_CLOSE    = -1, PRICE_HA_OPEN     = -2, PRICE_HA_HIGH     = -3, PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5, PRICE_HA_TYPICAL  = -6, PRICE_HA_WEIGHTED = -7,
   PRICE_CLOSE_STD   = PRICE_CLOSE, PRICE_OPEN_STD    = PRICE_OPEN, PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW, PRICE_MEDIAN_STD  = PRICE_MEDIAN, PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input double                    InpGamma        = 0.5; // Laguerre filter coefficient (0 to 1)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input bool                      InpShowFIR      = false; // Show the comparative FIR filter line

//--- Indicator Buffers ---
double    BufferFilter[];
double    BufferFIR[];

//--- Global calculator object (as a base class pointer) ---
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

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma))
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
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferFilter, BufferFIR);

// Hide the FIR buffer if not enabled by the user
   if(!InpShowFIR)
     {
      for(int i = 0; i < rates_total; i++)
        {
         BufferFIR[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
