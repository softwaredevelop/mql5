//+------------------------------------------------------------------+
//|                                                    Holt_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.01" // Final unified architecture
#property description "Professional Holt's Linear Trend Method, displaying either the"
#property description "MA line or a full forecast channel. Supports Standard and Heikin Ashi."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Center Line (Holt MA)
#property indicator_label1  "Holt MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Upper Band
#property indicator_label2  "Upper Channel"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width1  1

//--- Plot 3: Lower Band
#property indicator_label3  "Lower Channel"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\Holt_Calculator.mqh>

//--- Enum for Display Mode ---
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_MA_ONLY,       // Display only the Holt MA line
   DISPLAY_MA_AND_CHANNEL // Display the MA and the forecast channel
  };

//--- Input Parameters ---
input group                     "Holt Model Settings"
input int                       InpPeriod      = 20;
input double                    InpAlpha       = 0.1;
input double                    InpBeta        = 0.05;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;
input group                     "Display Settings"
input ENUM_DISPLAY_MODE         InpDisplayMode = DISPLAY_MA_AND_CHANNEL;
input int                       InpForecastPeriod = 5;     // Forecast period for the channel

//--- Indicator Buffers ---
double    BufferHoltMA[];
double    BufferUpperBand[];
double    BufferLowerBand[];

//--- Global calculator object (as a base class pointer) ---
CHoltMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferHoltMA,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferUpperBand,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferLowerBand,  INDICATOR_DATA);
   ArraySetAsSeries(BufferHoltMA,     false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);

//--- Dynamically create the appropriate calculator instance
   if(InpSourcePrice <= PRICE_HA_CLOSE) // Heikin Ashi source selected
     {
      g_calculator = new CHoltMACalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Pro HA(%d)", InpPeriod));
     }
   else // Standard price source selected
     {
      g_calculator = new CHoltMACalculator_Std();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt Pro(%d)", InpPeriod));
     }

//--- Check if creation was successful and initialize
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta, InpForecastPeriod))
     {
      Print("Failed to initialize Holt MA Calculator.");
      return(INIT_FAILED);
     }

//--- Set indicator display properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 2);

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
//| Custom indicator iteration function.                             |
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
   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferHoltMA, BufferUpperBand, BufferLowerBand);

//--- Hide buffers based on display mode
   if(InpDisplayMode == DISPLAY_MA_ONLY)
     {
      for(int i = 0; i < rates_total; i++)
        {
         BufferUpperBand[i] = EMPTY_VALUE;
         BufferLowerBand[i] = EMPTY_VALUE;
        }
     }

//--- Return rates_total for a full recalculation, ensuring stability
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
