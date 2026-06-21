//+------------------------------------------------------------------+
//|                                                   ZScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.70" // Integrated double-volume array translation to support VWMA Signal lines
#property description "Statistical Z-Score Oscillator with dynamic Signal Line."
#property description "Displays deviations from any selected Moving Average in Sigma units."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Institutional Levels Configuration (6 Sigma boundaries)
#property indicator_level1 2.0
#property indicator_level2 -2.0
#property indicator_level3 2.5
#property indicator_level4 -2.5
#property indicator_level5 3.0
#property indicator_level6 -3.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Z-Score Histogram (5-Zone Thermal Palette)
#property indicator_label1  "Z-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// 5-Color Palette:
// 0: Noise/Neutral     (Gray)
// 1: Warning High      (Coral)
// 2: Extreme High      (OrangeRed)
// 3: Warning Low       (LightSkyBlue)
// 4: Extreme Low       (DeepSkyBlue)
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line (Wyckoff Reversal Trigger)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\ZScore_Calculator.mqh>

//--- Input Parameters ---
input int                       InpPeriod      = 20;          // Z-Score Lookback Period
input ENUM_MA_TYPE              InpMAType      = SMA;         // Z-Score MA Type
input ENUM_APPLIED_PRICE        InpPrice       = PRICE_CLOSE; // Z-Score Applied Price

//--- Signal Line Parameters
input bool                      InpShowSignal  = true;        // Show Signal Line?
input int                       InpSignalPeriod= 5;           // Signal Line Period
input ENUM_MA_TYPE              InpSignalType  = SMA;         // Signal Line MA Type

//--- Buffers ---
double BufferZ[];
double BufferColors[];
double BufferSignal[];

//--- Volume Cache to support Volume-Weighted types (VWMA) on custom arrays
double g_double_volume[];

//--- Global Calculator Objects ---
CZScoreCalculator        *g_calculator;
CMovingAverageCalculator *g_signal_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind Buffers
   SetIndexBuffer(0, BufferZ,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferZ,      false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferSignal, false);

//--- Configure Core Z-Score Calculator
   g_calculator = new CZScoreCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Error: Failed to initialize ZScore Calculator Engine.");
      return INIT_FAILED;
     }

//--- Configure Optional Signal Line Calculator
   if(InpShowSignal)
     {
      // Explicitly restore DRAW_LINE & Label in case it was previously disabled
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
      // Set DRAW_NONE and clear Label to fully purge it from the MT5 Data Window
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- Dynamically set the indicator short name
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);

   string short_name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("ZScore(%d, %s) %s(%d)", InpPeriod, ma_name, sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = StringFormat("ZScore(%d, %s)", InpPeriod, ma_name);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Z-Score");
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
   if(rates_total < InpPeriod)
      return 0;

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- Convert long volume to double cache array in O(1) incrementally
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

//--- 1. Calculate Core Z-Score (Handles VWMA volume integration dynamically)
   if(volume_limit > 0)
     {
      g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, volume, BufferZ);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, InpPrice, open, high, low, close, tick_volume, BufferZ);
     }

//--- 2. Calculate Optional Signal Line on top of Z-Score values
   if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      // Source start index is 'InpPeriod - 1' since Z-Score before that index is invalid/empty
      // FIXED: Passed g_double_volume down to ensure VWMA signal line type calculates correctly
      g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufferZ, g_double_volume, BufferSignal, InpPeriod - 1);
     }

//--- 3. Apply 5-Zone Thermal Coloring Logic (O(1) incremental)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
     {
      double z = BufferZ[i];

      // 5-Zone Thermal Coloring:
      // Z > 2.5  -> OrangeRed (Extreme High / Sell Reversal Zone)
      // Z > 2.0  -> Coral (Warning High / Caution Zone)
      // Z < -2.5 -> DeepSkyBlue (Extreme Low / Buy Reversal Zone)
      // Z < -2.0 -> LightSkyBlue (Warning Low / Caution Zone)
      // Else     -> Gray (Neutral Noise Zone)
      if(z > 2.5)
         BufferColors[i] = 2.0; // Index 2: OrangeRed
      else
         if(z > 2.0)
            BufferColors[i] = 1.0; // Index 1: Coral
         else
            if(z < -2.5)
               BufferColors[i] = 4.0; // Index 4: DeepSkyBlue
            else
               if(z < -2.0)
                  BufferColors[i] = 3.0; // Index 3: LightSkyBlue
               else
                  BufferColors[i] = 0.0; // Index 0: Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
