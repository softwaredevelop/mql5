//+------------------------------------------------------------------+
//|                                           CCI_Oscillator_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00"
#property description "CCI Oscillator (Histogram of CCI vs Signal Line) with selectable"
#property description "price source (Standard and Heikin Ashi)."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "CCI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Include the calculator engine ---
#include <MyIncludes\CCI_Oscillator_Calculator.mqh>

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
input int                       InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;
input group                     "Signal Line Settings"
input int                       InpMAPeriod     = 14;
input ENUM_MA_METHOD            InpMAMethod     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object (as a base class pointer) ---
CCCI_OscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CCCI_OscillatorCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Osc HA(%d, %d)", InpCCIPeriod, InpMAPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CCCI_OscillatorCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Osc(%d, %d)", InpCCIPeriod, InpMAPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpCCIPeriod, InpMAPeriod, InpMAMethod))
     {
      Print("Failed to create or initialize CCI Oscillator Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   int draw_begin = InpCCIPeriod + InpMAPeriod - 2;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferOscillator);

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
