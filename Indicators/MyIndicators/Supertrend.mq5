//+------------------------------------------------------------------+
//|                                                  Supertrend.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for stability and robust logic
#property description "Supertrend Indicator for trend identification"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 6 // Supertrend, Color, ATR, Upper, Lower, Trend
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
double    BufferTrend[];

//--- Global Variables ---
int       g_ExtAtrPeriod;
double    g_ExtFactor;
int       g_handle_atr;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtAtrPeriod = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   g_ExtFactor    = (InpFactor <= 0) ? 3.0 : InpFactor;

   SetIndexBuffer(0, BufferSupertrend, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferATR,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferTrend,      INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferSupertrend, false);
   ArraySetAsSeries(BufferColor,      false);
   ArraySetAsSeries(BufferATR,        false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);
   ArraySetAsSeries(BufferTrend,      false);

   g_handle_atr = iATR(_Symbol, _Period, g_ExtAtrPeriod);
   if(g_handle_atr == INVALID_HANDLE)
     {
      Print("Error creating iATR handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Supertrend(%d, %.1f)", g_ExtAtrPeriod, g_ExtFactor));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release the indicator handle
   IndicatorRelease(g_handle_atr);
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
   if(rates_total <= g_ExtAtrPeriod)
      return(0);

//--- STEP 1: Get ATR values
   if(CopyBuffer(g_handle_atr, 0, 0, rates_total, BufferATR) < rates_total)
     {
      Print("Error copying iATR buffer data.");
     }

//--- STEP 2: Main calculation loop with robust initialization
   for(int i = 1; i < rates_total; i++)
     {
      double hl2 = (high[i] + low[i]) / 2.0;
      double atr_val = g_ExtFactor * BufferATR[i];

      //--- Calculate basic upper and lower bands
      double upper_basic = hl2 + atr_val;
      double lower_basic = hl2 - atr_val;

      //--- Final upper band (stair-step logic)
      if(upper_basic < BufferUpperBand[i-1] || close[i-1] > BufferUpperBand[i-1])
         BufferUpperBand[i] = upper_basic;
      else
         BufferUpperBand[i] = BufferUpperBand[i-1];

      //--- Final lower band (stair-step logic)
      if(lower_basic > BufferLowerBand[i-1] || close[i-1] < BufferLowerBand[i-1])
         BufferLowerBand[i] = lower_basic;
      else
         BufferLowerBand[i] = BufferLowerBand[i-1];

      //--- Determine trend direction
      if(i == g_ExtAtrPeriod) // Explicit trend initialization
        {
         if(close[i] > hl2)
            BufferTrend[i] = 1;
         else
            BufferTrend[i] = -1;
        }
      else
         if(i > g_ExtAtrPeriod)  // Subsequent points
           {
            if(BufferTrend[i-1] == 1 && close[i] < BufferLowerBand[i])
               BufferTrend[i] = -1; // Trend changed to down
            else
               if(BufferTrend[i-1] == -1 && close[i] > BufferUpperBand[i])
                  BufferTrend[i] = 1;  // Trend changed to up
               else
                  BufferTrend[i] = BufferTrend[i-1]; // Trend continues
           }

      //--- Set the final Supertrend value and color, and connect lines on change
      if(BufferTrend[i] == 1) // Uptrend
        {
         BufferSupertrend[i] = BufferLowerBand[i];
         BufferColor[i] = 0;
         if(BufferTrend[i-1] == -1)
            BufferSupertrend[i-1] = BufferLowerBand[i];
        }
      else // Downtrend
        {
         BufferSupertrend[i] = BufferUpperBand[i];
         BufferColor[i] = 1;
         if(BufferTrend[i-1] == 1)
            BufferSupertrend[i-1] = BufferUpperBand[i];
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
