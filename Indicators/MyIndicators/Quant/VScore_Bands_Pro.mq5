//+------------------------------------------------------------------+
//|                                             VScore_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Refactored with Dynamic Input Levels
#property description "V-Score Projected Bands on Main Chart."
#property description "Rolling standard deviation (Bollinger style) around VWAP."

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   14

//--- Plot 1 & 2: VWAP Base (Odd / Even)
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3 & 4: Upper Flow Band (Odd / Even)
#property indicator_label3  "Bull Flow" // Dynamically updated in OnInit
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  ""
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCoral
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5 & 6: Lower Flow Band (Odd / Even)
#property indicator_label5  "Bear Flow" // Dynamically updated in OnInit
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLightSkyBlue
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  ""
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrLightSkyBlue
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7 & 8: Upper Extreme Band (Odd / Even)
#property indicator_label7  "Bull Extreme" // Dynamically updated in OnInit
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCoral
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  ""
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrCoral
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Plot 9 & 10: Lower Extreme Band (Odd / Even)
#property indicator_label9  "Bear Extreme" // Dynamically updated in OnInit
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrLightSkyBlue
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

#property indicator_label10 ""
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrLightSkyBlue
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//--- Plot 11 & 12: Upper Wall Band (Odd / Even)
#property indicator_label11 "Bull Wall" // Dynamically updated in OnInit
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrOrangeRed
#property indicator_style11 STYLE_SOLID
#property indicator_width11 1

#property indicator_label12 ""
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrOrangeRed
#property indicator_style12 STYLE_SOLID
#property indicator_width12 1

//--- Plot 13 & 14: Lower Wall Band (Odd / Even)
#property indicator_label13 "Bear Wall" // Dynamically updated in OnInit
#property indicator_type13  DRAW_LINE
#property indicator_color13 clrDeepSkyBlue
#property indicator_style13 STYLE_SOLID
#property indicator_width13 1

#property indicator_label14 ""
#property indicator_type14  DRAW_LINE
#property indicator_color14 clrDeepSkyBlue
#property indicator_style14 STYLE_SOLID
#property indicator_width14 1

#include <MyIncludes\VWAP_Calculator.mqh>

//--- Input Parameters
input group "V-Score Core Settings"
input int                 InpPeriod         = 20;             // Volatility Lookback
input ENUM_VWAP_PERIOD    InpVWAPReset      = PERIOD_SESSION; // VWAP Anchor
input ENUM_APPLIED_VOLUME InpVolumeType     = VOLUME_TICK;    // Volume Type

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "V-Score Z-Levels (Standard Deviations)"
input double              InpLevelFlow      = 1.5;            // Flow Level (Point of No Return)
input double              InpLevelExtreme   = 2.0;            // Extreme Level (Warning)
input double              InpLevelWall      = 2.5;            // Wall Level (Climax Exhaustion)

//--- Double Buffers (Semantically Named)
double BufVWAP_Odd[],   BufVWAP_Even[];
double BufUpFlow_Odd[], BufUpFlow_Even[];
double BufDnFlow_Odd[], BufDnFlow_Even[];
double BufUpExtr_Odd[], BufUpExtr_Even[];
double BufDnExtr_Odd[], BufDnExtr_Even[];
double BufUpWall_Odd[], BufUpWall_Even[];
double BufDnWall_Odd[], BufDnWall_Even[];

// Internal Arrays
double m_vwap_odd[];
double m_vwap_even[];
double m_merged_vwap[];

//--- Global Engine
CVWAPCalculator *g_vwap;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// VWAP Base
   SetIndexBuffer(0, BufVWAP_Odd, INDICATOR_DATA);
   SetIndexBuffer(1, BufVWAP_Even, INDICATOR_DATA);

// Flow Level Bands
   SetIndexBuffer(2, BufUpFlow_Odd, INDICATOR_DATA);
   SetIndexBuffer(3, BufUpFlow_Even, INDICATOR_DATA);
   SetIndexBuffer(4, BufDnFlow_Odd, INDICATOR_DATA);
   SetIndexBuffer(5, BufDnFlow_Even, INDICATOR_DATA);

// Extreme Level Bands
   SetIndexBuffer(6, BufUpExtr_Odd, INDICATOR_DATA);
   SetIndexBuffer(7, BufUpExtr_Even, INDICATOR_DATA);
   SetIndexBuffer(8, BufDnExtr_Odd, INDICATOR_DATA);
   SetIndexBuffer(9, BufDnExtr_Even, INDICATOR_DATA);

// Wall Level Bands
   SetIndexBuffer(10, BufUpWall_Odd, INDICATOR_DATA);
   SetIndexBuffer(11, BufUpWall_Even, INDICATOR_DATA);
   SetIndexBuffer(12, BufDnWall_Odd, INDICATOR_DATA);
   SetIndexBuffer(13, BufDnWall_Even, INDICATOR_DATA);

// Dynamically set plot labels to reflect custom input levels in the Data Window
   PlotIndexSetString(2,  PLOT_LABEL, StringFormat("Bull Flow (+%.2f)", InpLevelFlow));
   PlotIndexSetString(4,  PLOT_LABEL, StringFormat("Bear Flow (-%.2f)", InpLevelFlow));
   PlotIndexSetString(6,  PLOT_LABEL, StringFormat("Bull Extr (+%.2f)", InpLevelExtreme));
   PlotIndexSetString(8,  PLOT_LABEL, StringFormat("Bear Extr (-%.2f)", InpLevelExtreme));
   PlotIndexSetString(10, PLOT_LABEL, StringFormat("Bull Wall (+%.2f)", InpLevelWall));
   PlotIndexSetString(12, PLOT_LABEL, StringFormat("Bear Wall (-%.2f)", InpLevelWall));

