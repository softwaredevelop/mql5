//+------------------------------------------------------------------+
//|                                       TSI_Oscillator_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "True Strength Index Oscillator (Multi-Timeframe)."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Plot: Histogram
#property indicator_label1  "TSI Hist MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: Bear(Red), Bull(Green)
#property indicator_color1  clrOrangeRed, clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\TSI_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_H1;        // Target Timeframe
input group                     "TSI Settings"
input int                       InpSlowPeriod   = 25;
input int                       InpFastPeriod   = 13;
input int                       InpSignalPeriod = 13;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Buffers
double BufHist[];
double BufCol[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];
double h_main[], h_sig[], h_osc[]; // Results

CTSICalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufHist, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string name = StringFormat("TSI Osc MTF %s%s(%d,%d,%d)", tf_name, type, InpSlowPeriod, InpFastPeriod, InpSignalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calc = new CTSICalculator_HA();
   else
      g_calc = new CTSICalculator();

   if(!g_calc.Init(InpSlowPeriod, EMA, InpFastPeriod, EMA, InpSignalPeriod, EMA))
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
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpSlowPeriod + InpFastPeriod + 10)
      return 0;

   int count = MathMin(htf_bars, 3000);

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_open, false);
   ArraySetAsSeries(h_high, false);
   ArraySetAsSeries(h_low, false);
   ArraySetAsSeries(h_close, false);

   if(CopyTime(_Symbol, InpTimeframe, 0, count, h_time) != count)
      return 0;
   if(CopyOpen(_Symbol, InpTimeframe, 0, count, h_open) != count)
      return 0;
   if(CopyHigh(_Symbol, InpTimeframe, 0, count, h_high) != count)
      return 0;
   if(CopyLow(_Symbol, InpTimeframe, 0, count, h_low) != count)
      return 0;
   if(CopyClose(_Symbol, InpTimeframe, 0, count, h_close) != count)
      return 0;

   if(ArraySize(h_osc) != count)
     {
      ArrayResize(h_main, count);
      ArrayResize(h_sig, count);
      ArrayResize(h_osc, count);
     }

   g_calc.Calculate(count, 0, PRICE_CLOSE, h_open, h_high, h_low, h_close, h_main, h_sig, h_osc);

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
            double val = h_osc[idx_htf];
            BufHist[i] = val;

            // Color: Green if > 0, Red if < 0
            if(val > 0)
               BufCol[i] = 1.0;
            else
               BufCol[i] = 0.0;
           }
         else
           {
            BufHist[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
