//+------------------------------------------------------------------+
//|                                           ATR_HeikinAshi.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Average True Range on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ATR line
#property indicator_label1  "HA_ATR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int InpAtrPeriod = 14; // ATR Period

//--- Indicator Buffers ---
double    BufferHA_ATR[];

//--- Global Objects and Variables ---
int                       g_ExtAtrPeriod;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAtrPeriod = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;

   SetIndexBuffer(0, BufferHA_ATR, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_ATR, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_ATR(%d)", g_ExtAtrPeriod));

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
//| Average True Range on Heikin Ashi calculation function.          |
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
   if(rates_total <= g_ExtAtrPeriod)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Heikin Ashi True Range
   double ha_tr[];
   ArrayResize(ha_tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      double range1 = ha_high[i] - ha_low[i];
      double range2 = MathAbs(ha_high[i] - ha_close[i-1]);
      double range3 = MathAbs(ha_low[i] - ha_close[i-1]);
      ha_tr[i] = MathMax(range1, MathMax(range2, range3));
     }

//--- STEP 3: Calculate ATR (Wilder's Smoothing) on HA_TR
   for(int i = 1; i < rates_total; i++)
     {
      if(i == g_ExtAtrPeriod) // Initialization with a simple average of HA_TR
        {
         double sum_tr = 0;
         for(int j = 1; j <= g_ExtAtrPeriod; j++)
           {
            sum_tr += ha_tr[j];
           }
         BufferHA_ATR[i] = sum_tr / g_ExtAtrPeriod;
        }
      else
         if(i > g_ExtAtrPeriod) // Recursive calculation
           {
            BufferHA_ATR[i] = (BufferHA_ATR[i-1] * (g_ExtAtrPeriod - 1) + ha_tr[i]) / g_ExtAtrPeriod;
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
