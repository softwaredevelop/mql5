//+------------------------------------------------------------------+
//|                                   VolumePressure_Candles_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Volume Pressure Candles (Main Chart Overlay)."
#property description "Colors standard candles based on buying/selling pressure intensity."

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1

//--- Plot 1: Color Candles
#property indicator_label1  "VP Open;VP High;VP Low;VP Close"
#property indicator_type1   DRAW_COLOR_CANDLES
// 4-Color Heatmap Palette:
// 0: Strong Bull (Lime)
// 1: Weak Bull (ForestGreen)
// 2: Weak Bear (FireBrick)
// 3: Strong Bear (Red)
#property indicator_color1  clrLime, clrForestGreen, clrFireBrick, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\VolumePressure_Calculator.mqh>

//--- Input Parameters
input int InpSmoothPeriod = 1; // Smoothing (1 = Raw Pressure)

//--- Buffers for Drawing Candles
double BufOpen[];
double BufHigh[];
double BufLow[];
double BufClose[];
double BufColor[];

//--- Hidden Buffer for Mathematical Calculation
double BufMath[];

//--- Global Engine
CVolumePressureCalculator *g_calc;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// Bind Drawing Buffers (Must be strictly O, H, L, C, Color)
   SetIndexBuffer(0, BufOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, BufHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, BufLow,   INDICATOR_DATA);
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX);

// Bind Hidden Math Buffer
   SetIndexBuffer(5, BufMath,  INDICATOR_CALCULATIONS);

   string name = (InpSmoothPeriod > 1) ? StringFormat("VP Candles(EMA%d)", InpSmoothPeriod) : "VP Candles(Raw)";
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// Prevent drawing zero-values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_calc = new CVolumePressureCalculator();
   if(!g_calc.Init(InpSmoothPeriod))
     {
      Print("Error: Failed to initialize Volume Pressure Engine.");
      return INIT_FAILED;
     }

// Optional: Force chart to show candles
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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
   if(rates_total < 2)
      return 0;

// 1. Calculate Core Mathematical Values (-1.0 to 1.0) via Engine
   g_calc.Calculate(rates_total, prev_calculated, high, low, close, BufMath);

// 2. Map standard OHLC data and apply Color Logic (O(1) incremental)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      // Copy physical candle dimensions
      BufOpen[i]  = open[i];
      BufHigh[i]  = high[i];
      BufLow[i]   = low[i];
      BufClose[i] = close[i];

      // Extract pressure metric
      double pressure = BufMath[i];

      // 4-Zone Heatmap Logic
      if(pressure >= 0.5)
         BufColor[i] = 0.0; // Strong Bull (Climax/Control) -> Lime
      else
         if(pressure >= 0.0)
            BufColor[i] = 1.0; // Weak Bull -> ForestGreen
         else
            if(pressure > -0.5)
               BufColor[i] = 2.0; // Weak Bear -> FireBrick
            else
               BufColor[i] = 3.0; // Strong Bear (Climax/Control) -> Red
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
