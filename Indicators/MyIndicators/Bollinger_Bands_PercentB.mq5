//+------------------------------------------------------------------+
//|                                     Bollinger_Bands_PercentB.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Optimized for incremental calculation
#property description "Bollinger Bands %B. Shows the position of price relative to the bands."
#property description "Includes a selectable price source with Heikin Ashi options."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_level1 0.0
#property indicator_level2 0.5
#property indicator_level3 1.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>

//--- Plot 1: %B Line
#property indicator_label1  "%B"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrTeal
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int                      InpPeriod    = 20;
input double                   InpDeviation = 2.0;
input ENUM_MA_METHOD           InpMethodMA  = MODE_SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferPercentB[];
double    BufferPrice[];

//--- Internal Buffers (Must be global for incremental calculation) ---
double    BufferUpper_Internal[];
double    BufferLower_Internal[];
double    BufferMA_Internal[];
double    BufferPrice_Internal[]; // To store the price from calculator

//--- Global calculator object ---
CBollingerBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBollingerBandsCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%%B HA(%d, %.2f)", InpPeriod, InpDeviation));
     }
   else
     {
      g_calculator = new CBollingerBandsCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%%B(%d, %.2f)", InpPeriod, InpDeviation));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpDeviation, InpMethodMA))
     {
      Print("Failed to initialize Bollinger Bands Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   ArrayFree(BufferUpper_Internal);
   ArrayFree(BufferLower_Internal);
   ArrayFree(BufferMA_Internal);
   ArrayFree(BufferPrice_Internal);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Resize internal buffers
   if(ArraySize(BufferUpper_Internal) != rates_total)
     {
      ArrayResize(BufferUpper_Internal, rates_total);
      ArrayResize(BufferLower_Internal, rates_total);
      ArrayResize(BufferMA_Internal, rates_total);
     }

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- Step 1: Run the main calculation (Incremental)
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);

//--- Step 2: Get the source price array from the calculator
// This is already calculated incrementally inside the calculator
   g_calculator.GetPriceBuffer(BufferPrice_Internal);

//--- Step 3: Calculate the final %B value (Optimized Loop)
   int start_pos = InpPeriod - 1;
   int loop_start = MathMax(start_pos, (prev_calculated > 0 ? prev_calculated - 1 : 0));

   for(int i = loop_start; i < rates_total; i++)
     {
      double band_width = BufferUpper_Internal[i] - BufferLower_Internal[i];

      if(band_width != 0)
        {
         // Use the internal price buffer which matches the calculator's source
         BufferPercentB[i] = (BufferPrice_Internal[i] - BufferLower_Internal[i]) / band_width;
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
