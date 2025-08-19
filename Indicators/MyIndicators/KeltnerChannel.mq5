//+------------------------------------------------------------------+
//|                                             KeltnerChannel.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00" // Final Consensus: iMA handle for Middle Line, manual ATR
#property description "Keltner Channels based on ATR"

#include <MovingAverages.mqh> // Only needed for manual ATR's SMA init

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 4 // Upper, Lower, Middle, and ATR
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Middle Band (Basis)
#property indicator_label3  "Basis"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Input Parameters ---
input int                InpMaPeriod     = 20;
input ENUM_MA_METHOD     InpMaMethod     = MODE_EMA;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL;
input int                InpAtrPeriod    = 10;
input double             InpMultiplier   = 2.0;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];
double    BufferATR[];

//--- Global Variables ---
int       g_ExtMaPeriod, g_ExtAtrPeriod;
double    g_ExtMultiplier;
int       g_handle_ma; // Handle for the middle line MA

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

   g_handle_ma = iMA(_Symbol, _Period, g_ExtMaPeriod, 0, InpMaMethod, InpAppliedPrice);
   if(g_handle_ma == INVALID_HANDLE)
     {
      Print("Error creating iMA handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   int draw_begin = MathMax(g_ExtMaPeriod, g_ExtAtrPeriod);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtMaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KC(%d,%d,%.1f)", g_ExtMaPeriod, g_ExtAtrPeriod, g_ExtMultiplier));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(g_handle_ma);
  }

//+------------------------------------------------------------------+
//| Keltner Channel calculation function.                            |
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

//--- STEP 1: Get Middle Line (MA) values from handle for perfect accuracy
   if(CopyBuffer(g_handle_ma, 0, 0, rates_total, BufferMiddle) < rates_total)
     {
      Print("Error copying iMA buffer data.");
     }

//--- STEP 2: Calculate True Range manually
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }

//--- STEP 3: Calculate ATR and Bands
   for(int i = 1; i < rates_total; i++)
     {
      // --- Calculate ATR (using Wilder's smoothing) ---
      if(i == g_ExtAtrPeriod) // Initialization with SMA
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
