//+------------------------------------------------------------------+
//|                                             ADXW_HeikenAshi.mq5  |
//|            Copyright 2024, Your Name (Based on MetaQuotes ADXW)  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Your Name"
#property link        ""
#property version     "1.03" // Corrected HA calculation and ADX initialization
#property description "Average Directional Movement Index by Welles Wilder on Heiken Ashi"

// --- Standard Includes ---
#include <MovingAverages.mqh>
// --- Custom Toolkit Include ---
#include <MyInclude\HA_Tools.mqh>

#property indicator_separate_window
#property indicator_buffers 7 // ADX, +DI, -DI, and 4 calculation buffers
#property indicator_plots   3

//--- Plot 1: ADX line
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "HA_ADX Wilder"

//--- Plot 2: +DI line
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellowGreen
#property indicator_style2  STYLE_DOT
#property indicator_width2  1
#property indicator_label2  "HA_+DI"

//--- Plot 3: -DI line
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrWheat
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
#property indicator_label3  "HA_-DI"

//--- input parameters
input int InpPeriodADX=14; // ADX Period

//--- Indicator Buffers
double    BufferHA_ADX[];   // Final ADX
double    BufferHA_PDI[];   // Final +DI
double    BufferHA_NDI[];   // Final -DI
// Calculation buffers
double    BufferSmoothed_PDM[]; // Smoothed +DM
double    BufferSmoothed_NDM[]; // Smoothed -DM
double    BufferSmoothed_TR[];  // Smoothed True Range (ATR)
double    BufferDX[];           // Directional Index

//--- Global Variables ---
int             ExtADXPeriod;
CHA_Calculator  ha_calculator; // Global instance of our Heiken Ashi calculator class

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtADXPeriod = (InpPeriodADX < 1) ? 1 : InpPeriodADX;

// Map only the buffers needed for this indicator's logic
   SetIndexBuffer(0, BufferHA_ADX,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_PDI,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_NDI,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferSmoothed_PDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSmoothed_NDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSmoothed_TR,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDX,       INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtADXPeriod * 2 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtADXPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtADXPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_ADXW(%d)", ExtADXPeriod));
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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
   if(rates_total < ExtADXPeriod + 1)
      return(0);

//====== STEP 1: CALCULATE HEIKEN ASHI BARS using our toolkit ======
   if(!ha_calculator.Calculate(rates_total, prev_calculated, open, high, low, close))
     {
      Print("Heiken Ashi calculation failed. Indicator will stop.");
      return(0);
     }

//====== STEP 2: CALCULATE ADX using the results from the HA calculator ======
   int start_adx;
   if(prev_calculated > ExtADXPeriod)
      start_adx = prev_calculated - 1;
   else
      start_adx = ExtADXPeriod;

//--- Main calculation loop
   for(int i = start_adx; i < rates_total; i++)
     {
      //--- Get Heiken Ashi values from the calculator's public buffers
      double ha_high       = ha_calculator.ha_high[i];
      double prev_ha_high  = ha_calculator.ha_high[i-1];
      double ha_low        = ha_calculator.ha_low[i];
      double prev_ha_low   = ha_calculator.ha_low[i-1];
      double prev_ha_close = ha_calculator.ha_close[i-1];

      // Calculate raw +DM, -DM, and TR
      double pdm = ha_high - prev_ha_high;
      double ndm = prev_ha_low - ha_low;
      if(pdm < 0 || pdm < ndm)
         pdm = 0;
      if(ndm < 0 || ndm < pdm)
         ndm = 0;

      double tr = MathMax(ha_high, prev_ha_close) - MathMin(ha_low, prev_ha_close);

      // Smooth PDM, NDM, and TR (Wilder's Smoothing)
      if(i == ExtADXPeriod) // First calculation: simple sum
        {
         double sum_pdm=0, sum_ndm=0, sum_tr=0;
         for(int j=1; j<=ExtADXPeriod; j++)
           {
            double p_pdm = ha_calculator.ha_high[j] - ha_calculator.ha_high[j-1];
            double p_ndm = ha_calculator.ha_low[j-1] - ha_calculator.ha_low[j];
            if(p_pdm < 0 || p_pdm < p_ndm)
               p_pdm = 0;
            if(p_ndm < 0 || p_ndm < p_pdm)
               p_ndm = 0;
            sum_pdm += p_pdm;
            sum_ndm += p_ndm;
            sum_tr += MathMax(ha_calculator.ha_high[j], ha_calculator.ha_close[j-1]) - MathMin(ha_calculator.ha_low[j], ha_calculator.ha_close[j-1]);
           }
         BufferSmoothed_PDM[i] = sum_pdm;
         BufferSmoothed_NDM[i] = sum_ndm;
         BufferSmoothed_TR[i] = sum_tr;
        }
      else // Subsequent calculations: recursive smoothing
        {
         BufferSmoothed_PDM[i] = BufferSmoothed_PDM[i-1] - (BufferSmoothed_PDM[i-1] / ExtADXPeriod) + pdm;
         BufferSmoothed_NDM[i] = BufferSmoothed_NDM[i-1] - (BufferSmoothed_NDM[i-1] / ExtADXPeriod) + ndm;
         BufferSmoothed_TR[i]  = BufferSmoothed_TR[i-1] - (BufferSmoothed_TR[i-1] / ExtADXPeriod) + tr;
        }

      // Calculate +DI and -DI
      if(BufferSmoothed_TR[i] != 0.0)
        {
         BufferHA_PDI[i] = (BufferSmoothed_PDM[i] / BufferSmoothed_TR[i]) * 100.0;
         BufferHA_NDI[i] = (BufferSmoothed_NDM[i] / BufferSmoothed_TR[i]) * 100.0;
        }

      // Calculate DX
      double di_sum = BufferHA_PDI[i] + BufferHA_NDI[i];
      if(di_sum != 0.0)
         BufferDX[i] = MathAbs(BufferHA_PDI[i] - BufferHA_NDI[i]) / di_sum * 100.0;
      else
         BufferDX[i] = 0.0;

      // Smooth DX to get ADX
      if(i == ExtADXPeriod * 2 - 1) // First ADX value is a simple average of DX
        {
         double sum_dx = 0;
         for(int j=i-ExtADXPeriod+1; j<=i; j++)
            sum_dx += BufferDX[j];
         BufferHA_ADX[i] = sum_dx / ExtADXPeriod;
        }
      else
         if(i > ExtADXPeriod * 2 - 1)  // Subsequent ADX values are smoothed
           {
            BufferHA_ADX[i] = (BufferHA_ADX[i-1] * (ExtADXPeriod - 1) + BufferDX[i]) / ExtADXPeriod;
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
