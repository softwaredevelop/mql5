//+------------------------------------------------------------------+
//|                                           Laguerre_Slope_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.40" // Upgraded with dynamic Volume-Weighted MA (VWMA) signal line support
#property description "Slope derivative of John Ehlers' Laguerre Filter with optional Signal MA."
#property description "Features a 5-zone symmetrical thermal color palette and dynamic volume cache."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Plot 1: Laguerre Slope (Color Histogram)
#property indicator_label1  "Laguerre Slope"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_color1  clrGray, clrMediumSeaGreen, clrPaleGreen, clrCrimson, clrLightCoral

//--- Plot 2: Moving Average Signal Line (Continuous Line)
#property indicator_label2  "Signal MA"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_color2  clrMaroon

//--- Included Engines
#include <MyIncludes\Laguerre_Slope_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input group "--- Laguerre Settings ---"
input double                    InpGamma         = 0.5;             // Laguerre Gamma (e.g. 0.236, 0.382, 0.618)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice   = PRICE_CLOSE_STD; // Price Source
input double                    InpThreshold     = 0.00005;         // Slope Neutral Threshold

input group "--- Signal MA Settings ---"
input bool                      InpShowSignal    = true;            // Show Signal MA Line?
input int                       InpSignalPeriod  = 5;               // Signal MA Period
input ENUM_MA_TYPE              InpSignalType    = EMA;             // Signal MA Type (Supports VWMA)

//--- Indicator Buffers ---
double    BufferSlope[];
double    BufferSlopeColor[];
double    BufferSignalMA[];

//--- Volume Cache to support Volume-Weighted types (VWMA)
double    g_double_volume[];

//--- Global Objects ---
CLaguerreSlopeCalculator *g_calculator;
CMovingAverageCalculator *g_ma_calc;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind buffers to index mapping
   SetIndexBuffer(0, BufferSlope,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferSlopeColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignalMA,   INDICATOR_DATA);

//--- Force strict chronological alignment (false = old to new)
   ArraySetAsSeries(BufferSlope,      false);
   ArraySetAsSeries(BufferSlopeColor, false);
   ArraySetAsSeries(BufferSignalMA,   false);

//--- Setup EMPTY_VALUE fallbacks for drawing safety
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- Initialize physical Laguerre Slope Calculator
   g_calculator = new CLaguerreSlopeCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to allocate Laguerre Slope Calculator memory.");
      return(INIT_FAILED);
     }

   if(!g_calculator.Init(InpGamma, SOURCE_PRICE, is_ha))
     {
      Print("Critical Error: Failed to initialize Laguerre Slope Calculator.");
      return(INIT_FAILED);
     }

//--- Initialize physical Signal MA Calculator
   g_ma_calc = new CMovingAverageCalculator();
   if(CheckPointer(g_ma_calc) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to allocate Signal MA Calculator memory.");
      return(INIT_FAILED);
     }

   if(!g_ma_calc.Init(InpSignalPeriod, InpSignalType))
     {
      Print("Critical Error: Failed to initialize Signal MA Calculator.");
      return(INIT_FAILED);
     }

//--- Dynamic Plot visibility and Shortname configuration
   string short_name = StringFormat("Laguerre Slope%s(%.3f, %.5f)",
                                    is_ha ? " HA" : "",
                                    InpGamma,
                                    InpThreshold);
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name += StringFormat(" | %s(%d)", sig_name, InpSignalPeriod);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

//--- Apply offsets and sub-point display settings for fractional precision
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSignalPeriod + 2);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   if(CheckPointer(g_ma_calc) != POINTER_INVALID)
      delete g_ma_calc;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
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
   if(rates_total < InpSignalPeriod + 5 || CheckPointer(g_calculator) == POINTER_INVALID || CheckPointer(g_ma_calc) == POINTER_INVALID)
      return 0;

//--- Chronological safeguarding of critical calculation arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//--- 1. Sync Volume to local double array incrementally (O(1)) for VWMA support
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

   if(ArraySize(g_double_volume) != rates_total)
     {
      ArrayResize(g_double_volume, rates_total);
      ArraySetAsSeries(g_double_volume, false);
     }

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

//--- 2. Handle negative-index Heikin Ashi pricing conversions transparently
   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

//--- 3. Calculate Laguerre Slope & Colors (O(1) incremental update)
   g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                          BufferSlope, BufferSlopeColor, InpThreshold);

//--- 4. Calculate or Clear Signal MA Line
   if(InpShowSignal)
     {
      // VWMA calculations are handled seamlessly by passing the synced g_double_volume array
      g_ma_calc.CalculateOnArray(rates_total, prev_calculated, BufferSlope, g_double_volume, BufferSignalMA, 1);
     }
   else
     {
      // If disabled, dynamically wipe the buffer using optimized incremental loop
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start_index; i < rates_total; i++)
         BufferSignalMA[i] = EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
