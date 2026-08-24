//+------------------------------------------------------------------+
//|                                     KAMA_Anchored_Bands_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // First Anchored KAMA with Volatility Standard Deviation Bands release
#property description "Session-Anchored Kaufman's Adaptive Moving Average (AKAMA) with Standard Deviation Bands."
#property description "Features odd/even gapped lines and current session focus."

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot 1-2: Anchored KAMA (Odd/Even for Gapped Drawing)
#property indicator_label1  "AKAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3-4: Band 1 (+/- 1.0 Sigma)
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "Lower Band 1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5-6: Band 2 (+/- 2.0 Sigma)
#property indicator_label5  "Upper Band 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCoral
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Lower Band 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCoral
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7-8: Band 3 (+/- 3.0 Sigma)
#property indicator_label7  "Upper Band 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCrimson
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  "Lower Band 3"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrCrimson
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Included Engines
#include <MyIncludes\KAMA_Anchored_Calculator.mqh>

//--- Input Parameters ---
input group "--- Anchor Settings ---"
input ENUM_ANCHOR_PERIOD        InpResetPeriod      = ANCHOR_PERIOD_SESSION; // Anchor Reset Period
input int                       InpTzShift          = 0;                     // Timezone Shift (Hours)
input string                    InpCustomStart      = "08:00";               // Custom Session Start (HH:MM)
input string                    InpCustomEnd        = "17:00";               // Custom Session End (HH:MM)

input group "--- KAMA Core Settings ---"
input int                       InpErPeriod         = 10;                    // Efficiency Ratio Period
input int                       InpFastEmaPeriod    = 2;                     // Fastest EMA Period
input int                       InpSlowEmaPeriod    = 30;                    // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice      = PRICE_CLOSE_STD;       // Price Source (Standard / HA)

input group "--- Standard Deviation Bands Settings ---"
input double                    InpBand1Mult        = 1.0;                   // Band 1 Multiplier (Sigma)
input double                    InpBand2Mult        = 2.0;                   // Band 2 Multiplier (Sigma)
input double                    InpBand3Mult        = 3.0;                   // Band 3 Multiplier (Sigma)
input bool                      InpCurrentSessionOnly= true;                 // Display Bands for Current Session Only?

input group "--- Visual Settings - AKAMA Centerline ---"
input color                     InpColorKAMA        = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleKAMA        = STYLE_SOLID;           // Centerline Style
input int                       InpWidthKAMA        = 2;                     // Centerline Width

input group "--- Visual Settings - Bands Colors ---"
input color                     InpColorBand1       = clrDodgerBlue;         // Band 1 Color (+/- 1σ)
input color                     InpColorBand2       = clrCoral;              // Band 2 Color (+/- 2σ)
input color                     InpColorBand3       = clrCrimson;            // Band 3 Color (+/- 3σ)

//--- Visual Indicator Buffers ---
double BufKAMA_Odd[];
double BufKAMA_Even[];
double BufUp1[], BufDn1[];
double BufUp2[], BufDn2[];
double BufUp3[], BufDn3[];

//--- Internal State Buffer
double g_price_series[];

//--- Calculator Object
CKamaAnchoredCalculator *g_calculator = NULL;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Bind Buffers
   SetIndexBuffer(0, BufKAMA_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufKAMA_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufUp1,       INDICATOR_DATA);
   SetIndexBuffer(3, BufDn1,       INDICATOR_DATA);
   SetIndexBuffer(4, BufUp2,       INDICATOR_DATA);
   SetIndexBuffer(5, BufDn2,       INDICATOR_DATA);
   SetIndexBuffer(6, BufUp3,       INDICATOR_DATA);
   SetIndexBuffer(7, BufDn3,       INDICATOR_DATA);

// Force strict chronological alignment (0 = oldest)
   for(int i = 0; i < 8; i++)
     {
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }

   ArraySetAsSeries(BufKAMA_Odd,  false);
   ArraySetAsSeries(BufKAMA_Even, false);
   ArraySetAsSeries(BufUp1,       false);
   ArraySetAsSeries(BufDn1,       false);
   ArraySetAsSeries(BufUp2,       false);
   ArraySetAsSeries(BufDn2,       false);
   ArraySetAsSeries(BufUp3,       false);
   ArraySetAsSeries(BufDn3,       false);

   ArrayInitialize(BufKAMA_Odd,  EMPTY_VALUE);
   ArrayInitialize(BufKAMA_Even, EMPTY_VALUE);
   ArrayInitialize(BufUp1,       EMPTY_VALUE);
   ArrayInitialize(BufDn1,       EMPTY_VALUE);
   ArrayInitialize(BufUp2,       EMPTY_VALUE);
   ArrayInitialize(BufDn2,       EMPTY_VALUE);
   ArrayInitialize(BufUp3,       EMPTY_VALUE);
   ArrayInitialize(BufDn3,       EMPTY_VALUE);

// 2. Configure Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetString(1,  PLOT_LABEL, "AKAMA (Segment)");

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorBand3);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColorBand3);

// 3. Initialize Anchored KAMA Engine
   g_calculator = new CKamaAnchoredCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpResetPeriod, InpTzShift, InpCustomStart, InpCustomEnd,
                         InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Anchored KAMA Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string short_name = StringFormat("AKAMA Bands%s(%s, ER%d)",
                                    ha_tag, EnumToString(InpResetPeriod), InpErPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
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
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Chronological Array Safety
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

// 1. Run Anchored KAMA Engine (Fills Odd/Even Buffers & Extracts Price)
   g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                          BufKAMA_Odd, BufKAMA_Even, g_price_series);

// 2. Identify the Start Index of the Current Active Session
   int current_session_start = 0;

   for(int i = rates_total - 1; i > 0; i--)
     {
      bool is_odd_now  = (BufKAMA_Odd[i] != EMPTY_VALUE);
      bool is_odd_prev = (BufKAMA_Odd[i - 1] != EMPTY_VALUE);

      if(is_odd_now != is_odd_prev)
        {
         current_session_start = i;
         break;
        }
     }

// 3. Clear Old Bands if a New Session just started (If CurrentSessionOnly is true)
   static int prev_session_start = -1;
   if(InpCurrentSessionOnly && current_session_start != prev_session_start)
     {
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

// 4. Calculate Standard Deviation Bands
   int calc_start = InpCurrentSessionOnly ? current_session_start : 0;

   double sum_sq_dev = 0.0;
   int    count = 0;
   int    last_session_idx = -1;

   for(int i = calc_start; i < rates_total; i++)
     {
      // Reset accumulators when session flips (in All Sessions mode)
      bool is_odd = (BufKAMA_Odd[i] != EMPTY_VALUE);
      int session_id = is_odd ? 1 : 2;

      if(session_id != last_session_idx)
        {
         sum_sq_dev = 0.0;
         count = 0;
         last_session_idx = session_id;
        }

      double akama = is_odd ? BufKAMA_Odd[i] : BufKAMA_Even[i];

      if(akama != EMPTY_VALUE && akama > 0.0)
        {
         double diff = g_price_series[i] - akama;
         sum_sq_dev += (diff * diff);
         count++;

         double stddev = MathSqrt(sum_sq_dev / (double)count);

         BufUp1[i] = akama + (InpBand1Mult * stddev);
         BufDn1[i] = akama - (InpBand1Mult * stddev);
         BufUp2[i] = akama + (InpBand2Mult * stddev);
         BufDn2[i] = akama - (InpBand2Mult * stddev);
         BufUp3[i] = akama + (InpBand3Mult * stddev);
         BufDn3[i] = akama - (InpBand3Mult * stddev);
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

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
