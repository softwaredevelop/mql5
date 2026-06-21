//+------------------------------------------------------------------+
//|                                                   ZScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.40" // Upgraded with dynamic MA type selectors and volume support
#property description "Statistical Z-Score Oscillator."
#property description "Displays deviations from any selected Moving Average in Sigma units."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Institutional Levels Configuration (Sigma boundaries)
#property indicator_level1 2.0
#property indicator_level2 -2.0
#property indicator_level3 3.0
#property indicator_level4 -3.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Z-Score Histogram (Colored)
#property indicator_label1  "Z-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Color Index: 0=Normal, 1=High(Red), 2=Low(Lime)
#property indicator_color1  clrGray, clrOrangeRed, clrSpringGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\ZScore_Calculator.mqh>

//--- Input Parameters
input int                       InpPeriod      = 20;          // Lookback Period
input ENUM_MA_TYPE              InpMAType      = SMA;         // Moving Average Type
input ENUM_APPLIED_PRICE        InpPrice       = PRICE_CLOSE; // Applied Price

//--- Buffers
double BufferZ[];
double BufferColors[];

//--- Global Calculator Object
CZScoreCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferZ, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferZ, false);
   ArraySetAsSeries(BufferColors, false);

//--- Dynamically set the indicator name based on MA selection
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);

   string short_name = StringFormat("ZScore(%d, %s)", InpPeriod, ma_name);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Z-Score");
   IndicatorSetInteger(INDICATOR_DIGITS, 2); // Z-Score usually has 2 decimals (e.g., 1.96)

   g_calculator = new CZScoreCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Error: Failed to initialize ZScore Calculator Engine.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
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
   if(rates_total < InpPeriod)
      return 0;

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Route calculations dynamically to support volume-weighted types (VWMA)
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, volume, BufferZ);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, tick_volume, BufferZ);
     }

//--- 2. Apply Dynamic Coloring Logic (O(1) incremental)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double z = BufferZ[i];

      // Color Logic:
      // > 2.0  -> OrangeRed (Extreme High / Overbought)
      // < -2.0 -> SpringGreen (Extreme Low / Oversold)
      // Else   -> Gray (Normal Noise Zone)
      if(z > 2.0)
         BufferColors[i] = 1.0; // Index 1: OrangeRed
      else
         if(z < -2.0)
            BufferColors[i] = 2.0; // Index 2: SpringGreen
         else
            BufferColors[i] = 0.0; // Index 0: Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
