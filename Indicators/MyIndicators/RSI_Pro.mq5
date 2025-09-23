//+------------------------------------------------------------------+
//|                                                    RSI_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00"
#property description "A professional, unified RSI with selectable price source (incl. Heikin Ashi),"
#property description "a flexible MA signal line, and optional Bollinger Bands."

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
#property indicator_width1  2
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

//--- Custom Enum for Price Source, including Heikin Ashi
enum ENUM_APPLIED_PRICE_HA
  {
   PRICE_HA_CLOSE = -1, // Heikin Ashi Close
   PRICE_CLOSE_STD = PRICE_CLOSE,
   PRICE_OPEN_STD = PRICE_OPEN,
   PRICE_HIGH_STD = PRICE_HIGH,
   PRICE_LOW_STD = PRICE_LOW,
   PRICE_MEDIAN_STD = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD = PRICE_WEIGHTED
  };

//--- Input Parameters ---
input group "RSI Settings"
input int                    InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA  InpSourcePrice  = PRICE_CLOSE_STD;

input group "Overlay Settings"
input ENUM_DISPLAY_MODE  InpDisplayMode  = DISPLAY_RSI_AND_BANDS;
input int                InpPeriodMA     = 20;
input ENUM_MA_METHOD     InpMethodMA     = MODE_SMA;
input double             InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferRSI[], BufferSignalMA[], BufferUpperBand[], BufferLowerBand[];

//--- Global calculator object (as a base class pointer) ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
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

//--- Dynamic Calculator Instantiation ---
   if(InpSourcePrice == PRICE_HA_CLOSE)
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
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      //--- The calculator will handle the price source internally
      g_calculator.Calculate(rates_total, (ENUM_APPLIED_PRICE)InpSourcePrice, open, high, low, close,
                             BufferRSI, BufferSignalMA, BufferUpperBand, BufferLowerBand);

      for(int i = 0; i < rates_total; i++)
        {
         if(InpDisplayMode == DISPLAY_RSI_ONLY)
           {
            BufferSignalMA[i] = EMPTY_VALUE;
            BufferUpperBand[i] = EMPTY_VALUE;
            BufferLowerBand[i] = EMPTY_VALUE;
           }
         else
            if(InpDisplayMode == DISPLAY_RSI_AND_MA)
              {
               BufferUpperBand[i] = EMPTY_VALUE;
               BufferLowerBand[i] = EMPTY_VALUE;
              }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
