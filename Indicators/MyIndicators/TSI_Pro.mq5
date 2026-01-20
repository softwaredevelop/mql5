//+------------------------------------------------------------------+
//|                                                       TSI_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "5.00" // Updated to use unified calculator
#property description "Professional True Strength Index (TSI) with fully customizable"
#property description "smoothing methods and selectable price source."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
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

#include <MyIncludes\TSI_Calculator.mqh>

//--- Input Parameters ---
input group                     "TSI Calculation Settings"
input int                       InpSlowPeriod   = 25;
input ENUM_MA_TYPE              InpSlowMAType   = EMA;
input int                       InpFastPeriod   = 13;
input ENUM_MA_TYPE              InpFastMAType   = EMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group                     "Signal Line Settings"
input int                       InpSignalPeriod = 13;
input ENUM_MA_TYPE              InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferTSI[];
double    BufferSignal[];

//--- Global calculator object ---
CTSICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CTSICalculator_HA();
   else
      g_calculator = new CTSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpSlowPeriod, InpSlowMAType, InpFastPeriod, InpFastMAType, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to create or initialize TSI Calculator object.");
      return(INIT_FAILED);
     }

   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI%s(%d,%d,%d)", type, InpSlowPeriod, InpFastPeriod, InpSignalPeriod));

   int tsi_draw_begin = InpSlowPeriod + InpFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, tsi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, tsi_draw_begin + InpSignalPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

// Pass dummy array for oscillator output
   double dummy_osc[];
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferTSI, BufferSignal, dummy_osc);

   return(rates_total);
  }
//+------------------------------------------------------------------+
