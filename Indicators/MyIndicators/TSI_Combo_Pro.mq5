//+------------------------------------------------------------------+
//|                                                TSI_Combo_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "True Strength Index (TSI) - Combined View."
#property description "Displays Main Line, Signal Line, and Histogram together."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Histogram (Background)
#property indicator_label1  "Oscillator"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: TSI Line
#property indicator_label2  "TSI"
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

#property indicator_level1 -50.0
#property indicator_level2 -37.5
#property indicator_level3 -25.0
#property indicator_level4  25.0
#property indicator_level5  37.5
#property indicator_level6  50.0
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
double    BufferOsc[];
double    BufferTSI[];
double    BufferSignal[];

//--- Global calculator object ---
CTSICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOsc,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferOsc,    false);
   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

// Factory Logic
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CTSICalculator_HA();
   else
      g_calculator = new CTSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpSlowPeriod, InpSlowMAType, InpFastPeriod, InpFastMAType, InpSignalPeriod, InpSignalMAType))
     {
      Print("Init Failed.");
      return(INIT_FAILED);
     }

   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI Combo%s(%d,%d,%d)", type, InpSlowPeriod, InpFastPeriod, InpSignalPeriod));

   int draw_begin = InpSlowPeriod + InpFastPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin + InpSignalPeriod);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

// Pass ALL buffers (Main, Signal, Osc)
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferTSI, BufferSignal, BufferOsc);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
