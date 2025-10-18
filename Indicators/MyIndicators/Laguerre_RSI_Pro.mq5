//+------------------------------------------------------------------+
//|                                             Laguerre_RSI_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.10" // Added value clamping for strict 0-100 range
#property description "John Ehlers' Laguerre RSI with selectable price source (Standard/Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "Laguerre RSI"

//--- Scale and Level Properties (scaled to 0-100) ---
#property indicator_minimum 0   // CORRECTED: Back to standard 0
#property indicator_maximum 100 // CORRECTED: Back to standard 100
#property indicator_level1 20.0
#property indicator_level2 50.0
#property indicator_level3 80.0
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\Laguerre_RSI_Calculator.mqh>

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1, PRICE_HA_OPEN     = -2, PRICE_HA_HIGH     = -3, PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5, PRICE_HA_TYPICAL  = -6, PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE, PRICE_OPEN_STD    = PRICE_OPEN, PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW, PRICE_MEDIAN_STD  = PRICE_MEDIAN, PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input double                    InpGamma        = 0.2; // Laguerre filter coefficient (0 to 1)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferLRSI[];

//--- Global calculator object (as a base class pointer) ---
CLaguerreRSICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferLRSI, INDICATOR_DATA);
   ArraySetAsSeries(BufferLRSI, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CLaguerreRSICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre RSI HA(%.2f)", InpGamma));
     }
   else
     {
      g_calculator = new CLaguerreRSICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre RSI(%.2f)", InpGamma));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma))
     {
      Print("Failed to create or initialize Laguerre RSI Calculator object.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
//| Custom indicator calculation function.                           |
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferLRSI);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
