//+------------------------------------------------------------------+
//|                                     Bollinger_Bands_PercentB.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
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

//--- Global calculator object ---
CBollingerBandsCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

//--- Dynamic Calculator Instantiation ---
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
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Step 1: Run the main calculation to get the band components
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

//--- Step 2: Calculate the source price array that was used by the calculator
   ArrayResize(BufferPrice, rates_total);
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      // For HA, we need to recalculate the HA prices to get the correct source
      CHeikinAshi_Calculator ha_calc;
      double ha_open[], ha_high[], ha_low[], ha_close[];
      ArrayResize(ha_open, rates_total);
      ArrayResize(ha_high, rates_total);
      ArrayResize(ha_low, rates_total);
      ArrayResize(ha_close, rates_total);
      ha_calc.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      switch(price_type)
        {
         case PRICE_CLOSE:
            ArrayCopy(BufferPrice, ha_close, 0, 0, rates_total);
            break;
         case PRICE_OPEN:
            ArrayCopy(BufferPrice, ha_open, 0, 0, rates_total);
            break;
         case PRICE_HIGH:
            ArrayCopy(BufferPrice, ha_high, 0, 0, rates_total);
            break;
         case PRICE_LOW:
            ArrayCopy(BufferPrice, ha_low, 0, 0, rates_total);
            break;
         case PRICE_MEDIAN:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (ha_high[i]+ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
            break;
        }
     }
   else
     {
      // For standard prices, we can just copy the relevant array
      switch(price_type)
        {
         case PRICE_CLOSE:
            ArrayCopy(BufferPrice, close, 0, 0, rates_total);
            break;
         case PRICE_OPEN:
            ArrayCopy(BufferPrice, open, 0, 0, rates_total);
            break;
         case PRICE_HIGH:
            ArrayCopy(BufferPrice, high, 0, 0, rates_total);
            break;
         case PRICE_LOW:
            ArrayCopy(BufferPrice, low, 0, 0, rates_total);
            break;
         case PRICE_MEDIAN:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            for(int i=0; i<rates_total; i++)
               BufferPrice[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
            break;
        }
     }

//--- Step 3: Calculate the final %B value
   for(int i = InpPeriod - 1; i < rates_total; i++)
     {
      double band_width = upper_band[i] - lower_band[i];
      if(band_width != 0)
        {
         BufferPercentB[i] = (BufferPrice[i] - lower_band[i]) / band_width;
        }
      else
        {
         BufferPercentB[i] = 0.5; // If width is zero, price is at the centerline
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
