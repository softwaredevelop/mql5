//+------------------------------------------------------------------+
//|                                                 RVOL_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Relative Volume (Multi-Timeframe)."
#property description "Displays Normalized Volume of Higher Timeframe."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Levels
#property indicator_level1 1.0
#property indicator_level2 2.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot: Histogram
#property indicator_label1  "RVOL MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Low(Gray), Normal(Blue), High/Institutional(OrangeRad)
#property indicator_color1  clrGray, clrDodgerBlue, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_M15;   // Target Timeframe
input int               InpPeriod      = 20;           // Average Period
input double            InpThreshold   = 2.0;          // High Activity Level

//--- Buffers
double BufRVOL[];
double BufColor[];

//--- Internal HTF Data
long   h_vol[];
datetime h_time[];
double h_res[]; // Result

CRelativeVolumeCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufRVOL, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("RVOL MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CRelativeVolumeCalculator();
   if(!g_calc.Init(InpPeriod))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calc)==POINTER_DYNAMIC) delete g_calc; }

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
// 1. Fetch HTF Data
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpPeriod + 10)
      return 0;

   int count = MathMin(htf_bars, 3000);

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_vol, false);

// Use Tick Volume mostly
   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_time) != count)
      return 0;
   if(CopyTickVolume(_Symbol, InpTimeframe, 0, count, h_vol) != count)
      return 0;

// 2. Calc on HTF
   if(ArraySize(h_res) != count)
      ArrayResize(h_res, count);
   g_calc.Calculate(count, 0, h_vol, h_res);

// 3. Map to Current Chart
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            double val = h_res[idx_htf];
            BufRVOL[i] = val;

            // Color Logic
            if(val > InpThreshold)
               BufColor[i] = 2.0; // High
            else
               if(val > 1.0)
                  BufColor[i] = 1.0; // Normal
               else
                  BufColor[i] = 0.0; // Low
           }
         else
           {
            BufRVOL[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
