//+------------------------------------------------------------------+
//|                                              VIDYA_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Variable Index Dynamic Average on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "HA_VIDYA"

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heikin Ashi Close
   HA_PRICE_OPEN,  // Heikin Ashi Open
   HA_PRICE_HIGH,  // Heikin Ashi High
   HA_PRICE_LOW,   // Heikin Ashi Low
  };

//--- Input Parameters ---
input int                  InpPeriodCMO    = 9;       // Chande Momentum Oscillator Period
input int                  InpPeriodEMA    = 12;      // EMA Period for smoothing
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE; // Heikin Ashi Applied Price

//--- Indicator Buffers ---
double    BufferHA_VIDYA[];

//--- Global Objects and Variables ---
int                       g_ExtPeriodCMO;
int                       g_ExtPeriodEMA;
CHeikinAshi_Calculator   *g_ha_calculator;

//--- Forward declarations ---
double CalculateCMO(int position, int period, const double &price_array[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriodCMO = (InpPeriodCMO < 1) ? 1 : InpPeriodCMO;
   g_ExtPeriodEMA = (InpPeriodEMA < 1) ? 1 : InpPeriodEMA;

   SetIndexBuffer(0, BufferHA_VIDYA, INDICATOR_DATA);
   ArraySetAsSeries(BufferHA_VIDYA, false);

   int draw_begin = g_ExtPeriodCMO + g_ExtPeriodEMA;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_VIDYA(%d,%d)", g_ExtPeriodCMO, g_ExtPeriodEMA));
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
//| VIDYA on Heikin Ashi calculation function.                       |
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
   int start_pos = g_ExtPeriodCMO + g_ExtPeriodEMA;
   if(rates_total <= start_pos)
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

//--- STEP 3: Main calculation loop
   double alpha = 2.0 / (g_ExtPeriodEMA + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      // --- Initialization Step with SMA ---
      if(i == start_pos)
        {
         double sum = 0;
         for(int j=0; j<g_ExtPeriodEMA; j++)
           {
            sum += ha_price_source[i-j];
           }
         BufferHA_VIDYA[i] = sum / g_ExtPeriodEMA;
         continue;
        }

      if(i > start_pos)
        {
         // --- Recursive Calculation Step ---
         double cmo = MathAbs(CalculateCMO(i, g_ExtPeriodCMO, ha_price_source));
         BufferHA_VIDYA[i] = ha_price_source[i] * alpha * cmo + BufferHA_VIDYA[i-1] * (1 - alpha * cmo);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculates Chande Momentum Oscillator (CMO) for a given position |
//+------------------------------------------------------------------+
double CalculateCMO(int position, int period, const double &price_array[])
  {
   if(position < period)
      return 0.0;

   double sum_up = 0.0;
   double sum_down = 0.0;

   for(int i = 0; i < period; i++)
     {
      double diff = price_array[position - i] - price_array[position - i - 1];
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down += (-diff);
     }

   if(sum_up + sum_down == 0.0)
      return 0.0;

   return (sum_up - sum_down) / (sum_up + sum_down);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
