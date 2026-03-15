//+------------------------------------------------------------------+
//|                                               VWAP_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Bulletproof Sync & Gapped Drawing
#property description "VWAP with Volume-Weighted Standard Deviation Bands."
#property description "Bands only display for the Current Session."

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

// Plot 1-2: VWAP (Odd/Even for Gapped Drawing)
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

// Plot 3-4: Band 1 (+/-)
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID

#property indicator_label4  "Lower Band 1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_SOLID

// Plot 5-6: Band 2 (+/-)
#property indicator_label5  "Upper Band 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCoral
#property indicator_style5  STYLE_SOLID

#property indicator_label6  "Lower Band 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCoral
#property indicator_style6  STYLE_SOLID

// Plot 7-8: Band 3 (+/-)
#property indicator_label7  "Upper Band 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrRed
#property indicator_style7  STYLE_SOLID

#property indicator_label8  "Lower Band 3"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrRed
#property indicator_style8  STYLE_SOLID

#include <MyIncludes\VWAP_Calculator.mqh>

//--- Input Parameters
input group "VWAP Settings"
input ENUM_VWAP_PERIOD    InpResetPeriod  = PERIOD_SESSION;
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input int                 InpTzShift      = 0; // Timezone shift (Hours)

input group "Bands Settings"
input double              InpBand1Mult    = 1.0;
input double              InpBand2Mult    = 2.0;
input double              InpBand3Mult    = 3.0;

//--- Buffers
double BufVWAP_Odd[];
double BufVWAP_Even[];
double BufUp1[], BufDn1[];
double BufUp2[], BufDn2[];
double BufUp3[], BufDn3[];

//--- Calculator
CVWAPCalculator *g_vwap;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufVWAP_Odd, INDICATOR_DATA);
   SetIndexBuffer(1, BufVWAP_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufUp1, INDICATOR_DATA);
   SetIndexBuffer(3, BufDn1, INDICATOR_DATA);
   SetIndexBuffer(4, BufUp2, INDICATOR_DATA);
   SetIndexBuffer(5, BufDn2, INDICATOR_DATA);
   SetIndexBuffer(6, BufUp3, INDICATOR_DATA);
   SetIndexBuffer(7, BufDn3, INDICATOR_DATA);

// Disable drawing for empty values (Crucial for gapped lines)
   for(int i=0; i<8; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(1, PLOT_LABEL, "VWAP (Segment)");

   g_vwap = new CVWAPCalculator();
   if(!g_vwap.Init(InpResetPeriod, InpVolumeType, InpTzShift, true, 0))
      return INIT_FAILED;

   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP Bands Pro");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_vwap)==POINTER_DYNAMIC) delete g_vwap; }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
   if(rates_total < 2)
      return 0;

// 1. Run Original VWAP Calculator (Fills Odd/Even properly)
   g_vwap.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, BufVWAP_Odd, BufVWAP_Even);

// 2. Find the Start of the Current Session
// We look backwards until the Odd/Even status flips.
   int current_session_start = 0;

   for(int i = rates_total - 1; i > 0; i--)
     {
      bool is_odd_now  = (BufVWAP_Odd[i] != EMPTY_VALUE && BufVWAP_Odd[i] != 0);
      bool is_odd_prev = (BufVWAP_Odd[i-1] != EMPTY_VALUE && BufVWAP_Odd[i-1] != 0);

      if(is_odd_now != is_odd_prev)
        {
         current_session_start = i;
         break;
        }
     }

// 3. Clear Old Bands if a New Session just started
   static int prev_session_start = -1;
   if(current_session_start != prev_session_start)
     {
      // Wipe everything before the current session to keep chart clean
      for(int i = 0; i < current_session_start; i++)
        {
         BufUp1[i] = EMPTY_VALUE;
         BufDn1[i] = EMPTY_VALUE;
         BufUp2[i] = EMPTY_VALUE;
         BufDn2[i] = EMPTY_VALUE;
         BufUp3[i] = EMPTY_VALUE;
         BufDn3[i] = EMPTY_VALUE;
        }
      prev_session_start = current_session_start;
     }

// 4. Calculate Bands strictly for the Current Session
   double cum_vol = 0;
   double cum_tpv2 = 0;

// We always recalc the current session to guarantee mathematical purity
   for(int i = current_session_start; i < rates_total; i++)
     {
      double tp = (high[i] + low[i] + close[i]) / 3.0;
      double vol = (InpVolumeType == VOLUME_TICK) ? (double)tick_volume[i] : (double)volume[i];
      if(vol < 1.0)
         vol = 1.0;

      cum_vol += vol;
      cum_tpv2 += (tp * tp) * vol;

      double vwap = (BufVWAP_Odd[i] != EMPTY_VALUE && BufVWAP_Odd[i] != 0) ? BufVWAP_Odd[i] : BufVWAP_Even[i];

      if(cum_vol > 0 && vwap != EMPTY_VALUE && vwap != 0)
        {
         // Variance = E[P^2] - E[P]^2
         double variance = (cum_tpv2 / cum_vol) - (vwap * vwap);
         double stddev = (variance > 0) ? MathSqrt(variance) : 0.0;

         BufUp1[i] = vwap + (InpBand1Mult * stddev);
         BufDn1[i] = vwap - (InpBand1Mult * stddev);
         BufUp2[i] = vwap + (InpBand2Mult * stddev);
         BufDn2[i] = vwap - (InpBand2Mult * stddev);
         BufUp3[i] = vwap + (InpBand3Mult * stddev);
         BufDn3[i] = vwap - (InpBand3Mult * stddev);
        }
      else
        {
         BufUp1[i] = EMPTY_VALUE;
         BufDn1[i] = EMPTY_VALUE;
         BufUp2[i] = EMPTY_VALUE;
         BufDn2[i] = EMPTY_VALUE;
         BufUp3[i] = EMPTY_VALUE;
         BufDn3[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
