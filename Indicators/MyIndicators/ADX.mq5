//+------------------------------------------------------------------+
//|                                                          ADX.mq5 |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes ADXW)   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "1.00"
#property description "ADX by Welles Wilder on standard price data."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 7 // 3 for plotting, 4 for calculations
#property indicator_plots   3

//--- Plot 1: ADX line (Main trend strength)
#property indicator_label1  "ADX"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: +DI line (Positive Directional Indicator)
#property indicator_label2  "+DI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: -DI line (Negative Directional Indicator)
#property indicator_label3  "-DI"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input Parameters ---
input int InpPeriodADX = 14; // Period for ADX calculations

//--- Indicator Buffers ---
double    BufferADX[];
double    BufferPDI[];
double    BufferNDI[];
double    BufferSmoothed_PDM[];
double    BufferSmoothed_NDM[];
double    BufferSmoothed_TR[];
double    BufferDX[];

//--- Global Objects and Variables ---
int       g_ExtADXPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtADXPeriod = (InpPeriodADX < 1) ? 1 : InpPeriodADX;

   SetIndexBuffer(0, BufferADX,          INDICATOR_DATA);
   SetIndexBuffer(1, BufferPDI,          INDICATOR_DATA);
   SetIndexBuffer(2, BufferNDI,          INDICATOR_DATA);
   SetIndexBuffer(3, BufferSmoothed_PDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSmoothed_NDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSmoothed_TR,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDX,           INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferADX,          false);
   ArraySetAsSeries(BufferPDI,          false);
   ArraySetAsSeries(BufferNDI,          false);
   ArraySetAsSeries(BufferSmoothed_PDM, false);
   ArraySetAsSeries(BufferSmoothed_NDM, false);
   ArraySetAsSeries(BufferSmoothed_TR,  false);
   ArraySetAsSeries(BufferDX,           false);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtADXPeriod * 2 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtADXPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtADXPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADXW(%d)", g_ExtADXPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function.                           |
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
   if(rates_total < g_ExtADXPeriod * 2)
      return(0);

//--- STEP 1: Calculate raw +DM, -DM, and TR from standard prices
   double pDM[], nDM[], TR[];
   ArrayResize(pDM, rates_total);
   ArrayResize(nDM, rates_total);
   ArrayResize(TR, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      pDM[i] = high[i] - high[i-1];
      nDM[i] = low[i-1] - low[i];

      if(pDM[i] < 0 || pDM[i] < nDM[i])
         pDM[i] = 0;
      if(nDM[i] < 0 || nDM[i] < pDM[i])
         nDM[i] = 0;

      TR[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }

//--- STEP 2: Calculate Smoothed PDM, NDM, and TR
   for(int i = g_ExtADXPeriod; i < rates_total; i++)
     {
      if(i == g_ExtADXPeriod) // First calculation is a simple sum
        {
         double sum_pdm=0, sum_ndm=0, sum_tr=0;
         for(int j=1; j<=g_ExtADXPeriod; j++)
           {
            sum_pdm += pDM[j];
            sum_ndm += nDM[j];
            sum_tr  += TR[j];
           }
         BufferSmoothed_PDM[i] = sum_pdm;
         BufferSmoothed_NDM[i] = sum_ndm;
         BufferSmoothed_TR[i]  = sum_tr;
        }
      else // Subsequent calculations use Wilder's smoothing
        {
         BufferSmoothed_PDM[i] = BufferSmoothed_PDM[i-1] - (BufferSmoothed_PDM[i-1] / g_ExtADXPeriod) + pDM[i];
         BufferSmoothed_NDM[i] = BufferSmoothed_NDM[i-1] - (BufferSmoothed_NDM[i-1] / g_ExtADXPeriod) + nDM[i];
         BufferSmoothed_TR[i]  = BufferSmoothed_TR[i-1]  - (BufferSmoothed_TR[i-1] / g_ExtADXPeriod) + TR[i];
        }
     }

//--- STEP 3: Calculate +DI, -DI, and DX
   for(int i = g_ExtADXPeriod; i < rates_total; i++)
     {
      if(BufferSmoothed_TR[i] != 0.0)
        {
         BufferPDI[i] = (BufferSmoothed_PDM[i] / BufferSmoothed_TR[i]) * 100.0;
         BufferNDI[i] = (BufferSmoothed_NDM[i] / BufferSmoothed_TR[i]) * 100.0;
        }

      double di_sum = BufferPDI[i] + BufferNDI[i];
      if(di_sum != 0.0)
         BufferDX[i] = MathAbs(BufferPDI[i] - BufferNDI[i]) / di_sum * 100.0;
      else
         BufferDX[i] = 0.0;
     }

//--- STEP 4: Smooth DX to get the final ADX value
   for(int i = g_ExtADXPeriod * 2 - 1; i < rates_total; i++)
     {
      if(i == g_ExtADXPeriod * 2 - 1) // First ADX value is a simple average
        {
         double sum_dx = 0;
         for(int j=i-g_ExtADXPeriod+1; j<=i; j++)
            sum_dx += BufferDX[j];
         BufferADX[i] = sum_dx / g_ExtADXPeriod;
        }
      else // Subsequent ADX values are smoothed
        {
         BufferADX[i] = (BufferADX[i-1] * (g_ExtADXPeriod - 1) + BufferDX[i]) / g_ExtADXPeriod;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
