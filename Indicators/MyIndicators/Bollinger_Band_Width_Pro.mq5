//+------------------------------------------------------------------+
//|                                     Bollinger_Band_Width_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.20" // Optimized for incremental calculation
#property description "Professional Bollinger Band Width oscillator with selectable analysis modes."

#property indicator_separate_window
#property indicator_buffers 4 // Main Width, Upper Channel, Lower Channel, Centerline
#property indicator_plots   4

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>

//--- Plot 1: Band Width Line
#property indicator_label1  "BandWidth"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSlateBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Upper Channel Line
#property indicator_label2  "Upper Channel"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Lower Channel Line
#property indicator_label3  "Lower Channel"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Plot 4: Centerline for Bands on Width
#property indicator_label4  "Centerline"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGray
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Custom Enum for Display Mode
enum ENUM_BBW_MODE
  {
   MODE_WIDTH_ONLY,
   MODE_BANDS_ON_WIDTH,
   MODE_EXTREMES_CHANNEL
  };

//--- Input Parameters ---
input group "Base Bollinger Bands Settings"
input int                      InpPeriod    = 20;
input double                   InpDeviation = 2.0;
input ENUM_MA_METHOD           InpMethodMA  = MODE_SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD;

input group "Analysis Mode"
input ENUM_BBW_MODE      InpDisplayMode = MODE_WIDTH_ONLY;

input group "Bands on BandWidth Settings"
input int    InpBandsOnWidth_Period   = 20;
input double InpBandsOnWidth_Deviation = 2.0;

input group "Extremes Channel Settings"
input int InpExtremesLength = 125;

//--- Indicator Buffers ---
double    BufferBandWidth[];
double    BufferUpperChannel[];
double    BufferLowerChannel[];
double    BufferCenterline[];

//--- Internal Buffers (Must be global for incremental calculation) ---
double    BufferUpper_Internal[];
double    BufferLower_Internal[];
double    BufferMA_Internal[];

//--- Global calculator object ---
CBollingerBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferBandWidth,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferUpperChannel, INDICATOR_DATA);
   SetIndexBuffer(2, BufferLowerChannel, INDICATOR_DATA);
   SetIndexBuffer(3, BufferCenterline,   INDICATOR_DATA);

   ArraySetAsSeries(BufferBandWidth,    false);
   ArraySetAsSeries(BufferUpperChannel, false);
   ArraySetAsSeries(BufferLowerChannel, false);
   ArraySetAsSeries(BufferCenterline,   false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CBollingerBandsCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BBW Pro HA(%d)", InpPeriod));
     }
   else
     {
      g_calculator = new CBollingerBandsCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BBW Pro(%d)", InpPeriod));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpDeviation, InpMethodMA))
     {
      Print("Failed to initialize Bollinger Bands Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin + InpBandsOnWidth_Period);

//--- UPDATED: Use 4 digits for precision (like ATR Percent)
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   ArrayFree(BufferUpper_Internal);
   ArrayFree(BufferLower_Internal);
   ArrayFree(BufferMA_Internal);
  }

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

//--- Step 2: Calculate BandWidth (Optimized Loop)
   int start_pos = InpPeriod - 1;
   int loop_start = MathMax(start_pos, (prev_calculated > 0 ? prev_calculated - 1 : 0));

   for(int i = loop_start; i < rates_total; i++)
     {
      if(BufferMA_Internal[i] != 0)
         BufferBandWidth[i] = ((BufferUpper_Internal[i] - BufferLower_Internal[i]) / BufferMA_Internal[i]) * 100.0;
      else
         BufferBandWidth[i] = 0;
     }

//--- Step 3: Calculate Overlays (Optimized Loop)
// Initialize unused buffers on full recalc
   if(prev_calculated == 0)
     {
      ArrayInitialize(BufferUpperChannel, EMPTY_VALUE);
      ArrayInitialize(BufferLowerChannel, EMPTY_VALUE);
      ArrayInitialize(BufferCenterline,   EMPTY_VALUE);
     }

   switch(InpDisplayMode)
     {
      case MODE_BANDS_ON_WIDTH:
        {
         int bands_start_pos = start_pos + InpBandsOnWidth_Period - 1;
         int loop_start_bands = MathMax(bands_start_pos, loop_start);

         for(int i = loop_start_bands; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < InpBandsOnWidth_Period; j++)
               sum += BufferBandWidth[i-j];
            BufferCenterline[i] = sum / InpBandsOnWidth_Period;
           }

         for(int i = loop_start_bands; i < rates_total; i++)
           {
            double std_dev_val = 0, sum_sq = 0;
            for(int j = 0; j < InpBandsOnWidth_Period; j++)
               sum_sq += pow(BufferBandWidth[i-j] - BufferCenterline[i], 2);
            std_dev_val = sqrt(sum_sq / InpBandsOnWidth_Period);

            BufferUpperChannel[i] = BufferCenterline[i] + InpBandsOnWidth_Deviation * std_dev_val;
            BufferLowerChannel[i] = BufferCenterline[i] - InpBandsOnWidth_Deviation * std_dev_val;
           }
         break;
        }

      case MODE_EXTREMES_CHANNEL:
        {
         int extremes_start_pos = start_pos + InpExtremesLength - 1;
         int loop_start_extremes = MathMax(extremes_start_pos, loop_start);

         for(int i = loop_start_extremes; i < rates_total; i++)
           {
            int start = i - InpExtremesLength + 1;
            int highest_idx = ArrayMaximum(BufferBandWidth, start, InpExtremesLength);
            BufferUpperChannel[i] = BufferBandWidth[highest_idx];

            int lowest_idx = ArrayMinimum(BufferBandWidth, start, InpExtremesLength);
            BufferLowerChannel[i] = BufferBandWidth[lowest_idx];
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
