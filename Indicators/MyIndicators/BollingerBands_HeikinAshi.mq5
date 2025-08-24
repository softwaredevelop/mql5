//+------------------------------------------------------------------+
//|                                     BollingerBands_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Bollinger Bands on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "HA_Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Band
#property indicator_label2  "HA_Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Middle Band (Basis)
#property indicator_label3  "HA_Basis"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE,
   HA_PRICE_OPEN,
   HA_PRICE_HIGH,
   HA_PRICE_LOW
  };

//--- Input Parameters ---
input int                  InpBBPeriod     = 20;
input double               InpBBDeviation  = 2.0;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Objects and Variables ---
int                       g_ExtBBPeriod;
double                    g_ExtBBDeviation;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtBBPeriod    = (InpBBPeriod < 1) ? 1 : InpBBPeriod;
   g_ExtBBDeviation = (InpBBDeviation <= 0) ? 2.0 : InpBBDeviation;

   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtBBPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_BB(%d, %.1f)", g_ExtBBPeriod, g_ExtBBDeviation));

   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Bollinger Bands on Heikin Ashi calculation function.             |
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
   if(rates_total < g_ExtBBPeriod)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Prepare the Heikin Ashi source price array
   double ha_price_source[];
   ArrayResize(ha_price_source, rates_total);
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ha_open);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ha_high);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ha_low);
         break;
      default:
         ArrayCopy(ha_price_source, ha_close);
         break;
     }

//--- STEP 3: Main calculation loop on HA data
   double sma_sum = 0;
   for(int i = 0; i < rates_total; i++)
     {
      sma_sum += ha_price_source[i];

      if(i >= g_ExtBBPeriod)
        {
         sma_sum -= ha_price_source[i - g_ExtBBPeriod];
        }

      if(i >= g_ExtBBPeriod - 1)
        {
         BufferMiddle[i] = sma_sum / g_ExtBBPeriod;

         double deviation_sum_sq = 0;
         for(int j = 0; j < g_ExtBBPeriod; j++)
           {
            double diff = ha_price_source[i - j] - BufferMiddle[i];
            deviation_sum_sq += diff * diff;
           }
         double std_dev = MathSqrt(deviation_sum_sq / g_ExtBBPeriod);

         double dev_offset = g_ExtBBDeviation * std_dev;
         BufferUpper[i] = BufferMiddle[i] + dev_offset;
         BufferLower[i] = BufferMiddle[i] - dev_offset;
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
