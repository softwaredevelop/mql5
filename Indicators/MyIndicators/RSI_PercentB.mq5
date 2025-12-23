//+------------------------------------------------------------------+
//|                                                RSI_PercentB.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Refactored to use MovingAverage_Engine
#property description "RSI %B. Shows the position of the RSI line relative to its Bollinger Bands."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_level2 0.5
#property indicator_level3 1.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSI_Pro_Calculator.mqh>

//--- Plot 1: %B Line
#property indicator_label1  "RSI %B"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumPurple
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input group "RSI Settings"
input int                      InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Bollinger Bands Settings"
input int                InpPeriodMA     = 20;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE       InpMethodMA     = SMA;
input double             InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferPercentB[];

//--- Internal Buffers (Must be global for incremental calculation) ---
double    BufferRSI_Internal[];
double    BufferMA_Internal[];
double    BufferUpper_Internal[];
double    BufferLower_Internal[];

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIProCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI %%B HA(%d, %d)", InpPeriodRSI, InpPeriodMA));
     }
   else
     {
      g_calculator = new CRSIProCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI %%B(%d, %d)", InpPeriodRSI, InpPeriodMA));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, InpBandsDev))
     {
      Print("Failed to initialize RSI Pro Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriodRSI + InpPeriodMA - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   ArrayFree(BufferRSI_Internal);
   ArrayFree(BufferMA_Internal);
   ArrayFree(BufferUpper_Internal);
   ArrayFree(BufferLower_Internal);
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
      return 0;

// Resize internal buffers
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

// Step 1: Run the main calculation (Incremental)
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferRSI_Internal, BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);

// Step 2: Calculate the final %B value (Optimized Loop)
   int start_pos = InpPeriodRSI + InpPeriodMA - 1;
   int loop_start = MathMax(start_pos, (prev_calculated > 0 ? prev_calculated - 1 : 0));

   for(int i = loop_start; i < rates_total; i++)
     {
      double band_width = BufferUpper_Internal[i] - BufferLower_Internal[i];

      if(band_width != 0)
        {
         BufferPercentB[i] = (BufferRSI_Internal[i] - BufferLower_Internal[i]) / band_width;
        }
      else
        {
         BufferPercentB[i] = 0.5;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
