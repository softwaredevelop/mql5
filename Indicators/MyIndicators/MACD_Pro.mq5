//+------------------------------------------------------------------+
//|                                                     MACD_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "9.00"
#property description "Professional MACD with selectable MA types and price source"
#property description "(Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 3 // Histogram, MACD Line, Signal Line
#property indicator_plots   3

//--- Plot 1: MACD Histogram
#property indicator_label1  "Histogram"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1

//--- Plot 2: MACD Line
#property indicator_label2  "MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Include the calculator engine ---
#include <MyIncludes\MACD_Calculator.mqh>

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
input int                       InpFastPeriod   = 12;
input int                       InpSlowPeriod   = 26;
input int                       InpSignalPeriod = 9;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input ENUM_MA_METHOD            InpSourceMAType = MODE_EMA; // MA Type for Fast and Slow lines
input ENUM_MA_METHOD            InpSignalMAType = MODE_EMA; // MA Type for Signal line

//--- Indicator Buffers ---
double    BufferMACD_Histogram[];
double    BufferMACDLine[];
double    BufferSignalLine[];

//--- Global calculator object (as a base class pointer) ---
CMACDCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferMACD_Histogram, INDICATOR_DATA);
   SetIndexBuffer(1, BufferMACDLine,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignalLine,     INDICATOR_DATA);
   ArraySetAsSeries(BufferMACD_Histogram, false);
   ArraySetAsSeries(BufferMACDLine,       false);
   ArraySetAsSeries(BufferSignalLine,     false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CMACDCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD Pro HA(%d,%d,%d)", InpFastPeriod, InpSlowPeriod, InpSignalPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CMACDCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MACD Pro(%d,%d,%d)", InpFastPeriod, InpSlowPeriod, InpSignalPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastPeriod, InpSlowPeriod, InpSignalPeriod, InpSourceMAType, InpSignalMAType))
     {
      Print("Failed to create or initialize MACD Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   int slow_period = MathMax(InpFastPeriod, InpSlowPeriod);
   int macd_line_draw_begin = slow_period - 1;
   int signal_draw_begin = slow_period + InpSignalPeriod - 2;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, signal_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, macd_line_draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, signal_draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Ensure the calculator object is valid
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Convert our custom enum to the standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate the entire calculation to our calculator object
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferMACDLine, BufferSignalLine, BufferMACD_Histogram);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
