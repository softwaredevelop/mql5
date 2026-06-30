//+------------------------------------------------------------------+
//|                                                   LScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with 3-digit Gamma precision to support precise Fibonacci parameters
#property description "Statistical Laguerre Z-Score (L-Score) Oscillator with dynamic Signal Line."
#property description "Displays deviations from John Ehlers' Laguerre Filter in Sigma units."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: L-Score Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "L-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Palette Configuration:
// 0: Noise/Neutral     (Gray)
// 1: Bullish Flow      (LightSkyBlue)
// 2: Bullish Climax    (DeepSkyBlue)
// 3: Bearish Flow      (Coral)
// 4: Bearish Climax    (OrangeRed)
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\LScore_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input group "Laguerre Baseline Settings"
input double                    InpGamma       = 0.5;         // Laguerre Gamma (0.0 to 1.0, e.g. 0.236, 0.382)
input ENUM_APPLIED_PRICE_HA_ALL InpPrice       = PRICE_CLOSE_STD; // Price Source

input group "Volatility Settings"
input int                       InpPeriod      = 20;          // Sigma Lookback Period (N)

input group "Signal Line Settings"
input bool                      InpShowSignal  = true;        // Show Signal Line?
input int                       InpSignalPeriod= 5;           // Signal Line Period
input ENUM_MA_TYPE              InpSignalType  = SMA;         // Signal Line MA Type

input group "Indicator Levels"
input double                    InpLevelFlowHigh   = 2.0;         // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow    = -2.0;        // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh = 2.5;         // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow  = -2.5;        // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh= 3.0;         // High Exhaustion Level
input double                    InpLevelExtremeLow = -3.0;        // Low Exhaustion Level
input color                     InpLevelColor      = clrSilver;   // Levels Color
input ENUM_LINE_STYLE           InpLevelStyle      = STYLE_DOT;   // Levels Style

//--- Buffers ---
double BufferL[];
double BufferColors[];
double BufferSignal[];

//--- Volume Cache to support Volume-Weighted types (VWMA) on current timeframe
double g_double_volume[];

//--- Global Calculator Objects ---
CLScoreCalculator        *g_calculator;
CMovingAverageCalculator *g_signal_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind Buffers
   SetIndexBuffer(0, BufferL,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferL,      false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferSignal, false);

//--- Dynamically configure horizontal levels to support custom input parameters
   IndicatorSetInteger(INDICATOR_LEVELS, 6);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelFlowHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelFlowLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelClimaxHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelClimaxLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtremeHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, InpLevelExtremeLow);

   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

//--- Configure Core L-Score Calculator (Detects Heikin Ashi dynamically)
   bool is_ha = (InpPrice <= PRICE_HA_CLOSE);
   g_calculator = new CLScoreCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpGamma, InpPeriod, is_ha))
     {
      Print("Error: Failed to initialize L-Score Calculator Engine.");
      return INIT_FAILED;
     }

//--- Configure Optional Signal Line Calculator
   if(InpShowSignal)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(1, PLOT_LABEL, "Signal");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Error: Failed to initialize Signal Line Calculator.");
         return INIT_FAILED;
        }
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- Dynamically set indicator short name - Updated format string to %.3f to support exact Fibonacci decimals
   string short_name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("LScore%s(%.3f, %d) %s(%d)",
                                (is_ha ? " HA" : ""), InpGamma, InpPeriod, sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = StringFormat("LScore%s(%.3f, %d)", (is_ha ? " HA" : ""), InpGamma, InpPeriod);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "L-Score");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
      delete g_signal_calculator;
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
   if(rates_total < InpPeriod + 5)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpPrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpPrice) :
                                   (ENUM_APPLIED_PRICE)InpPrice;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Convert long volume to double cache array in O(1) incrementally (Required for Signal Line calculation)
   ArrayResize(g_double_volume, rates_total);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(volume_limit > 0)
     {
      for(int i = start_sync; i < rates_total; i++)
         g_double_volume[i] = (double)volume[i];
     }
   else
     {
      for(int i = start_sync; i < rates_total; i++)
         g_double_volume[i] = (double)tick_volume[i];
     }

//--- 1. Calculate L-Score using embedded Laguerre engine
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferL);

//--- 2. Calculate Optional Signal Line on top of L-Score values
   if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferL, g_double_volume, BufferSignal, InpPeriod - 1);
     }

//--- 3. Apply Dynamic 5-Zone Swapped Thermal Coloring Logic (O(1) incremental)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double l_val = BufferL[i];

      if(l_val > InpLevelClimaxHigh)
         BufferColors[i] = 2.0;
      else
         if(l_val > InpLevelFlowHigh)
            BufferColors[i] = 1.0;
         else
            if(l_val < InpLevelClimaxLow)
               BufferColors[i] = 4.0;
            else
               if(l_val < InpLevelFlowLow)
                  BufferColors[i] = 3.0;
               else
                  BufferColors[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
