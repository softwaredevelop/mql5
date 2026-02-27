//+------------------------------------------------------------------+
//|                                             AutoCorr_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Lag-1 Autocorrelation (Multi-Timeframe)."
#property description "Displays HTF Serial Correlation regime."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Plot: Histogram
#property indicator_label1  "AC MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Colors: MeanRev(Red), Random(Gray), Trend(Green)
#property indicator_color1  clrCrimson, clrGray, clrSpringGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Autocorrelation_Calculator.mqh>

//--- Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_H1;    // Target Timeframe
input int               InpPeriod      = 20;           // Window Size
input double            InpThreshold   = 0.1;          // Significance Threshold

//--- Buffers
double BufAC[];
double BufCol[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];
double h_res[]; // Result

CAutocorrelationCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufAC, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("AutoCorr MTF %s(%d)", tf_name, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_calc = new CAutocorrelationCalculator();
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

// 2. Calc on HTF
   if(ArraySize(h_res) != count)
      ArrayResize(h_res, count);
   g_calc.Calculate(count, 0, PRICE_CLOSE, h_open, h_high, h_low, h_close, h_res); // Assuming Price Close logic inside
// Note: Calculator Calculate method updated in prev steps to utilize PRICE_TYPE but logic copies to internal buffer.
// Correct call signature check in v2.0 calculator: Calculate(total, prev, price_type, o, h, l, c, out)

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
            BufAC[i] = val;

            // Color Logic
            if(val > InpThreshold)
               BufCol[i] = 2.0; // Green
            else
               if(val < -InpThreshold)
                  BufCol[i] = 0.0; // Red
               else
                  BufCol[i] = 1.0; // Gray
           }
         else
           {
            BufAC[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
