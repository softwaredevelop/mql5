//+------------------------------------------------------------------+
//|                                                MAMA_FAMA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00"
#property description "Definition-true MESA Adaptive Moving Average (MAMA) and FAMA by John Ehlers."
#property description "Supports Standard and Heikin Ashi price sources."

#property indicator_chart_window
#property indicator_buffers 2 // MAMA and FAMA
#property indicator_plots   2

//--- Include the calculator engine ---
#include <MyIncludes\MAMA_FAMA_Calculator.mqh>

//--- Plot 1: MAMA Line
#property indicator_label1  "MAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: FAMA Line
#property indicator_label2  "FAMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

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
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Source Price
input double                    InpFastLimit   = 0.5;         // Fast Limit
input double                    InpSlowLimit   = 0.05;        // Slow Limit

//--- Indicator Buffers ---
double    BufferMAMA[];
double    BufferFAMA[];

//--- Global calculator object (as a base class pointer) ---
CMAMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMAMA, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA, false);
   ArraySetAsSeries(BufferFAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 10);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 10);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMAMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA/FAMA HA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));
     }
   else
     {
      g_calculator = new CMAMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA/FAMA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to initialize MAMA Calculator.");
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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMAMA, BufferFAMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
