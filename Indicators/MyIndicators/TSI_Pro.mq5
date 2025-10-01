//+------------------------------------------------------------------+
//|                                                       TSI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "Professional True Strength Index (TSI) with a signal line and"
#property description "selectable price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // TSI and Signal Line
#property indicator_plots   2

//--- Plot 1: TSI Line
#property indicator_label1  "TSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_level1 -25.0
#property indicator_level2  25.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\TSI_Calculator.mqh>

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1,
   PRICE_HA_OPEN     = -2,
   PRICE_HA_HIGH     = -3,
   PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5,
   PRICE_HA_TYPICAL  = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE,
   PRICE_OPEN_STD    = PRICE_OPEN,
   PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW,
   PRICE_MEDIAN_STD  = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input int                       InpSlowPeriod   = 25;
input int                       InpFastPeriod   = 13;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group                     "Signal Line Settings"
input int                       InpSignalPeriod = 13;
input ENUM_MA_METHOD            InpSignalMAType = MODE_EMA;

//--- Indicator Buffers ---
double    BufferTSI[];
double    BufferSignal[];

//--- Global calculator object (as a base class pointer) ---
CTSICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CTSICalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI HA(%d,%d,%d)", InpSlowPeriod, InpFastPeriod, InpSignalPeriod));
     }
   else
     {
      g_calculator = new CTSICalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI(%d,%d,%d)", InpSlowPeriod, InpFastPeriod, InpSignalPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpSlowPeriod, InpFastPeriod, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize TSI Calculator object.");
      return(INIT_FAILED);
     }

   int tsi_draw_begin = InpSlowPeriod + InpFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, tsi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, tsi_draw_begin + InpSignalPeriod - 1);
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
//| Custom indicator iteration function.                             |
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

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferTSI, BufferSignal);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
