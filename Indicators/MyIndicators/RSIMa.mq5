//+------------------------------------------------------------------+
//|                                                       RSIMA.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored for full recalculation and stability
#property description "Oscillator based on the Moving Average of a standard RSI."

// --- Standard Includes ---
#include <MovingAverages.mqh>

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Buffers and Plots ---
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: RSIMA (Smoothed RSI)
#property indicator_label1  "RSIMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: RSI (Raw RSI)
#property indicator_label2  "RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Input Parameters ---
input int                 InpPeriodRSI      = 14;          // Period for RSI
input ENUM_APPLIED_PRICE  InpAppliedPrice   = PRICE_CLOSE; // Applied price for RSI
input int                 InpPeriodMA       = 14;          // Period for Moving Average
input ENUM_MA_METHOD      InpMethod         = MODE_SMA;    // Method for Moving Average

//--- Indicator Buffers ---
double    BufferRSIMA[];    // Buffer for the smoothed RSI line (Plot 1)
double    BufferRawRSI[];   // Buffer for the raw RSI values (Plot 2)

//--- Global Variables ---
int       g_ExtPeriodRSI;
int       g_ExtPeriodMA;
int       g_handle_rsi;       // Handle for the standard RSI indicator

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate and store input periods
   g_ExtPeriodRSI = (InpPeriodRSI < 1) ? 1 : InpPeriodRSI;
   g_ExtPeriodMA  = (InpPeriodMA < 1) ? 1 : InpPeriodMA;

//--- Map the buffers
   SetIndexBuffer(0, BufferRSIMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferRawRSI, INDICATOR_DATA);

//--- Set buffers as non-timeseries for stable calculation
   ArraySetAsSeries(BufferRSIMA,  false);
   ArraySetAsSeries(BufferRawRSI, false);

//--- Set indicator display properties
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSIMA(%d, %d)", g_ExtPeriodRSI, g_ExtPeriodMA));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_ExtPeriodRSI + g_ExtPeriodMA - 1);
   PlotIndexSetString(0, PLOT_LABEL, "RSIMA");
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_ExtPeriodRSI - 1);
   PlotIndexSetString(1, PLOT_LABEL, "RSI");

//--- Create a handle to the standard iRSI indicator
   g_handle_rsi = iRSI(_Symbol, _Period, g_ExtPeriodRSI, InpAppliedPrice);
   if(g_handle_rsi == INVALID_HANDLE)
     {
      PrintFormat("Failed to create iRSI handle. Error %d", GetLastError());
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release the indicator handle
   IndicatorRelease(g_handle_rsi);
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
//--- Check if there is enough data for the calculation
   int start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1;
   if(rates_total <= start_pos)
      return(0);

//--- STEP 1: Get all available RSI values into our buffer
   if(CopyBuffer(g_handle_rsi, 0, 0, rates_total, BufferRawRSI) < rates_total)
     {
      Print("Error copying RSI buffer data.");
     }

//--- STEP 2: Calculate the Moving Average on the RSI buffer
   int ma_start_pos = g_ExtPeriodRSI + g_ExtPeriodMA - 1; // Correct start pos
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      // --- FIX: Full, robust switch block for all MA types ---
      switch(InpMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtPeriodMA; j++)
                  sum+=BufferRawRSI[i-j];
               BufferRSIMA[i] = sum/g_ExtPeriodMA;
              }
            else
              {
               if(InpMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtPeriodMA+1.0);
                  BufferRSIMA[i] = BufferRawRSI[i]*pr + BufferRSIMA[i-1]*(1.0-pr);
                 }
               else
                  BufferRSIMA[i] = (BufferRSIMA[i-1]*(g_ExtPeriodMA-1)+BufferRawRSI[i])/g_ExtPeriodMA;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
              {
               int weight=g_ExtPeriodMA-j;
               lwma_sum+=BufferRawRSI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferRSIMA[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtPeriodMA; j++)
               sum+=BufferRawRSI[i-j];
            BufferRSIMA[i] = sum/g_ExtPeriodMA;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
