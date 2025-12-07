//+------------------------------------------------------------------+
//|                                                    ALMA_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.10" // Optimized for incremental calculation
#property description "Professional Arnaud Legoux Moving Average (ALMA) with selectable"
#property description "price source, including standard and Heikin Ashi candles."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ALMA line
#property indicator_label1  "ALMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\ALMA_Calculator.mqh>

//--- Input Parameters ---
input int                       InpAlmaPeriod   = 9;       // Window size (period)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Applied price
input double                    InpAlmaOffset   = 0.85;    // Offset (0 to 1)
input double                    InpAlmaSigma    = 6.0;     // Sigma (smoothness)

//--- Indicator Buffers ---
double    BufferALMA[];

//--- Global calculator object (as a base class pointer) ---
CALMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffer and set as non-timeseries
   SetIndexBuffer(0, BufferALMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferALMA, false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CALMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ALMA HA(%d, %.2f, %.1f)", InpAlmaPeriod, InpAlmaOffset, InpAlmaSigma));
     }
   else // Standard price source selected
     {
      g_calculator = new CALMACalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ALMA(%d, %.2f, %.1f)", InpAlmaPeriod, InpAlmaOffset, InpAlmaSigma));
     }

//--- Check if creation was successful and initialize the calculator
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAlmaPeriod, InpAlmaOffset, InpAlmaSigma))
     {
      Print("Failed to create or initialize ALMA Calculator object.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_calculator.GetPeriod() - 1);

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
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferALMA);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
