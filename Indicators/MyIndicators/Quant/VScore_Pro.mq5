//+------------------------------------------------------------------+
//|                                                  VScore_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.20" // Upgraded with corrected color polarity, dynamic horizontal levels input panel, smoothed Signal line (with VWMA support) and chronological safety
#property description "Professional V-Score (VWAP Z-Score)."
#property description "5-Zone logic: Neutral, Flow (Bull/Bear), Extreme (Bull/Bear)"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: Color Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "V-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Swapped Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bullish Flow      (LightSkyBlue)
// 2: Bullish Climax    (DeepSkyBlue)
// 3: Bearish Flow      (Coral)
// 4: Bearish Climax    (OrangeRed)
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Smoothed Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters
input group                     "V-Score Settings"
input int                       InpPeriod         = 20;             // Volatility Lookback
input ENUM_VWAP_PERIOD          InpVWAPReset      = PERIOD_SESSION; // VWAP Anchor

input group                     "Signal Line Settings"
input bool                      InpShowSignal     = true;           // Show Signal Line?
input int                       InpSignalPeriod   = 5;              // Signal Line Period
input ENUM_MA_TYPE              InpSignalType     = SMA;            // Signal Line MA Type

input group                     "Indicator Levels"
input double                    InpLevelFlowHigh   = 1.5;         // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow    = -1.5;        // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh = 2.0;         // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow  = -2.0;        // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh= 2.5;         // High Exhaustion Level
input double                    InpLevelExtremeLow = -2.5;        // Low Exhaustion Level
input color                     InpLevelColor      = clrSilver;   // Levels Color
input ENUM_LINE_STYLE           InpLevelStyle      = STYLE_DOT;   // Levels Style

//--- Buffers
double ExtVScoreBuffer[];
double ExtColorsBuffer[];
double ExtSignalBuffer[];

//--- Volume Cache to support Volume-Weighted types (VWMA) on custom arrays
double g_double_volume[];

//--- Global Engines
CVScoreCalculator        *g_calc;
CMovingAverageCalculator *g_signal_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind Buffers
   SetIndexBuffer(0, ExtVScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtSignalBuffer, INDICATOR_DATA);

   ArraySetAsSeries(ExtVScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);
   ArraySetAsSeries(ExtSignalBuffer, false);

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

//--- Configure Core V-Score Calculator
   g_calc = new CVScoreCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, InpVWAPReset))
     {
      Print("Error: Failed to initialize VScore Calculator.");
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
         Print("Error: Failed to initialize Signal Line Calculator Engine.");
         return INIT_FAILED;
        }
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- Dynamically set the indicator short name
   string name = StringFormat("V-Score Pro(%d)", InpPeriod);
   string short_name = "";

   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("%s %s(%d)", name, sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = name;
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "V-Score");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) != POINTER_INVALID)
      delete g_calc;
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
   if(rates_total < InpPeriod)
      return 0;

   if(CheckPointer(g_calc) == POINTER_INVALID)
      return 0;

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//--- Convert long volume to double cache array in O(1) incrementally
   ArrayResize(g_double_volume, rates_total);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

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

//--- 1. Calculate Core Mathematical Values (O(1) Engine)
   g_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, ExtVScoreBuffer);

//--- 2. Calculate Optional Signal Line on top of V-Score values (Handles VWMA dynamically)
   if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, ExtVScoreBuffer, g_double_volume, ExtSignalBuffer, InpPeriod);
     }

//--- 3. Apply Dynamic 5-Zone Corrected Thermal Color Mapping Loop (O(1) incremental)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double v = ExtVScoreBuffer[i];

      //--- Swapped Corrected 5-Zone Thermal Color Mapping
      // Positive Deviation -> Bluish Upward Flow (Index 1 & 2)
      // Negative Deviation -> Reddish Downward Flow (Index 3 & 4)
      if(v >= InpLevelClimaxHigh)
         ExtColorsBuffer[i] = 2.0; // Index 2: DeepSkyBlue Climax (Bullish)
      else
         if(v >= InpLevelFlowHigh)
            ExtColorsBuffer[i] = 1.0; // Index 1: LightSkyBlue Flow (Bullish)
         else
            if(v <= InpLevelClimaxLow)
               ExtColorsBuffer[i] = 4.0; // Index 4: OrangeRed Climax (Bearish)
            else
               if(v <= InpLevelFlowLow)
                  ExtColorsBuffer[i] = 3.0; // Index 3: Coral Flow (Bearish)
               else
                  ExtColorsBuffer[i] = 0.0; // Index 0: Gray Neutral
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
