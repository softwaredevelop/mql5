//+------------------------------------------------------------------+
//|                                   KeltnerChannel_HeikinAshi.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.01" // Corrected OnCalculate signature and SMA logic
#property description "Keltner Channels with HA middle line and Standard ATR"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4 // Upper, Lower, Middle, and ATR
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
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Enum for selecting Heikin Ashi price source for the middle line ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, // Heikin Ashi Close
   HA_PRICE_OPEN,  // Heikin Ashi Open
   HA_PRICE_HIGH,  // Heikin Ashi High
   HA_PRICE_LOW,   // Heikin Ashi Low
  };

//--- Input Parameters ---
input int                  InpMaPeriod     = 20;
input ENUM_MA_METHOD       InpMaMethod     = MODE_EMA;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE;
input int                  InpAtrPeriod    = 10;
input double               InpMultiplier   = 2.0;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];
double    BufferATR[];

//--- Global Objects and Variables ---
int                       g_ExtMaPeriod, g_ExtAtrPeriod;
double                    g_ExtMultiplier;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtMaPeriod   = (InpMaPeriod < 1) ? 1 : InpMaPeriod;
   g_ExtAtrPeriod  = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtMultiplier = (InpMultiplier <= 0) ? 2.0 : InpMultiplier;

   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);
   SetIndexBuffer(3, BufferATR,    INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);
   ArraySetAsSeries(BufferATR,    false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   int draw_begin = MathMax(g_ExtMaPeriod, g_ExtAtrPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtMaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_KC(%d,%d,%.1f)", g_ExtMaPeriod, g_ExtAtrPeriod, g_ExtMultiplier));

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
//| Keltner Channel on Heikin Ashi calculation function.             |
//+------------------------------------------------------------------+
// --- FIX: Restored the full, correct function signature ---
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
   int start_pos = MathMax(g_ExtMaPeriod, g_ExtAtrPeriod);
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

//--- STEP 2: Calculate Standard True Range manually
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }

//--- STEP 3: Prepare HA price source for the middle line
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

//--- STEP 4: Calculate ATR, Middle, Upper, and Lower bands
   double sma_sum = 0;
   for(int i = 1; i < rates_total; i++)
     {
      // --- Calculate Standard ATR (using Wilder's smoothing) ---
      if(i == g_ExtAtrPeriod) // Initialization with manual SMA
        {
         double atr_sum = 0;
         for(int j=1; j<=g_ExtAtrPeriod; j++)
            atr_sum += tr[j];
         BufferATR[i] = atr_sum / g_ExtAtrPeriod;
        }
      else
         if(i > g_ExtAtrPeriod) // Recursive calculation
           {
            BufferATR[i] = (BufferATR[i-1] * (g_ExtAtrPeriod - 1) + tr[i]) / g_ExtAtrPeriod;
           }

      // --- Calculate the middle line (MA on HA price) ---
      if(i >= g_ExtMaPeriod - 1)
        {
         switch(InpMaMethod)
           {
            case MODE_EMA:
            case MODE_SMMA:
               if(i == g_ExtMaPeriod - 1)
                 {
                  double sum = 0;
                  for(int j=0; j<g_ExtMaPeriod; j++)
                     sum += ha_price_source[i-j];
                  BufferMiddle[i] = sum / g_ExtMaPeriod;
                 }
               else
                 {
                  if(InpMaMethod == MODE_EMA)
                    {
                     double pr = 2.0 / (g_ExtMaPeriod + 1.0);
                     BufferMiddle[i] = ha_price_source[i] * pr + BufferMiddle[i-1] * (1.0 - pr);
                    }
                  else
                    {
                     BufferMiddle[i] = (BufferMiddle[i-1] * (g_ExtMaPeriod - 1) + ha_price_source[i]) / g_ExtMaPeriod;
                    }
                 }
               break;
            case MODE_LWMA:
              {
               double lwma_sum = 0;
               double weight_sum = 0;
               for(int j=0; j<g_ExtMaPeriod; j++)
                 {
                  int weight = g_ExtMaPeriod - j;
                  lwma_sum += ha_price_source[i-j] * weight;
                  weight_sum += weight;
                 }
               if(weight_sum > 0)
                  BufferMiddle[i] = lwma_sum / weight_sum;
              }
            break;
            default: // MODE_SMA
               if(i == g_ExtMaPeriod - 1) // First calculation
                 {
                  sma_sum = 0; // Re-initialize sum for the first calculation point
                  for(int j=0; j<g_ExtMaPeriod; j++)
                     sma_sum += ha_price_source[i-j];
                 }
               else // Subsequent calculations use the sliding window
                 {
                  sma_sum += ha_price_source[i];
                  sma_sum -= ha_price_source[i - g_ExtMaPeriod];
                 }
               BufferMiddle[i] = sma_sum / g_ExtMaPeriod;
               break;
           }
        }

      // --- Calculate Upper and Lower bands ---
      if(i >= start_pos)
        {
         BufferUpper[i] = BufferMiddle[i] + (BufferATR[i] * g_ExtMultiplier);
         BufferLower[i] = BufferMiddle[i] - (BufferATR[i] * g_ExtMultiplier);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
