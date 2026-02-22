//+------------------------------------------------------------------+
//|                                             Velocity_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Dual Mode MTF (Vector + Speed Envelope)
#property description "Velocity (MTF) - Displays HTF Velocity & Speed on current chart."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

// Levels
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_level3 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

// Plot 1: Velocity Histogram
#property indicator_label1  "Velocity MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Speed Positive
#property indicator_label2  "Speed (+) MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot 3: Speed Negative
#property indicator_label3  "Speed (-) MTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>

//--- Input Parameters
input ENUM_TIMEFRAMES   InpTimeframe   = PERIOD_M15;   // Target Timeframe
input int               InpVelPeriod   = 3;            // Velocity Period
input int               InpATRPeriod   = 14;           // Normalization ATR
input double            InpThreshold   = 1.0;          // High Velocity Threshold
input bool              InpShowSpeed   = true;         // Show Scalar Speed Line

//--- Buffers (Visual)
double BufVel[];
double BufColor[];
double BufSpeedPos[];
double BufSpeedNeg[];

//--- Internal HTF Data
double h_vel[], h_spd[]; // Calculated HTF results
datetime h_time[];
double h_open[], h_high[], h_low[], h_close[];
long   h_vol[]; // Dummy

CATRCalculator *g_atr;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTimeframe <= Period())
     {
      if(InpTimeframe != Period())
         Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

   SetIndexBuffer(0, BufVel, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSpeedPos, INDICATOR_DATA);
   SetIndexBuffer(3, BufSpeedNeg, INDICATOR_DATA);

   if(!InpShowSpeed)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string name = StringFormat("Velocity MTF %s(%d)", tf_name, InpVelPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

   g_atr = new CATRCalculator();
   if(!g_atr.Init(InpATRPeriod, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(CheckPointer(g_atr)==POINTER_DYNAMIC)
      delete g_atr;
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
   if(htf_bars < InpATRPeriod + InpVelPeriod)
      return 0;

   int count = MathMin(htf_bars, 3000);

// Set arrays to Non-Series (Chronological)
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

// 2. Calc on HTF Arrays
   if(ArraySize(h_vel) != count)
     {
      ArrayResize(h_vel, count);
      ArrayResize(h_spd, count);
     }

// A. Calculate ATR on HTF
   double h_atr_buf[];
   g_atr.Calculate(count, 0, h_open, h_high, h_low, h_close, h_atr_buf);

// B. Loop HTF
// Logic copied from Velocity_Pro.mq5 but applied to 'h_' arrays
   for(int i = InpATRPeriod+InpVelPeriod; i < count; i++)
     {
      double atr = h_atr_buf[i];
      if(atr == 0)
        {
         h_vel[i]=0;
         h_spd[i]=0;
         continue;
        }

      // Velocity (Vector)
      // Uses Metrics Tools Logic: (Close - PrevClose) / ATR
      h_vel[i] = CMetricsTools::CalculateSlope(h_close[i], h_close[i-InpVelPeriod], atr, InpVelPeriod);

      // Speed (Scalar)
      double path_length = 0;
      for(int k=0; k<InpVelPeriod; k++)
        {
         path_length += MathAbs(h_close[i-k] - h_close[i-k-1]);
        }
      h_spd[i] = (path_length / InpVelPeriod) / atr;
     }

// 3. Map to Current Chart
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         // Convert Series shift (0=Recent) to Array index (0=Oldest)
         int idx_htf = count - 1 - shift_htf;

         if(idx_htf >= 0 && idx_htf < count)
           {
            double val_v = h_vel[idx_htf];
            double val_s = h_spd[idx_htf];

            BufVel[i] = val_v;
            BufSpeedPos[i] = val_s;
            BufSpeedNeg[i] = -val_s;

            // Color Logic
            if(val_v > InpThreshold)
               BufColor[i] = 1.0; // Lime
            else
               if(val_v < -InpThreshold)
                  BufColor[i] = 2.0; // Red
               else
                  BufColor[i] = 0.0; // Gray
           }
         else
           {
            BufVel[i] = EMPTY_VALUE;
            BufSpeedPos[i] = EMPTY_VALUE;
            BufSpeedNeg[i] = EMPTY_VALUE;
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
