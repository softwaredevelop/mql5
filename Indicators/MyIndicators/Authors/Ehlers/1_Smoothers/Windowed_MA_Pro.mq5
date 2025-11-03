//+------------------------------------------------------------------+
//|                                              Windowed_MA_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Refactored to be a dedicated on-chart smoother
#property description "FIR filters with selectable Windowing functions (SMA, Triangular, Hann) applied to price."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Windowed MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Windowed_MA_Calculator.mqh>

enum ENUM_CANDLE_SOURCE { SOURCE_STD, SOURCE_HA };

//--- Input Parameters ---
input ENUM_WINDOW_TYPE    InpWindowType  = W_HANN;        // Windowing function type
input int                 InpPeriod      = 20;            // Averaging Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price type for calculation
input ENUM_CANDLE_SOURCE  InpCandleSource= SOURCE_STD;    // Candle type

//--- Indicator Buffers ---
double    BufferOutput[];

//--- Global calculator object ---
CWindowedMACalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOutput,  INDICATOR_DATA);
   ArraySetAsSeries(BufferOutput,  false);

   if(InpCandleSource == SOURCE_HA)
     {
      g_calculator = new CWindowedMACalculator_HA();
     }
   else
     {
      g_calculator = new CWindowedMACalculator();
     }

// Initialize the calculator in PRICE mode
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpWindowType, SOURCE_PRICE))
     {
      Print("Failed to initialize Windowed MA Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("W-MA(%d)", InpPeriod));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
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
   if(InpCandleSource == SOURCE_HA)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferOutput);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
