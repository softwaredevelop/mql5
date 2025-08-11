//+------------------------------------------------------------------+
//|                                             ADXW_HeikenAshi.mq5  |
//|            Copyright 2024, Your Name (Based on MetaQuotes ADXW)  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024, Your Name"
#property link        ""
#property version     "1.03" // Corrected HA calculation and ADX initialization
#property description "Average Directional Movement Index by Welles Wilder on Heiken Ashi"

#property indicator_separate_window
#property indicator_buffers 11 // ADX, +DI, -DI, and 8 calculation buffers
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
// Heiken Ashi Buffers
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];

int       ExtADXPeriod;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   ExtADXPeriod = (InpPeriodADX < 1) ? 1 : InpPeriodADX;

   SetIndexBuffer(0, BufferHA_ADX,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_PDI,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_NDI,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferSmoothed_PDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufferSmoothed_NDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferSmoothed_TR,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferDX,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferHA_Open,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, BufferHA_High,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, BufferHA_Low,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,BufferHA_Close, INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtADXPeriod * 2 - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtADXPeriod - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtADXPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_ADX Wilder(%d)", ExtADXPeriod));
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
   if(rates_total < ExtADXPeriod * 2) // Need enough data for the full calculation
      return(0);

//====== STEP 1: CALCULATE HEIKEN ASHI BARS ======
// This part is not optimized, it recalculates all HA bars every time for simplicity and stability
   BufferHA_Open[0]  = (open[0] + close[0]) / 2.0;
   BufferHA_Close[0] = (open[0] + high[0] + low[0] + close[0]) / 4.0;
   BufferHA_High[0]  = high[0];
   BufferHA_Low[0]   = low[0];

   for(int i = 1; i < rates_total; i++)
     {
      BufferHA_Open[i]  = (BufferHA_Open[i-1] + BufferHA_Close[i-1]) / 2.0;
      BufferHA_Close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      BufferHA_High[i]  = MathMax(high[i], MathMax(BufferHA_Open[i], BufferHA_Close[i]));
      BufferHA_Low[i]   = MathMin(low[i], MathMin(BufferHA_Open[i], BufferHA_Close[i]));
     }

//====== STEP 2: CALCULATE ADX FROM SCRATCH ON EVERY CALL ======

// --- Calculate raw PDM, NDM, TR for all bars ---
   double PDM[], NDM[], TR[];
   ArrayResize(PDM, rates_total);
   ArrayResize(NDM, rates_total);
   ArrayResize(TR, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      double pdm = BufferHA_High[i] - BufferHA_High[i-1];
      double ndm = BufferHA_Low[i-1] - BufferHA_Low[i];
      if(pdm < 0 || pdm < ndm)
         pdm = 0;
      if(ndm < 0 || ndm < pdm)
         ndm = 0;
      PDM[i] = pdm;
      NDM[i] = ndm;
      TR[i] = MathMax(BufferHA_High[i], BufferHA_Close[i-1]) - MathMin(BufferHA_Low[i], BufferHA_Close[i-1]);
     }

// --- Calculate first smoothed values ---
   double sum_pdm=0, sum_ndm=0, sum_tr=0;
   for(int i = 1; i <= ExtADXPeriod; i++)
     {
      sum_pdm += PDM[i];
      sum_ndm += NDM[i];
      sum_tr += TR[i];
     }
   BufferSmoothed_PDM[ExtADXPeriod] = sum_pdm;
   BufferSmoothed_NDM[ExtADXPeriod] = sum_ndm;
   BufferSmoothed_TR[ExtADXPeriod] = sum_tr;

// --- Smooth subsequent values ---
   for(int i = ExtADXPeriod + 1; i < rates_total; i++)
     {
      BufferSmoothed_PDM[i] = BufferSmoothed_PDM[i-1] - (BufferSmoothed_PDM[i-1] / ExtADXPeriod) + PDM[i];
      BufferSmoothed_NDM[i] = BufferSmoothed_NDM[i-1] - (BufferSmoothed_NDM[i-1] / ExtADXPeriod) + NDM[i];
      BufferSmoothed_TR[i]  = BufferSmoothed_TR[i-1] - (BufferSmoothed_TR[i-1] / ExtADXPeriod) + TR[i];
     }

// --- Calculate DI and DX ---
   for(int i = ExtADXPeriod; i < rates_total; i++)
     {
      if(BufferSmoothed_TR[i] != 0.0)
        {
         BufferHA_PDI[i] = (BufferSmoothed_PDM[i] / BufferSmoothed_TR[i]) * 100.0;
         BufferHA_NDI[i] = (BufferSmoothed_NDM[i] / BufferSmoothed_TR[i]) * 100.0;
        }
      double di_sum = BufferHA_PDI[i] + BufferHA_NDI[i];
      if(di_sum != 0.0)
         BufferDX[i] = MathAbs(BufferHA_PDI[i] - BufferHA_NDI[i]) / di_sum * 100.0;
     }

// --- Calculate ADX ---
   double sum_dx = 0;
   for(int i = ExtADXPeriod; i < ExtADXPeriod * 2; i++)
     {
      sum_dx += BufferDX[i];
     }
   BufferHA_ADX[ExtADXPeriod * 2 - 1] = sum_dx / ExtADXPeriod;

   for(int i = ExtADXPeriod * 2; i < rates_total; i++)
     {
      BufferHA_ADX[i] = (BufferHA_ADX[i-1] * (ExtADXPeriod - 1) + BufferDX[i]) / ExtADXPeriod;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
