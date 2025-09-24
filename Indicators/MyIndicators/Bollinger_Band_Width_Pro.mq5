//+------------------------------------------------------------------+
//|                                     Bollinger_Band_Width_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10"
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
#property indicator_width1  2

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

//--- Custom Enum for Price Source, including Heikin Ashi
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices
   PRICE_HA_CLOSE = -1,
   PRICE_HA_OPEN = -2,
   PRICE_HA_HIGH = -3,
   PRICE_HA_LOW = -4,
   PRICE_HA_MEDIAN = -5,
   PRICE_HA_TYPICAL = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices
   PRICE_CLOSE_STD = PRICE_CLOSE,
   PRICE_OPEN_STD = PRICE_OPEN,
   PRICE_HIGH_STD = PRICE_HIGH,
   PRICE_LOW_STD = PRICE_LOW,
   PRICE_MEDIAN_STD = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD = PRICE_WEIGHTED
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

//--- Global calculator object ---
CBollingerBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
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

   IndicatorSetInteger(INDICATOR_DIGITS, 5);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   double upper_band[], lower_band[], ma_line[];
   ArrayResize(upper_band, rates_total);
   ArrayResize(lower_band, rates_total);
   ArrayResize(ma_line, rates_total);

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close,
                          ma_line, upper_band, lower_band);

   int start_pos = InpPeriod - 1;
   for(int i = start_pos; i < rates_total; i++)
     {
      if(ma_line[i] != 0)
         BufferBandWidth[i] = ((upper_band[i] - lower_band[i]) / ma_line[i]) * 100.0;
      else
         BufferBandWidth[i] = 0;
     }

//--- Initialize all overlay buffers to empty
   ArrayInitialize(BufferUpperChannel, EMPTY_VALUE);
   ArrayInitialize(BufferLowerChannel, EMPTY_VALUE);
   ArrayInitialize(BufferCenterline,   EMPTY_VALUE);

   switch(InpDisplayMode)
     {
      case MODE_BANDS_ON_WIDTH:
        {
         int bands_start_pos = start_pos + InpBandsOnWidth_Period - 1;

         for(int i = bands_start_pos; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < InpBandsOnWidth_Period; j++)
               sum += BufferBandWidth[i-j];
            BufferCenterline[i] = sum / InpBandsOnWidth_Period;
           }

         for(int i = bands_start_pos; i < rates_total; i++)
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
         for(int i = extremes_start_pos; i < rates_total; i++)
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
//+------------------------------------------------------------------+
