//+------------------------------------------------------------------+
//|                                             VScore_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Upgraded with Double Buffering (Session Gaps)
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

//--- Plot 3 & 4: Upper 1.5 Band (Odd / Even)
#property indicator_label3  "Bull Flow (+1.5)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  ""
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCoral
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5 & 6: Lower 1.5 Band (Odd / Even)
#property indicator_label5  "Bear Flow (-1.5)"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLightSkyBlue
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  ""
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrLightSkyBlue
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7 & 8: Upper 2.0 Band (Odd / Even)
#property indicator_label7  "Bull Extreme (+2.0)"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCoral
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  ""
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrCoral
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Plot 9 & 10: Lower 2.0 Band (Odd / Even)
#property indicator_label9  "Bear Extreme (-2.0)"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrLightSkyBlue
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

#property indicator_label10 ""
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrLightSkyBlue
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//--- Plot 11 & 12: Upper 2.5 Band (Odd / Even)
#property indicator_label11 "Bull Wall (+2.5)"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrOrangeRed
#property indicator_style11 STYLE_SOLID
#property indicator_width11 1

#property indicator_label12 ""
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrOrangeRed
#property indicator_style12 STYLE_SOLID
#property indicator_width12 1

//--- Plot 13 & 14: Lower 2.5 Band (Odd / Even)
#property indicator_label13 "Bear Wall (-2.5)"
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
input group "V-Score Logic Settings"
input int              InpPeriod         = 20;             // Volatility Lookback
input ENUM_VWAP_PERIOD InpVWAPReset      = PERIOD_SESSION; // VWAP Anchor
input ENUM_APPLIED_VOLUME InpVolumeType  = VOLUME_TICK;    // Volume Type

//--- Double Buffers
double BufVWAP_Odd[], BufVWAP_Even[];
double BufUp15_Odd[], BufUp15_Even[];
double BufDn15_Odd[], BufDn15_Even[];
double BufUp20_Odd[], BufUp20_Even[];
double BufDn20_Odd[], BufDn20_Even[];
double BufUp25_Odd[], BufUp25_Even[];
double BufDn25_Odd[], BufDn25_Even[];

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
// VWAP
   SetIndexBuffer(0, BufVWAP_Odd, INDICATOR_DATA);
   SetIndexBuffer(1, BufVWAP_Even, INDICATOR_DATA);
// +1.5
   SetIndexBuffer(2, BufUp15_Odd, INDICATOR_DATA);
   SetIndexBuffer(3, BufUp15_Even, INDICATOR_DATA);
// -1.5
   SetIndexBuffer(4, BufDn15_Odd, INDICATOR_DATA);
   SetIndexBuffer(5, BufDn15_Even, INDICATOR_DATA);
// +2.0
   SetIndexBuffer(6, BufUp20_Odd, INDICATOR_DATA);
   SetIndexBuffer(7, BufUp20_Even, INDICATOR_DATA);
// -2.0
   SetIndexBuffer(8, BufDn20_Odd, INDICATOR_DATA);
   SetIndexBuffer(9, BufDn20_Even, INDICATOR_DATA);
// +2.5
   SetIndexBuffer(10, BufUp25_Odd, INDICATOR_DATA);
   SetIndexBuffer(11, BufUp25_Even, INDICATOR_DATA);
// -2.5
   SetIndexBuffer(12, BufDn25_Odd, INDICATOR_DATA);
   SetIndexBuffer(13, BufDn25_Even, INDICATOR_DATA);

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
      BufUp15_Odd[i] = EMPTY_VALUE;
      BufUp15_Even[i] = EMPTY_VALUE;
      BufDn15_Odd[i] = EMPTY_VALUE;
      BufDn15_Even[i] = EMPTY_VALUE;
      BufUp20_Odd[i] = EMPTY_VALUE;
      BufUp20_Even[i] = EMPTY_VALUE;
      BufDn20_Odd[i] = EMPTY_VALUE;
      BufDn20_Even[i] = EMPTY_VALUE;
      BufUp25_Odd[i] = EMPTY_VALUE;
      BufUp25_Even[i] = EMPTY_VALUE;
      BufDn25_Odd[i] = EMPTY_VALUE;
      BufDn25_Even[i] = EMPTY_VALUE;

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
            BufUp15_Odd[i] = current_vwap + (1.5 * std_dev);
            BufDn15_Odd[i] = current_vwap - (1.5 * std_dev);
            BufUp20_Odd[i] = current_vwap + (2.0 * std_dev);
            BufDn20_Odd[i] = current_vwap - (2.0 * std_dev);
            BufUp25_Odd[i] = current_vwap + (2.5 * std_dev);
            BufDn25_Odd[i] = current_vwap - (2.5 * std_dev);
           }
         else
           {
            // Collapse bands to VWAP if zero volatility
            BufUp15_Odd[i] = current_vwap;
            BufDn15_Odd[i] = current_vwap;
            BufUp20_Odd[i] = current_vwap;
            BufDn20_Odd[i] = current_vwap;
            BufUp25_Odd[i] = current_vwap;
            BufDn25_Odd[i] = current_vwap;
           }
        }
      else
        {
         BufVWAP_Even[i] = current_vwap;
         if(std_dev > 1.0e-9)
           {
            BufUp15_Even[i] = current_vwap + (1.5 * std_dev);
            BufDn15_Even[i] = current_vwap - (1.5 * std_dev);
            BufUp20_Even[i] = current_vwap + (2.0 * std_dev);
            BufDn20_Even[i] = current_vwap - (2.0 * std_dev);
            BufUp25_Even[i] = current_vwap + (2.5 * std_dev);
            BufDn25_Even[i] = current_vwap - (2.5 * std_dev);
           }
         else
           {
            BufUp15_Even[i] = current_vwap;
            BufDn15_Even[i] = current_vwap;
            BufUp20_Even[i] = current_vwap;
            BufDn20_Even[i] = current_vwap;
            BufUp25_Even[i] = current_vwap;
            BufDn25_Even[i] = current_vwap;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