// Prevent drawing lines to 0 when values are empty
   for(int i=0; i<14; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   string name = StringFormat("V-Score Bands(%d)", InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   g_vwap = new CVWAPCalculator();
   if(!g_vwap.Init(InpVWAPReset, InpVolumeType, 0, true, 0))
     {
      Print("Error: Failed to initialize VWAP Engine.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_vwap) == POINTER_DYNAMIC)
      delete g_vwap;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total < InpPeriod)
      return 0;

// 1. Resize internal arrays
   if(ArraySize(m_vwap_odd) != rates_total)
     {
      ArrayResize(m_vwap_odd, rates_total);
      ArrayResize(m_vwap_even, rates_total);
      ArrayResize(m_merged_vwap, rates_total);
     }

// 2. Calculate Base VWAP Incrementally
   g_vwap.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, m_vwap_odd, m_vwap_even);

// 3. Project Bands matching V-Score standard deviation logic
   int start = (prev_calculated > InpPeriod) ? prev_calculated - 1 : InpPeriod;

   for(int i = start; i < rates_total; i++)
     {
      // Determine if the current session is using the Odd or Even buffer
      bool is_odd = (m_vwap_odd[i] != EMPTY_VALUE && m_vwap_odd[i] != 0);
      double current_vwap = is_odd ? m_vwap_odd[i] : m_vwap_even[i];
      m_merged_vwap[i] = current_vwap;

      // Reset all outputs for current bar first
      BufVWAP_Odd[i] = EMPTY_VALUE;
      BufVWAP_Even[i] = EMPTY_VALUE;
      BufUpFlow_Odd[i] = EMPTY_VALUE;
      BufUpFlow_Even[i] = EMPTY_VALUE;
      BufDnFlow_Odd[i] = EMPTY_VALUE;
      BufDnFlow_Even[i] = EMPTY_VALUE;
      BufUpExtr_Odd[i] = EMPTY_VALUE;
      BufUpExtr_Even[i] = EMPTY_VALUE;
      BufDnExtr_Odd[i] = EMPTY_VALUE;
      BufDnExtr_Even[i] = EMPTY_VALUE;
      BufUpWall_Odd[i] = EMPTY_VALUE;
      BufUpWall_Even[i] = EMPTY_VALUE;
      BufDnWall_Odd[i] = EMPTY_VALUE;
      BufDnWall_Even[i] = EMPTY_VALUE;

      // If VWAP is missing or just reset, continue
      if(current_vwap == 0 || current_vwap == EMPTY_VALUE)
         continue;

      // Calculate StdDev of the distance (Price - VWAP) over InpPeriod
      double sum_sq_diff = 0;
      for(int k = 0; k < InpPeriod; k++)
        {
         int idx = i - k;
         double p = close[idx];
         double v = m_merged_vwap[idx];

         // Fallback if historical VWAP is invalid during rolling window
         if(v == 0 || v == EMPTY_VALUE)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / InpPeriod);

      // Assign calculated values to the correct Active Buffer (Odd or Even)
      if(is_odd)
        {
         BufVWAP_Odd[i] = current_vwap;
         if(std_dev > 1.0e-9)
           {
            BufUpFlow_Odd[i] = current_vwap + (InpLevelFlow * std_dev);
            BufDnFlow_Odd[i] = current_vwap - (InpLevelFlow * std_dev);
            BufUpExtr_Odd[i] = current_vwap + (InpLevelExtreme * std_dev);
            BufDnExtr_Odd[i] = current_vwap - (InpLevelExtreme * std_dev);
            BufUpWall_Odd[i] = current_vwap + (InpLevelWall * std_dev);
            BufDnWall_Odd[i] = current_vwap - (InpLevelWall * std_dev);
           }
         else
           {
            // Collapse bands to VWAP if zero volatility
            BufUpFlow_Odd[i] = current_vwap;
            BufDnFlow_Odd[i] = current_vwap;
            BufUpExtr_Odd[i] = current_vwap;
            BufDnExtr_Odd[i] = current_vwap;
            BufUpWall_Odd[i] = current_vwap;
            BufDnWall_Odd[i] = current_vwap;
           }
        }
      else
        {
         BufVWAP_Even[i] = current_vwap;
         if(std_dev > 1.0e-9)
           {
            BufUpFlow_Even[i] = current_vwap + (InpLevelFlow * std_dev);
            BufDnFlow_Even[i] = current_vwap - (InpLevelFlow * std_dev);
            BufUpExtr_Even[i] = current_vwap + (InpLevelExtreme * std_dev);
            BufDnExtr_Even[i] = current_vwap - (InpLevelExtreme * std_dev);
            BufUpWall_Even[i] = current_vwap + (InpLevelWall * std_dev);
            BufDnWall_Even[i] = current_vwap - (InpLevelWall * std_dev);
           }
         else
           {
            // Collapse bands to VWAP if zero volatility
            BufUpFlow_Even[i] = current_vwap;
            BufDnFlow_Even[i] = current_vwap;
            BufUpExtr_Even[i] = current_vwap;
            BufDnExtr_Even[i] = current_vwap;
            BufUpWall_Even[i] = current_vwap;
            BufDnWall_Even[i] = current_vwap;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
