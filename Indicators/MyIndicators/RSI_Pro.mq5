//+------------------------------------------------------------------+
//|                                                    RSI_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00" // Refactored to use MovingAverage_Engine
#property description "A professional, unified RSI with selectable price source (incl. Heikin Ashi),"
#property description "a flexible MA signal line, and optional Bollinger Bands."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

#include <MyIncludes\RSI_Pro_Calculator.mqh>

//--- Plot Properties ---
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1
#property indicator_label3  "Upper Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
#property indicator_label4  "Lower Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGray
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Enum for Display Mode
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_RSI_ONLY,
   DISPLAY_RSI_AND_MA,
   DISPLAY_RSI_AND_BANDS
  };

//--- Input Parameters ---
input group "RSI Settings"
input int                      InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Overlay Settings"
input ENUM_DISPLAY_MODE  InpDisplayMode  = DISPLAY_RSI_AND_BANDS;
input int                InpPeriodMA     = 20;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE       InpMethodMA     = SMA;
input double             InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferRSI[], BufferSignalMA[], BufferUpperBand[], BufferLowerBand[];

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSI,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalMA,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferUpperBand, INDICATOR_DATA);
   SetIndexBuffer(3, BufferLowerBand, INDICATOR_DATA);

   ArraySetAsSeries(BufferRSI,       false);
   ArraySetAsSeries(BufferSignalMA,  false);
   ArraySetAsSeries(BufferUpperBand, false);
   ArraySetAsSeries(BufferLowerBand, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIProCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Pro HA(%d)", InpPeriodRSI));
     }
   else
     {
      g_calculator = new CRSIProCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Pro(%d)", InpPeriodRSI));
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, InpBandsDev))
     {
      Print("Failed to initialize RSI Pro Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriodRSI + InpPeriodMA - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      ENUM_APPLIED_PRICE price_type;
      if(InpSourcePrice <= PRICE_HA_CLOSE)
         price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
      else
         price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                             BufferRSI, BufferSignalMA, BufferUpperBand, BufferLowerBand);

      if(InpDisplayMode == DISPLAY_RSI_ONLY)
        {
         ArrayInitialize(BufferSignalMA, EMPTY_VALUE);
         ArrayInitialize(BufferUpperBand, EMPTY_VALUE);
         ArrayInitialize(BufferLowerBand, EMPTY_VALUE);
        }
      else
         if(InpDisplayMode == DISPLAY_RSI_AND_MA)
           {
            ArrayInitialize(BufferUpperBand, EMPTY_VALUE);
            ArrayInitialize(BufferLowerBand, EMPTY_VALUE);
           }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
