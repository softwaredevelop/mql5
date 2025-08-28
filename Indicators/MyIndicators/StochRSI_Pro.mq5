//+------------------------------------------------------------------+
//|                                                  StochRSI_Pro.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Stochastic RSI with selectable MA types for %K and %D."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 4 // %K, %D, RawK, and RSI buffer
#property indicator_plots   2
#property indicator_level1 20.0
#property indicator_level2 80.0
#property indicator_minimum -10.0
#property indicator_maximum 110.0

//--- Plot 1: %K line
#property indicator_label1  "%K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: %D line
#property indicator_label2  "%D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int            InpRSIPeriod     = 14;
input int            InpKPeriod       = 14;
input int            InpSlowingPeriod = 3;
input ENUM_MA_METHOD InpSlowingMAType = MODE_SMA; // MA type for Slowing
input int            InpDPeriod       = 3;
input ENUM_MA_METHOD InpDMAType       = MODE_SMMA; // MA type for %D (Signal)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferK[];
double    BufferD[];
double    BufferRSI[];
double    BufferRawStochK[];

//--- Global Variables ---
int       g_ExtRSIPeriod, g_ExtKPeriod, g_ExtSlowingPeriod, g_ExtDPeriod;
int       g_handle_rsi;

//--- Forward declarations for helper functions ---
double Highest(const double &array[], int period, int current_pos);
double Lowest(const double &array[], int period, int current_pos);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtRSIPeriod     = (InpRSIPeriod < 1) ? 1 : InpRSIPeriod;
   g_ExtKPeriod       = (InpKPeriod < 1) ? 1 : InpKPeriod;
   g_ExtSlowingPeriod = (InpSlowingPeriod < 1) ? 1 : InpSlowingPeriod;
   g_ExtDPeriod       = (InpDPeriod < 1) ? 1 : InpDPeriod;

   SetIndexBuffer(0, BufferK,         INDICATOR_DATA);
   SetIndexBuffer(1, BufferD,         INDICATOR_DATA);
   SetIndexBuffer(2, BufferRSI,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufferRawStochK, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferK,         false);
   ArraySetAsSeries(BufferD,         false);
   ArraySetAsSeries(BufferRSI,       false);
   ArraySetAsSeries(BufferRawStochK, false);

   g_handle_rsi = iRSI(_Symbol, _Period, g_ExtRSIPeriod, InpAppliedPrice);
   if(g_handle_rsi == INVALID_HANDLE)
     {
      Print("Error creating iRSI handle.");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtRSIPeriod + g_ExtKPeriod + g_ExtSlowingPeriod - 3);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtRSIPeriod + g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 4);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("StochRSI Pro(%d,%d,%d,%d)", g_ExtRSIPeriod, g_ExtKPeriod, g_ExtSlowingPeriod, g_ExtDPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(g_handle_rsi);
  }

//+------------------------------------------------------------------+
//| Pro Stochastic RSI calculation function.                         |
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
   int start_pos = g_ExtRSIPeriod + g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 3;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Get RSI values
   if(CopyBuffer(g_handle_rsi, 0, 0, rates_total, BufferRSI) < rates_total)
     {
      Print("Error copying iRSI buffer data.");
     }

//--- STEP 2: Calculate Raw Stochastic %K on the RSI buffer
   int raw_k_start_pos = g_ExtRSIPeriod + g_ExtKPeriod - 2;
   for(int i = raw_k_start_pos; i < rates_total; i++)
     {
      double highest_rsi = Highest(BufferRSI, g_ExtKPeriod, i);
      double lowest_rsi  = Lowest(BufferRSI, g_ExtKPeriod, i);
      double range = highest_rsi - lowest_rsi;
      if(range > 0.00001)
         BufferRawStochK[i] = (BufferRSI[i] - lowest_rsi) / range * 100.0;
      else
         BufferRawStochK[i] = (i > 0) ? BufferRawStochK[i-1] : 50.0;
     }

//--- STEP 3: Calculate %K (Main Line) by smoothing Raw %K
   int k_slow_start_pos = g_ExtRSIPeriod + g_ExtKPeriod + g_ExtSlowingPeriod - 3;
   for(int i = k_slow_start_pos; i < rates_total; i++)
     {
      switch(InpSlowingMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == k_slow_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtSlowingPeriod; j++)
                  sum+=BufferRawStochK[i-j];
               BufferK[i] = sum/g_ExtSlowingPeriod;
              }
            else
              {
               if(InpSlowingMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtSlowingPeriod+1.0);
                  BufferK[i] = BufferRawStochK[i]*pr + BufferK[i-1]*(1.0-pr);
                 }
               else
                  BufferK[i] = (BufferK[i-1]*(g_ExtSlowingPeriod-1)+BufferRawStochK[i])/g_ExtSlowingPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtSlowingPeriod; j++)
              {
               int weight=g_ExtSlowingPeriod-j;
               lwma_sum+=BufferRawStochK[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferK[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtSlowingPeriod; j++)
               sum+=BufferRawStochK[i-j];
            BufferK[i] = sum/g_ExtSlowingPeriod;
           }
         break;
        }
     }

//--- STEP 4: Calculate %D (Signal Line) by smoothing %K
   int d_start_pos = g_ExtRSIPeriod + g_ExtKPeriod + g_ExtSlowingPeriod + g_ExtDPeriod - 4;
   for(int i = d_start_pos; i < rates_total; i++)
     {
      switch(InpDMAType)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == d_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtDPeriod; j++)
                  sum+=BufferK[i-j];
               BufferD[i] = sum/g_ExtDPeriod;
              }
            else
              {
               if(InpDMAType == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtDPeriod+1.0);
                  BufferD[i] = BufferK[i]*pr + BufferD[i-1]*(1.0-pr);
                 }
               else
                  BufferD[i] = (BufferD[i-1]*(g_ExtDPeriod-1)+BufferK[i])/g_ExtDPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtDPeriod; j++)
              {
               int weight=g_ExtDPeriod-j;
               lwma_sum+=BufferK[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferD[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtDPeriod; j++)
               sum+=BufferK[i-j];
            BufferD[i] = sum/g_ExtDPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Finds the highest value in a given period of an array.           |
//+------------------------------------------------------------------+
double Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Finds the lowest value in a given period of an array.            |
//+------------------------------------------------------------------+
double Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
