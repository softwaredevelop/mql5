//+------------------------------------------------------------------+
//|                                           Laguerre_Slope_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Optimized for incremental calculation and 5-zone state classification
#property description "Slope derivative of John Ehlers' Laguerre Filter."
#property description "Features a 5-zone symmetrical thermal color palette."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "Laguerre Slope"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- The Symmetrical Thermal Slope Palette (5-Zone Matrix)
#property indicator_color1  clrGray, clrMediumSeaGreen, clrPaleGreen, clrCrimson, clrLightCoral

#include <MyIncludes\Laguerre_Slope_Calculator.mqh>

//--- Input Parameters ---
input double                    InpGamma        = 0.5;             // Laguerre Gamma (e.g. 0.236, 0.382, 0.618)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Price Source
input double                    InpThreshold    = 0.00005;         // Slope Neutral Threshold (e.g. 0.00005)

//--- Indicator Buffers ---
double    BufferSlope[];
double    BufferSlopeColor[];

//--- Global Calculator Object ---
CLaguerreSlopeCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind buffers to index mapping
   SetIndexBuffer(0, BufferSlope,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlopeColor, INDICATOR_COLOR_INDEX);

//--- Force strict chronological alignment (false = old to new)
   ArraySetAsSeries(BufferSlope,      false);
   ArraySetAsSeries(BufferSlopeColor, false);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- Initialize physical calculator engine
   g_calculator = new CLaguerreSlopeCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to allocate Laguerre Slope Calculator memory.");
      return(INIT_FAILED);
     }

   if(!g_calculator.Init(InpGamma, SOURCE_PRICE, is_ha))
     {
      Print("Critical Error: Failed to initialize Laguerre Slope Calculator.");
      return(INIT_FAILED);
     }

//--- Shortname formatting to 3 decimal places to support Fibonacci Gamma values
   string short_name = StringFormat("Laguerre Slope%s(%.3f, %.5f)",
                                    is_ha ? " HA" : "",
                                    InpGamma,
                                    InpThreshold);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

//--- High precision display settings for visual smoothness on fractional oscillators
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
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
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Chronological safeguarding of critical calculation arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//--- Handle negative-index Heikin Ashi pricing conversions transparently
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Delegate calculation to stateful engine
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferSlope, BufferSlopeColor, InpThreshold);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
