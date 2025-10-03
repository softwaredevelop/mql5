//+------------------------------------------------------------------+
//|                                                       CCI_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00"
#property description "Professional CCI with MA signal line and optional Bollinger Bands."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_level1 -100.0
#property indicator_level2  100.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\CCI_Calculator.mqh>

//--- Plot Properties ---
#property indicator_label1  "CCI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
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
   DISPLAY_CCI_ONLY,
   DISPLAY_CCI_AND_MA,
   DISPLAY_CCI_AND_BANDS
  };

//--- Custom Enum for Price Source, including Heikin Ashi
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices
   PRICE_HA_CLOSE = -1,
   PRICE_HA_OPEN = -2,
   PRICE_HA_HIGH = -3,
   PRICE_HA_LOW = -4,
   PRICE_HA_MEDIAN = -5,
   PRICE_HA_TYPICAL = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices
   PRICE_CLOSE_STD = PRICE_CLOSE,
   PRICE_OPEN_STD = PRICE_OPEN,
   PRICE_HIGH_STD = PRICE_HIGH,
   PRICE_LOW_STD = PRICE_LOW,
   PRICE_MEDIAN_STD = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD = PRICE_WEIGHTED
  };

//--- Input Parameters ---
input group                     "CCI Settings"
input int                       InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_TYPICAL_STD;
input group                     "Overlay Settings"
input ENUM_DISPLAY_MODE         InpDisplayMode  = DISPLAY_CCI_AND_BANDS;
input int                       InpMAPeriod     = 14;
input ENUM_MA_METHOD            InpMAMethod     = MODE_SMA;
input int                       InpBandsPeriod  = 14;
input double                    InpBandsDev     = 2.0;

//--- Buffers ---
double BufferCCI[], BufferSignal[], BufferUpper[], BufferLower[];

//--- Global calculator ---
CCCI_Calculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCCI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   SetIndexBuffer(2, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(3, BufferLower,  INDICATOR_DATA);
   ArraySetAsSeries(BufferCCI,    false);
   ArraySetAsSeries(BufferSignal, false);
   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CCCI_Calculator_HA();
   else
      g_calculator = new CCCI_Calculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpCCIPeriod, InpMAPeriod, InpMAMethod, InpBandsPeriod, InpBandsDev))
     {
      Print("Failed to create or initialize CCI Calculator object.");
      return(INIT_FAILED);
     }

   int cci_draw_begin = InpCCIPeriod - 1;
   int ma_draw_begin = cci_draw_begin + InpMAPeriod - 1;
   int bands_draw_begin = cci_draw_begin + InpBandsPeriod - 1;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, cci_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ma_draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, bands_draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, bands_draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Pro(%d)", InpCCIPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, open, high, low, close, price_type, BufferCCI, BufferSignal, BufferUpper, BufferLower);

   for(int i=0; i<rates_total; i++)
     {
      if(InpDisplayMode == DISPLAY_CCI_ONLY)
        {
         BufferSignal[i]=EMPTY_VALUE;
         BufferUpper[i]=EMPTY_VALUE;
         BufferLower[i]=EMPTY_VALUE;
        }
      else
         if(InpDisplayMode == DISPLAY_CCI_AND_MA)
           {
            BufferUpper[i]=EMPTY_VALUE;
            BufferLower[i]=EMPTY_VALUE;
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
