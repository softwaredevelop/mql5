//+------------------------------------------------------------------+
//|                                                   Supertrend.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.04" // Final stable version, logic aligned with Pine Script
#property description "Supertrend Indicator for trend identification"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 5 // Supertrend, Color, ATR, UpperBand, LowerBand
#property indicator_plots   1

//--- Plot 1: Supertrend line
#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int    InpAtrPeriod = 10;
input double InpFactor    = 3.0;

//--- Indicator Buffers ---
double    BufferSupertrend[];
double    BufferColor[];
double    BufferATR[];
double    BufferUpperBand[];
double    BufferLowerBand[];

//--- Global Variables ---
int       ExtAtrPeriod;
double    ExtFactor;
int       handle_atr;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtAtrPeriod = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   ExtFactor    = (InpFactor <= 0) ? 3.0 : InpFactor;

   SetIndexBuffer(0, BufferSupertrend, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferATR,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferSupertrend, false);
   ArraySetAsSeries(BufferColor,      false);
   ArraySetAsSeries(BufferATR,        false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);

   handle_atr = iATR(_Symbol, _Period, ExtAtrPeriod);
   if(handle_atr == INVALID_HANDLE)
      Print("Error creating iATR handle.");

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Supertrend(%d, %.1f)", ExtAtrPeriod, ExtFactor));
  }

//+------------------------------------------------------------------+
//| Supertrend calculation function.                                 |
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
   if(rates_total < ExtAtrPeriod)
      return(0);

//--- STEP 1: Get ATR values
   if(BarsCalculated(handle_atr) < rates_total)
      return(0);
   if(CopyBuffer(handle_atr, 0, 0, rates_total, BufferATR) <= 0)
      return(0);

//--- STEP 2: Main calculation loop
   for(int i = 1; i < rates_total; i++)
     {
      double hl2 = (high[i] + low[i]) / 2.0;

      double upper_basic = hl2 + (ExtFactor * BufferATR[i]);
      double lower_basic = hl2 - (ExtFactor * BufferATR[i]);

      // --- Stair-step logic
      if(upper_basic < BufferUpperBand[i-1] || close[i-1] > BufferUpperBand[i-1])
         BufferUpperBand[i] = upper_basic;
      else
         BufferUpperBand[i] = BufferUpperBand[i-1];

      if(lower_basic > BufferLowerBand[i-1] || close[i-1] < BufferLowerBand[i-1])
         BufferLowerBand[i] = lower_basic;
      else
         BufferLowerBand[i] = BufferLowerBand[i-1];

      // --- Trend direction and final Supertrend value ---
      int trend = 0;
      if(BufferSupertrend[i-1] == BufferUpperBand[i-1])
         trend = (close[i] > BufferUpperBand[i]) ? 1 : -1;
      else
         trend = (close[i] < BufferLowerBand[i]) ? -1 : 1;

      if(trend == 1) // Uptrend
        {
         BufferSupertrend[i] = BufferLowerBand[i];
         BufferColor[i] = 0; // Green
        }
      else // Downtrend
        {
         BufferSupertrend[i] = BufferUpperBand[i];
         BufferColor[i] = 1; // Red
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
