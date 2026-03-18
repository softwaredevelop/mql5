//+------------------------------------------------------------------+
//|                                           TSI_Combo_MTF_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // O(1) Incremental HTF Optimization
#property description "True Strength Index Combo (Multi-Timeframe)."
#property description "Displays Main Line, Signal Line, and Histogram from a Higher Timeframe."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Histogram (Background)
#property indicator_label1  "Oscillator"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: TSI Line
#property indicator_label2  "TSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Institutional Levels
#property indicator_level1 -50.0
#property indicator_level2 -37.5
#property indicator_level3 -25.0
#property indicator_level4  25.0
#property indicator_level5  37.5
#property indicator_level6  50.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\TSI_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_H1;        // Target Timeframe

input group                     "TSI Calculation Settings"
input int                       InpSlowPeriod   = 25;
input ENUM_MA_TYPE              InpSlowMAType   = EMA;
input int                       InpFastPeriod   = 13;
input ENUM_MA_TYPE              InpFastMAType   = EMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group                     "Signal Line Settings"
input int                       InpSignalPeriod = 13;
input ENUM_MA_TYPE              InpSignalMAType = EMA;

//--- Indicator Buffers ---
double    BufferOsc[];
double    BufferTSI[];
double    BufferSignal[];

//--- Internal HTF Data Arrays ---
double    h_open[], h_high[], h_low[], h_close[];
datetime  h_time[];
double    h_main[], h_sig[], h_osc[]; // Results

//--- Global calculator object ---
CTSICalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be strictly > Current Timeframe.");
     }

   SetIndexBuffer(0, BufferOsc,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferOsc,    false);
   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

// Factory Logic for Heikin Ashi support
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calc = new CTSICalculator_HA();
   else
      g_calc = new CTSICalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID ||
      !g_calc.Init(InpSlowPeriod, InpSlowMAType, InpFastPeriod, InpFastMAType, InpSignalPeriod, InpSignalMAType))
     {
      Print("Init Failed.");
      return(INIT_FAILED);
     }

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TSI Combo MTF %s%s(%d,%d,%d)", tf_name, type, InpSlowPeriod, InpFastPeriod, InpSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r) { if(CheckPointer(g_calc) != POINTER_INVALID) delete g_calc; }

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
// 1. Validate HTF Data Availability
   int htf_bars = iBars(_Symbol, InpTimeframe);
   if(htf_bars < InpSlowPeriod + InpFastPeriod + InpSignalPeriod)
      return 0;

   int count = MathMin(htf_bars, 3000); // Limit deep history for MTF mapping

   ArraySetAsSeries(h_time, false);
   ArraySetAsSeries(h_open, false);
   ArraySetAsSeries(h_high, false);
   ArraySetAsSeries(h_low, false);
   ArraySetAsSeries(h_close, false);

// Fetch HTF Data
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

// 2. Incremental HTF Calculation (O(1) Optimization)
   static int htf_prev_calculated = 0;
   if(prev_calculated == 0)
      htf_prev_calculated = 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calc.Calculate(count, htf_prev_calculated, price_type, h_open, h_high, h_low, h_close, h_main, h_sig, h_osc);

// Prepare for next tick
   htf_prev_calculated = count - 1;

// 3. Map HTF values to Current Timeframe (O(1) Incremental)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         // Convert descending shift (0 = newest) to ascending chronological index
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            BufferTSI[i]    = h_main[idx_htf];
            BufferSignal[i] = h_sig[idx_htf];
            BufferOsc[i]    = h_osc[idx_htf];
           }
         else
           {
            BufferTSI[i]    = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
            BufferOsc[i]    = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
