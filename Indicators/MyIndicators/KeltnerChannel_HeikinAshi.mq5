//+------------------------------------------------------------------+
//|                                    KeltnerChannel_HeikinAshi.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Keltner Channels on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MovingAverages.mqh>

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
input ENUM_HA_APPLIED_PRICE InpAppliedPrice = HA_PRICE_CLOSE; // HA price for the middle line
input int                  InpAtrPeriod    = 10;
input double               InpMultiplier   = 2.0;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];
double    BufferATR[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtMaPeriod, g_ExtAtrPeriod;
double                    g_ExtMultiplier;
int                       g_handle_atr;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

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

// ATR is always calculated on standard candles for true volatility
   g_handle_atr = iATR(_Symbol, _Period, g_ExtAtrPeriod);
   if(g_handle_atr == INVALID_HANDLE)
     {
      Print("Error creating iATR handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   int draw_begin = MathMax(g_ExtMaPeriod, g_ExtAtrPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtMaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_KC(%d,%d,%.1f)", g_ExtMaPeriod, g_ExtAtrPeriod, g_ExtMultiplier));

//--- Create the calculator instance
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
//--- Free the calculator object
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
//--- Release the indicator handle
   IndicatorRelease(g_handle_atr);
  }

//+------------------------------------------------------------------+
//| Keltner Channel on Heikin Ashi calculation function.             |
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
   int start_pos = MathMax(g_ExtMaPeriod, g_ExtAtrPeriod);
   if(rates_total <= start_pos)
      return(0);

//--- Resize intermediate buffers
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Get ATR values (from standard candles)
   if(CopyBuffer(g_handle_atr, 0, 0, rates_total, BufferATR) < rates_total)
     {
      Print("Error copying iATR buffer data.");
      // We don't return here, calculation can proceed with partial data
     }

//--- STEP 3: Select the source Heikin Ashi price array for the middle line
   double ha_price_source[];
   switch(InpAppliedPrice)
     {
      case HA_PRICE_OPEN:
         ArrayCopy(ha_price_source, ExtHaOpenBuffer);
         break;
      case HA_PRICE_HIGH:
         ArrayCopy(ha_price_source, ExtHaHighBuffer);
         break;
      case HA_PRICE_LOW:
         ArrayCopy(ha_price_source, ExtHaLowBuffer);
         break;
      default:
         ArrayCopy(ha_price_source, ExtHaCloseBuffer);
         break;
     }

//--- STEP 4: Calculate Middle, Upper, and Lower bands in a single loop
   for(int i = 1; i < rates_total; i++)
     {
      // --- Calculate the middle line (MA on HA price) ---
      if(i >= g_ExtMaPeriod - 1)
        {
         switch(InpMaMethod)
           {
            case MODE_EMA:
               if(i == g_ExtMaPeriod - 1)
                  BufferMiddle[i] = SimpleMA(i, g_ExtMaPeriod, ha_price_source);
               else
                 {
                  double pr = 2.0 / (g_ExtMaPeriod + 1.0);
                  BufferMiddle[i] = ha_price_source[i] * pr + BufferMiddle[i-1] * (1.0 - pr);
                 }
               break;
            case MODE_SMMA:
               if(i == g_ExtMaPeriod - 1)
                  BufferMiddle[i] = SimpleMA(i, g_ExtMaPeriod, ha_price_source);
               else
                  BufferMiddle[i] = (BufferMiddle[i-1] * (g_ExtMaPeriod - 1) + ha_price_source[i]) / g_ExtMaPeriod;
               break;
            case MODE_LWMA:
               BufferMiddle[i] = LinearWeightedMA(i, g_ExtMaPeriod, ha_price_source);
               break;
            default: // MODE_SMA
               BufferMiddle[i] = SimpleMA(i, g_ExtMaPeriod, ha_price_source);
               break;
           }
        }

      // --- Calculate Upper and Lower bands ---
      if(i >= start_pos)
        {
         double atr_value = BufferATR[i];
         double ma_value  = BufferMiddle[i];

         BufferUpper[i] = ma_value + (atr_value * g_ExtMultiplier);
         BufferLower[i] = ma_value - (atr_value * g_ExtMultiplier);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
