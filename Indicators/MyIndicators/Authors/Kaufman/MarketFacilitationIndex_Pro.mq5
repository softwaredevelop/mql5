//+------------------------------------------------------------------+
//|                               MarketFacilitationIndex_Pro.mq5    |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Re-architected to 4-buffer histogram for color stability
#property description "Bill Williams' Market Facilitation Index (MFI / BW MFI)."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot Properties for 4 separate histograms ---
#property indicator_label1  "Green"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrGreen
#property indicator_width1  2
#property indicator_label2  "Fade"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrSaddleBrown
#property indicator_width2  2
#property indicator_label3  "Fake"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrBlue
#property indicator_width3  2
#property indicator_label4  "Squat"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrMagenta
#property indicator_width4  2

#include <MyIncludes\MarketFacilitationIndex_Calculator.mqh>

//--- Input Parameters ---
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferGreen[], BufferFade[], BufferFake[], BufferSquat[];

//--- Global calculator object ---
CMarketFacilitationIndexCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpVolumeType == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) == 0)
     {
      Print("Error: Real Volume is not available for this symbol. Please use Tick Volume.");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufferGreen, INDICATOR_DATA);
   SetIndexBuffer(1, BufferFade,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferFake,  INDICATOR_DATA);
   SetIndexBuffer(3, BufferSquat, INDICATOR_DATA);

   ArraySetAsSeries(BufferGreen, false);
   ArraySetAsSeries(BufferFade,  false);
   ArraySetAsSeries(BufferFake,  false);
   ArraySetAsSeries(BufferSquat, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, 1);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CMarketFacilitationIndexCalculator_HA();
   else
      g_calculator = new CMarketFacilitationIndexCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpVolumeType))
     {
      Print("Failed to initialize MFI Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MFI BW%s", (InpCandleSource == CANDLE_HEIKIN_ASHI ? " HA" : "")));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+2);

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
      g_calculator.Calculate(rates_total, open, high, low, close, volume, BufferGreen, BufferFade, BufferFake, BufferSquat);
   else
      g_calculator.Calculate(rates_total, open, high, low, close, tick_volume, BufferGreen, BufferFade, BufferFake, BufferSquat);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
