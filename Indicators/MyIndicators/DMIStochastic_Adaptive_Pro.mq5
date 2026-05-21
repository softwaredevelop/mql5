//+------------------------------------------------------------------+
//|                                  DMIStochastic_Adaptive_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Initial Release for merged logic
#property description "DMI Stochastic with Kaufman's ER Adaptive Lookback. Supports Heikin Ashi."

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
#property indicator_minimum 0.0
#property indicator_maximum 100.0

//--- Plot 1: %K (Main line)
#property indicator_label1  "%K Adaptive"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D (Signal line)
#property indicator_label2  "%D Adaptive"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\DMIStochastic_Adaptive_Calculator.mqh>

//--- Input Parameters ---
input group                     "DMI Settings"
input ENUM_CANDLE_SOURCE        InpCandleSource  = CANDLE_STANDARD;   // Candle Source (Std/HA)
input ENUM_DMI_OSC_TYPE         InpOscType       = OSC_PDI_MINUS_NDI; // Oscillator Formula
input int                       InpDMIPeriod     = 10;                // DMI Period

input group                     "Adaptive Stochastic Settings"
input int                       InpErPeriod      = 10;                // Efficiency Ratio Period
input int                       InpMinStochPeriod= 5;                 // Minimum Stochastic Period
input int                       InpMaxStochPeriod= 30;                // Maximum Stochastic Period

input group                     "Smoothing Settings"
input int                       InpSlowingPeriod = 3;                 // %K Slowing Period
input ENUM_MA_TYPE              InpSlowingMAType = SMA;               // %K MA Method
input int                       InpDPeriod       = 3;                 // %D Signal Period
input ENUM_MA_TYPE              InpDMAType       = SMA;               // %D MA Method

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];

//--- Global calculator object ---
CDMIStochasticAdaptiveCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferK, INDICATOR_DATA);
   SetIndexBuffer(1, BufferD, INDICATOR_DATA);
   ArraySetAsSeries(BufferK, false);
   ArraySetAsSeries(BufferD, false);

// Initialize the correct engine type
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
     {
      g_calculator = new CDMIStochasticAdaptiveCalculator_HA();
     }
   else
     {
      g_calculator = new CDMIStochasticAdaptiveCalculator();
     }

// Validation and object checking
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpDMIPeriod, InpErPeriod, InpMinStochPeriod, InpMaxStochPeriod, InpSlowingPeriod, InpSlowingMAType, InpDPeriod, InpDMAType, InpOscType))
     {
      Print("Failed to create or initialize DMI Adaptive Stochastic Calculator.");
      return(INIT_FAILED);
     }

// Set short name
   string short_name = StringFormat("DMI Stoch Adapt%s(%d,%d,%d-%d)",
                                    (InpCandleSource == CANDLE_HEIKIN_ASHI ? " HA" : ""),
                                    InpDMIPeriod, InpErPeriod, InpMinStochPeriod, InpMaxStochPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// Calculate correct draw limits based on delays
   int draw_begin = InpDMIPeriod + InpErPeriod + InpMaxStochPeriod + InpSlowingPeriod + InpDPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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

// Execute the calculation logic (O(1) implementation via calculator)
   g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferK, BufferD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
