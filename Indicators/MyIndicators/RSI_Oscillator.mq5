//+------------------------------------------------------------------+
//|                                               RSI_Oscillator.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.20" // Refactored to use MovingAverage_Engine
#property description "RSI Oscillator (Histogram of RSI vs Signal Line) with selectable price source."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  2
#property indicator_label1  "RSI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSI_Pro_Calculator.mqh>

//--- Input Parameters ---
input int                      InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group                    "Signal Line Settings"
input int                      InpPeriodMA     = 14;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE             InpMethodMA     = SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Internal Buffers (Must be global for incremental calculation) ---
double    BufferRSI_Internal[];
double    BufferMA_Internal[];
double    BufferUpper_Internal[]; // Dummy, not used but needed for calculator
double    BufferLower_Internal[]; // Dummy, not used but needed for calculator

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIProCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Osc HA(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }
   else
     {
      g_calculator = new CRSIProCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Osc(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }

//--- We pass a dummy deviation value (0.0) as it's not used for the oscillator
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, 0.0))
     {
      Print("Failed to initialize RSI Pro Calculator for Oscillator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodMA - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

// Free internal memory
   ArrayFree(BufferRSI_Internal);
   ArrayFree(BufferMA_Internal);
   ArrayFree(BufferUpper_Internal);
   ArrayFree(BufferLower_Internal);
  }

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

//--- Resize internal buffers
   if(ArraySize(BufferRSI_Internal) != rates_total)
     {
      ArrayResize(BufferRSI_Internal, rates_total);
      ArrayResize(BufferMA_Internal, rates_total);
      ArrayResize(BufferUpper_Internal, rates_total);
      ArrayResize(BufferLower_Internal, rates_total);
     }

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Step 1: Run the main calculation (Incremental)
//--- Passing global buffers to preserve state for recursive calculations
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferRSI_Internal, BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);

//--- Step 2: Calculate the final Oscillator value (Optimized Loop)
   int start_pos = InpPeriodRSI + InpPeriodMA - 1;
   int loop_start = MathMax(start_pos, (prev_calculated > 0 ? prev_calculated - 1 : 0));

   for(int i = loop_start; i < rates_total; i++)
     {
      BufferOscillator[i] = BufferRSI_Internal[i] - BufferMA_Internal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
