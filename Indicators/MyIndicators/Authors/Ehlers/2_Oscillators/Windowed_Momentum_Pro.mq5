//+------------------------------------------------------------------+
//|                                       Windowed_Momentum_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Ehlers' Windowed FIR filter applied to Momentum (Close-Open)."

#property indicator_separate_window // THIS IS THE KEY CHANGE
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "W-Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_level1 0.0
#property indicator_levelstyle STYLE_SOLID
#property indicator_levelcolor clrGray

#include <MyIncludes\Windowed_MA_Calculator.mqh>

enum ENUM_CANDLE_SOURCE { SOURCE_STD, SOURCE_HA };

//--- Input Parameters ---
input ENUM_WINDOW_TYPE    InpWindowType  = W_HANN;        // Windowing function type
input int                 InpPeriod      = 20;            // Averaging Period
// Note: Source Price is not needed as this indicator always uses Momentum (C-O)
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

// Initialize the calculator in MOMENTUM mode
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpWindowType, SOURCE_MOMENTUM))
     {
      Print("Failed to initialize Windowed Momentum Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("W-Mom(%d)", InpPeriod));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

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

// The price_type parameter is not used by the calculator in SOURCE_MOMENTUM mode,
// but we pass a default value for consistency.
   g_calculator.Calculate(rates_total, PRICE_CLOSE, open, high, low, close, BufferOutput);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
