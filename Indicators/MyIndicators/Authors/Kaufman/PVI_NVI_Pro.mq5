//+------------------------------------------------------------------+
//|                                                  PVI_NVI_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Added signal lines and display modes
#property description "Positive Volume Index (PVI) and Negative Volume Index (NVI)."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot 1: PVI
#property indicator_label1  "PVI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- Plot 2: NVI
#property indicator_label2  "NVI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
//--- Plot 3: PVI Signal
#property indicator_label3  "PVI Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCornflowerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
//--- Plot 4: NVI Signal
#property indicator_label4  "NVI Signal"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrTomato
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#include <MyIncludes\PVI_NVI_Calculator.mqh>

enum ENUM_PVINVI_DISPLAY { DISPLAY_PVI_ONLY, DISPLAY_NVI_ONLY, DISPLAY_BOTH };

//--- Input Parameters ---
input group "Display & Signal Line"
input ENUM_PVINVI_DISPLAY InpDisplayMode  = DISPLAY_NVI_ONLY;
input int                 InpSignalPeriod = 255; // Default to ~1 year for NVI
input ENUM_MA_TYPE        InpSignalMAType = SMA;
input group "Source Settings"
input ENUM_APPLIED_VOLUME InpVolumeType   = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferPVI[], BufferNVI[], BufferPVISignal[], BufferNVISignal[];

//--- Global calculator object ---
CPVINVICalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpVolumeType == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) == 0)
     {
      Print("Error: Real Volume is not available for this symbol. Please use Tick Volume.");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufferPVI,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferNVI,       INDICATOR_DATA);
   SetIndexBuffer(2, BufferPVISignal, INDICATOR_DATA);
   SetIndexBuffer(3, BufferNVISignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferPVI, false);
   ArraySetAsSeries(BufferNVI, false);
   ArraySetAsSeries(BufferPVISignal, false);
   ArraySetAsSeries(BufferNVISignal, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CPVINVICalculator_HA();
   else
      g_calculator = new CPVINVICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpVolumeType, InpSignalPeriod, InpSignalMAType))
     {
      Print("Failed to initialize PVI/NVI Calculator.");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PVI/NVI%s", (InpCandleSource == CANDLE_HEIKIN_ASHI ? " HA" : "")));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   int draw_begin = 1 + InpSignalPeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);

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
      g_calculator.Calculate(rates_total, open, high, low, close, volume, BufferPVI, BufferNVI, BufferPVISignal, BufferNVISignal);
   else
      g_calculator.Calculate(rates_total, open, high, low, close, tick_volume, BufferPVI, BufferNVI, BufferPVISignal, BufferNVISignal);

   if(InpDisplayMode == DISPLAY_PVI_ONLY)
     {
      ArrayInitialize(BufferNVI, EMPTY_VALUE);
      ArrayInitialize(BufferNVISignal, EMPTY_VALUE);
     }
   else
      if(InpDisplayMode == DISPLAY_NVI_ONLY)
        {
         ArrayInitialize(BufferPVI, EMPTY_VALUE);
         ArrayInitialize(BufferPVISignal, EMPTY_VALUE);
        }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
