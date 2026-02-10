//+------------------------------------------------------------------+
//|                                               TrendScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "DSMA Trend Score (Histogram) & Slope (Line)."
#property description "Quantifies trend extension and acceleration in ATR units."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Levels
#property indicator_level1 1.0
#property indicator_level2 -1.0
#property indicator_level3 0.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Trend Score (Distance from DSMA)
#property indicator_label1  "Trend Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrLime, clrRed // Neutral, Bullish Ext, Bearish Ext
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Trend Slope (Acceleration)
#property indicator_label2  "Trend Slope"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Includes
#include <MyIncludes\DSMA_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\Metrics_Tools.mqh>

//--- Input Parameters
input int      InpDSMAPeriod     = 40;    // Trend Period
input int      InpATRPeriod      = 14;    // Normalization Period
input int      InpSlopeLookback  = 5;     // Slope Bars Back
input double   InpScoreThresh    = 1.0;   // Color Threshold for Score

//--- Buffers
double BufScore[];
double BufScoreColors[];
double BufSlope[];
double BufDSMA_Internal[]; // Hidden buffer for DSMA calculation

//--- Objects
CDSMACalculator *g_dsma;
CATRCalculator  *g_atr;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);
   SetIndexBuffer(1, BufScoreColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufSlope, INDICATOR_DATA);
   SetIndexBuffer(3, BufDSMA_Internal, INDICATOR_CALCULATIONS);

   string name = StringFormat("TrendScore(%d)", InpDSMAPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_dsma = new CDSMACalculator();
   if(!g_dsma.Init(InpDSMAPeriod))
      return INIT_FAILED;

   g_atr = new CATRCalculator();
   if(!g_atr.Init(InpATRPeriod, ATR_POINTS))
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_dsma)==POINTER_DYNAMIC)
      delete g_dsma;
   if(CheckPointer(g_atr)==POINTER_DYNAMIC)
      delete g_atr;
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
   if(rates_total < MathMax(InpDSMAPeriod, InpATRPeriod) + InpSlopeLookback)
      return 0;

// 1. Calculate DSMA
   g_dsma.Calculate(rates_total, prev_calculated, PRICE_CLOSE, open, high, low, close, BufDSMA_Internal);

// 2. Calculate ATR
   double atr_buf[];
   if(ArraySize(atr_buf) != rates_total)
      ArrayResize(atr_buf, rates_total);

   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, atr_buf);

// 3. Main Loop
   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpDSMAPeriod + InpSlopeLookback;

   for(int i = start; i < rates_total; i++)
     {
      double atr = atr_buf[i];
      if(atr == 0)
        {
         BufScore[i]=0;
         BufSlope[i]=0;
         continue;
        }

      // --- Trend Score ---
      // (Price - DSMA) / ATR
      double dsma = BufDSMA_Internal[i];
      // REFACTORED: Use Metrics Tools
      double score = CMetricsTools::CalculateDeviation(close[i], dsma, atr);
      BufScore[i] = score;

      // Color Logic
      if(score > InpScoreThresh)
         BufScoreColors[i] = 1.0;      // Lime (Extensions)
      else
         if(score < -InpScoreThresh)
            BufScoreColors[i] = 2.0;   // Red
         else
            BufScoreColors[i] = 0.0;   // Gray

      // --- Trend Slope ---
      // (DSMA - DesmaPrev) / ATR
      // Using Metrics Tools logic but applied to DSMA array
      BufSlope[i] = CMetricsTools::CalculateSlope(dsma, BufDSMA_Internal[i-InpSlopeLookback], atr, InpSlopeLookback);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
