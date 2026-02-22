//+------------------------------------------------------------------+
//|                                       Ehlers_Channel_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Ehlers Channel (Multi-Timeframe)."
#property description "Displays HTF Smoother-based Channel on Current Chart."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot 1: Upper
#property indicator_label1  "Upper MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSlateBlue
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

// Plot 2: Lower
#property indicator_label2  "Lower MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMediumSlateBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

// Plot 3: Middle
#property indicator_label3  "Middle MTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\Ehlers_Channel_Calculator.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_H1;         // Target Timeframe
input group                     "Smoother Settings"
input ENUM_SMOOTHER_TYPE        InpSmootherType   = SUPERSMOOTHER;     // Filter Type
input int                       InpPeriod         = 20;                // Filter Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group                     "Channel (ATR) Settings"
input int                       InpAtrPeriod      = 14;
input double                    InpMultiplier     = 2.0;
input ENUM_ATR_SOURCE           InpAtrSource      = ATR_SOURCE_STANDARD;

//--- Buffers
double BufUpper[];
double BufLower[];
double BufMiddle[];

//--- Internal HTF Data
double h_open[], h_high[], h_low[], h_close[];
datetime h_time[];
double h_up[], h_lo[], h_mid[]; // Calculated HTF results

//--- Calculator
CEhlersChannelCalculator *g_calc;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufUpper, INDICATOR_DATA);
   SetIndexBuffer(1, BufLower, INDICATOR_DATA);
   SetIndexBuffer(2, BufMiddle, INDICATOR_DATA);

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string smoothStr = (InpSmootherType == SUPERSMOOTHER) ? "SS" : "US";
   string name = StringFormat("Ehlers Ch MTF %s(%s %d, ATR %d)", tf_name, smoothStr, InpPeriod, InpAtrPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// Factory Logic for HA support
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calc = new CEhlersChannelCalculator_HA();
   else
      g_calc = new CEhlersChannelCalculator();

   if(!g_calc.Init(InpPeriod, InpSmootherType, InpAtrPeriod, InpMultiplier, InpAtrSource))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_calc)==POINTER_DYNAMIC)
      delete g_calc;
  }

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
   if(htf_bars < MathMax(InpPeriod, InpAtrPeriod) + 10)
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
   if(ArraySize(h_up) != count)
     {
      ArrayResize(h_up, count);
      ArrayResize(h_lo, count);
      ArrayResize(h_mid, count);
     }

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calc.Calculate(count, 0, h_open, h_high, h_low, h_close, price_type, h_mid, h_up, h_lo);

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
            BufUpper[i]  = h_up[idx_htf];
            BufLower[i]  = h_lo[idx_htf];
            BufMiddle[i] = h_mid[idx_htf];
           }
         else
           {
            BufUpper[i]  = EMPTY_VALUE;
            BufLower[i]  = EMPTY_VALUE;
            BufMiddle[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
