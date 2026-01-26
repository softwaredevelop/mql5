//+------------------------------------------------------------------+
//|                                          DMIStochastic_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.20" // Added fixed digits precision
#property description "Barbara Star's DMI Stochastic Oscillator. Supports Standard and Heikin Ashi sources."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_level1 10.0
#property indicator_level2 20.0
#property indicator_level3 50.0
#property indicator_level4 80.0
#property indicator_level5 90.0
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0
#property indicator_maximum 100

//--- Plot 1: DMI Stoch %K (Main line)
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: DMI Stoch %D (Signal line)
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\DMIStochastic_Calculator.mqh>

//--- Input Parameters ---
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;     // Candle source
input ENUM_DMI_OSC_TYPE  InpOscType      = OSC_PDI_MINUS_NDI;     // Oscillator Formula
input int                InpDMIPeriod    = 10;                  // DMI Period
input int                InpFastKPeriod  = 10;                  // Stochastic %K Period
input int                InpSlowKPeriod  = 3;                   // Stochastic %K Slowing
input ENUM_MA_TYPE       InpStochMethod  = SMA;                 // MA Method for %K
input int                InpSmoothPeriod = 3;                   // Stochastic %D Period (Signal)
input ENUM_MA_TYPE       InpSignalMethod = SMA;                 // MA Method for %D

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];

//--- Global calculator object ---
CDMIStochasticCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_calculator = new CDMIStochasticCalculator_HA();
     }
   else
     {
      g_calculator = new CDMIStochasticCalculator();
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpDMIPeriod, InpFastKPeriod, InpSlowKPeriod, InpSmoothPeriod, InpStochMethod, InpSignalMethod, InpOscType))
     {
      Print("Failed to create or initialize DMI Stochastic Calculator.");
      return(INIT_FAILED);
     }

   string short_name = StringFormat("DMI Stoch%s(%d,%d,%d,%d)",
                                    (InpCandleSource == CANDLE_HEIKIN_ASHI ? " HA" : ""),
                                    InpDMIPeriod, InpFastKPeriod, InpSlowKPeriod, InpSmoothPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   int draw_begin = InpDMIPeriod + InpFastKPeriod + InpSlowKPeriod + InpSmoothPeriod - 2;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

//--- Set fixed precision for oscillator (0-100 range)
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return(0);

   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
