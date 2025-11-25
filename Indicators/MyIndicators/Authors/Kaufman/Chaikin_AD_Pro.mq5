//+------------------------------------------------------------------+
//|                                              Chaikin_AD_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Chaikin Accumulation/Distribution (A/D) Line."
#property description "Also known as Volume Accumulator."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "A/D Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\Chaikin_AD_Calculator.mqh>

//--- Input Parameters ---
input ENUM_APPLIED_VOLUME InpVolumeType  = VOLUME_TICK;    // Volume type to use
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferAD[];

//--- Global calculator object ---
CChaikinADCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpVolumeType == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) == 0)
     {
      Print("Error: Real Volume is not available for this symbol ('", _Symbol, "'). Please use Tick Volume.");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufferAD, INDICATOR_DATA);
   ArraySetAsSeries(BufferAD, false);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CChaikinADCalculator_HA();
   else
      g_calculator = new CChaikinADCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpVolumeType))
     {
      Print("Failed to initialize Chaikin A/D Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Chaikin A/D%s", (InpCandleSource == CANDLE_HEIKIN_ASHI ? " HA" : "")));
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   if(InpVolumeType == VOLUME_REAL)
      g_calculator.Calculate(rates_total, open, high, low, close, volume, BufferAD);
   else
      g_calculator.Calculate(rates_total, open, high, low, close, tick_volume, BufferAD);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
