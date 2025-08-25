//+------------------------------------------------------------------+
//|                                              AMA_HeikinAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Adaptive Moving Average (AMA) on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "HA_AMA"

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW, HA_PRICE_TYPICAL, HA_PRICE_MEDIAN
  };

//--- Input Parameters ---
input int                   InpAmaPeriod    = 10;
input int                   InpFastEmaPeriod= 2;
input int                   InpSlowEmaPeriod= 30;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferAMA[];

//--- Global Objects and Variables ---
int                       g_ExtAmaPeriod, g_ExtFastEmaPeriod, g_ExtSlowEmaPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAmaPeriod     = (InpAmaPeriod < 1) ? 1 : InpAmaPeriod;
   g_ExtFastEmaPeriod = (InpFastEmaPeriod < 1) ? 1 : InpFastEmaPeriod;
   g_ExtSlowEmaPeriod = (InpSlowEmaPeriod < 1) ? 1 : InpSlowEmaPeriod;

   SetIndexBuffer(0, BufferAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferAMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAmaPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_AMA(%d,%d,%d)", g_ExtAmaPeriod, g_ExtFastEmaPeriod, g_ExtSlowEmaPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
//| AMA on Heikin Ashi calculation function.                         |
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
   if(rates_total <= g_ExtAmaPeriod)
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
   for(int i=0; i<rates_total; i++)
     {
      switch(InpAppliedPrice)
        {
         case HA_PRICE_OPEN:
            ha_price_source[i] = ha_open[i];
            break;
         case HA_PRICE_HIGH:
            ha_price_source[i] = ha_high[i];
            break;
         case HA_PRICE_LOW:
            ha_price_source[i] = ha_low[i];
            break;
         case HA_PRICE_TYPICAL:
            ha_price_source[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
            break;
         case HA_PRICE_MEDIAN:
            ha_price_source[i] = (ha_high[i] + ha_low[i]) / 2.0;
            break;
         default:
            ha_price_source[i] = ha_close[i];
            break;
        }
     }

//--- STEP 3: Main calculation loop on HA data
   double fast_sc = 2.0 / (g_ExtFastEmaPeriod + 1.0);
   double slow_sc = 2.0 / (g_ExtSlowEmaPeriod + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAmaPeriod)
        {
         BufferAMA[i] = ha_price_source[i];
         continue;
        }

      if(i > g_ExtAmaPeriod)
        {
         double direction = MathAbs(ha_price_source[i] - ha_price_source[i - g_ExtAmaPeriod]);
         double volatility = 0;
         for(int j = 0; j < g_ExtAmaPeriod; j++)
           {
            volatility += MathAbs(ha_price_source[i - j] - ha_price_source[i - j - 1]);
           }
         double er = (volatility > 0) ? direction / volatility : 0;

         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         double ssc_sq = ssc * ssc;

         BufferAMA[i] = BufferAMA[i-1] + ssc_sq * (ha_price_source[i] - BufferAMA[i-1]);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
