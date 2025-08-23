//+------------------------------------------------------------------+
//|                                             ADX_HeikinAshi.mq5   |
//|            Copyright 2025, xxxxxxxx (Based on MetaQuotes ADXW)   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, xxxxxxxx"
#property link        ""
#property version     "4.00" // Refactored for full recalculation and stability
#property description "ADX by Welles Wilder on Heikin Ashi data."

// --- Standard and Custom Includes ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 7 // 3 for plotting, 4 for calculations
#property indicator_plots   3

//--- Plot 1: ADX line (Main trend strength)
#property indicator_label1  "HA_ADX"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: +DI line (Positive Directional Indicator)
#property indicator_label2  "HA_+DI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: -DI line (Negative Directional Indicator)
#property indicator_label3  "HA_-DI"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input Parameters ---
input int InpPeriodADX = 14; // Period for ADX calculations

//--- Indicator Buffers ---
double    BufferHA_ADX[];
double    BufferHA_PDI[];
double    BufferHA_NDI[];
double    BufferSmoothed_PDM[];
double    BufferSmoothed_NDM[];
double    BufferSmoothed_TR[];
double    BufferDX[];

//--- Intermediate Heikin Ashi Buffers ---
double    ExtHaOpenBuffer[];
double    ExtHaHighBuffer[];
double    ExtHaLowBuffer[];
double    ExtHaCloseBuffer[];

//--- Global Objects and Variables ---
int                       g_ExtADXPeriod;
CHeikinAshi_Calculator   *g_ha_calculator; // Pointer to our Heikin Ashi calculator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store the ADX period
   g_ExtADXPeriod = (InpPeriodADX < 1) ? 1 : InpPeriodADX;

//--- Map the buffers
   SetIndexBuffer(0, BufferHA_ADX,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_PDI,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_NDI,       INDICATOR_DATA);
   SetIndexBuffer(3, BufferSmoothed_PDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSmoothed_NDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSmoothed_TR,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDX,           INDICATOR_CALCULATIONS);

//--- Set all buffers as non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_ADX,       false);
   ArraySetAsSeries(BufferHA_PDI,       false);
   ArraySetAsSeries(BufferHA_NDI,       false);
   ArraySetAsSeries(BufferSmoothed_PDM, false);
   ArraySetAsSeries(BufferSmoothed_NDM, false);
   ArraySetAsSeries(BufferSmoothed_TR,  false);
   ArraySetAsSeries(BufferDX,           false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtADXPeriod * 2 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtADXPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_ExtADXPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_ADXW(%d)", g_ExtADXPeriod));

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
//--- Free the calculator object to prevent memory leaks
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
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
//--- Check if there is enough historical data for the calculation
   if(rates_total < g_ExtADXPeriod + 1)
      return(0);

//--- Resize intermediate buffers to match the available bars
   ArrayResize(ExtHaOpenBuffer, rates_total);
   ArrayResize(ExtHaHighBuffer, rates_total);
   ArrayResize(ExtHaLowBuffer, rates_total);
   ArrayResize(ExtHaCloseBuffer, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars using our toolkit
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             ExtHaOpenBuffer, ExtHaHighBuffer, ExtHaLowBuffer, ExtHaCloseBuffer);

//--- STEP 2: Calculate raw +DM, -DM, and TR
   double pDM[], nDM[], TR[];
   ArrayResize(pDM, rates_total);
   ArrayResize(nDM, rates_total);
   ArrayResize(TR, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      double ha_high       = ExtHaHighBuffer[i];
      double prev_ha_high  = ExtHaHighBuffer[i-1];
      double ha_low        = ExtHaLowBuffer[i];
      double prev_ha_low   = ExtHaLowBuffer[i-1];
      double prev_ha_close = ExtHaCloseBuffer[i-1];

      pDM[i] = ha_high - prev_ha_high;
      nDM[i] = prev_ha_low - ha_low;

      if(pDM[i] < 0 || pDM[i] < nDM[i])
         pDM[i] = 0;
      if(nDM[i] < 0 || nDM[i] < pDM[i])
         nDM[i] = 0;

      TR[i] = MathMax(ha_high, prev_ha_close) - MathMin(ha_low, prev_ha_close);
     }

//--- STEP 3: Calculate Smoothed PDM, NDM, and TR
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

//--- STEP 4: Calculate +DI, -DI, and DX
   for(int i = g_ExtADXPeriod; i < rates_total; i++)
     {
      if(BufferSmoothed_TR[i] != 0.0)
        {
         BufferHA_PDI[i] = (BufferSmoothed_PDM[i] / BufferSmoothed_TR[i]) * 100.0;
         BufferHA_NDI[i] = (BufferSmoothed_NDM[i] / BufferSmoothed_TR[i]) * 100.0;
        }

      double di_sum = BufferHA_PDI[i] + BufferHA_NDI[i];
      if(di_sum != 0.0)
         BufferDX[i] = MathAbs(BufferHA_PDI[i] - BufferHA_NDI[i]) / di_sum * 100.0;
      else
         BufferDX[i] = 0.0;
     }

//--- STEP 5: Smooth DX to get the final ADX value
   for(int i = g_ExtADXPeriod * 2 - 1; i < rates_total; i++)
     {
      if(i == g_ExtADXPeriod * 2 - 1) // First ADX value is a simple average
        {
         double sum_dx = 0;
         for(int j=i-g_ExtADXPeriod+1; j<=i; j++)
            sum_dx += BufferDX[j];
         BufferHA_ADX[i] = sum_dx / g_ExtADXPeriod;
        }
      else // Subsequent ADX values are smoothed
        {
         BufferHA_ADX[i] = (BufferHA_ADX[i-1] * (g_ExtADXPeriod - 1) + BufferDX[i]) / g_ExtADXPeriod;
        }
     }

//--- Return value of rates_total to signal a full recalculation
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
