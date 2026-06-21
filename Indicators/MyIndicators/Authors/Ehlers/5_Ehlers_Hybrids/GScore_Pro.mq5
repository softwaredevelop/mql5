//+------------------------------------------------------------------+
//|                                                   GScore_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Dynamic G-Score statistical cycle oscillator
#property description "Professional G-Score (Ehlers 2-Pole Gaussian Z-Score)."
#property description "5-Zone logic: Neutral, Flow (Bull/Bear), Extreme (Bull/Bear) with dynamic Signal Line."
#property indicator_separate_window
#property indicator_buffers 3  // 3 buffers (G-Score + Color index + Signal Line)
#property indicator_plots   2  // 2 Plots (Histogram + Signal Line)

//--- Institutional Levels Configuration (Dynamic Sigma limits)
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5
#property indicator_level4 -1.5
#property indicator_level5 -2.0
#property indicator_level6 -2.5

#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Color Histogram (5-Zone Thermal Palette)
#property indicator_label1  "G-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line (Wyckoff Reversal Trigger)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\GScore_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input int                       InpPeriod       = 20;              // Gaussian Cutoff / Volatility Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Applied Price

//--- Signal Line Parameters (Dynamic MA Engine Integration)
input bool                      InpShowSignal   = true;            // Show Signal Line?
input int                       InpSignalPeriod = 5;               // Signal Line Period
input ENUM_MA_TYPE              InpSignalType   = SMA;             // Signal Line MA Type

//--- Buffers
double ExtGScoreBuffer[];
double ExtColorsBuffer[];
double ExtSignalBuffer[];

//--- Volume Cache to support Volume-Weighted types (VWMA) on custom arrays
double g_double_volume[];

//--- Global Engines
CGScoreCalculator        *g_calc;
CMovingAverageCalculator *g_signal_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind Buffers
   SetIndexBuffer(0, ExtGScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtSignalBuffer, INDICATOR_DATA);

   ArraySetAsSeries(ExtGScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);
   ArraySetAsSeries(ExtSignalBuffer, false);

//--- Configure Core G-Score Calculator
   bool use_ha = (InpSourcePrice <= PRICE_HA_CLOSE);
   g_calc = new CGScoreCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpPeriod, use_ha))
     {
      Print("Error: Failed to initialize GScore Calculator.");
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
         Print("Error: Failed to initialize Signal Line Calculator Engine.");
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
   string short_name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("G-Score Pro (%d%s) %s(%d)", InpPeriod, (use_ha ? " HA" : ""), sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = StringFormat("G-Score Pro (%d%s)", InpPeriod, (use_ha ? " HA" : ""));
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "G-Score");
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
   if(rates_total < InpPeriod + 5)
      return 0;

// Convert custom HA price mapping back to standard ENUM_APPLIED_PRICE
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

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
   g_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, ExtGScoreBuffer);

//--- 2. Calculate Optional Signal Line on top of G-Score values (Handles VWMA dynamically)
   if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
     {
      // Source start index is 'InpPeriod' since G-Score before that index is empty/unstable
      g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, ExtGScoreBuffer, g_double_volume, ExtSignalBuffer, InpPeriod);
     }

//--- 3. Apply 5-Zone Color Mapping Loop (O(1) incremental)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double v = ExtGScoreBuffer[i];

      //--- 5-Zone Thermal Color Mapping
      if(v >= 2.0)
         ExtColorsBuffer[i] = 2.0; // Bull Extreme (Hot) -> OrangeRed
      else
         if(v >= 1.5)
            ExtColorsBuffer[i] = 1.0; // Bull Flow (Warming) -> Coral
         else
            if(v <= -2.0)
               ExtColorsBuffer[i] = 4.0; // Bear Extreme (Freezing) -> DeepSkyBlue
            else
               if(v <= -1.5)
                  ExtColorsBuffer[i] = 3.0; // Bear Flow (Cooling) -> LightSkyBlue
               else
                  ExtColorsBuffer[i] = 0.0; // Noise -> Gray
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
