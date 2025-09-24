//+------------------------------------------------------------------+
//|                                                RSI_PercentB.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10"
#property description "RSI %B. Shows the position of the RSI line relative to its Bollinger Bands."
#property description "Includes a full range of standard and Heikin Ashi price sources."

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
input group "RSI Settings"
input int                      InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Bollinger Bands Settings"
input int                InpPeriodMA     = 20;
input ENUM_MA_METHOD     InpMethodMA     = MODE_SMA;
input double             InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferPercentB[];

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
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

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodMA - 1);
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
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Step 1: Run the main calculation to get all RSI Pro components
   double rsi_buffer[], ma_buffer[], upper_band[], lower_band[];
   ArrayResize(rsi_buffer, rates_total);
   ArrayResize(ma_buffer, rates_total);
   ArrayResize(upper_band, rates_total);
   ArrayResize(lower_band, rates_total);

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close,
                          rsi_buffer, ma_buffer, upper_band, lower_band);

//--- Step 2: Calculate the final %B value
   int start_pos = InpPeriodRSI + InpPeriodMA - 1;
   for(int i = start_pos; i < rates_total; i++)
     {
      double band_width = upper_band[i] - lower_band[i];
      if(band_width != 0)
        {
         BufferPercentB[i] = (rsi_buffer[i] - lower_band[i]) / band_width;
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
