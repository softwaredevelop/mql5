//+------------------------------------------------------------------+
//|                                                      CMO_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // Refactored to match RSI_Pro architecture
#property description "Chande Momentum Oscillator (CMO) with selectable price source,"
#property description "a flexible MA signal line, and optional Bollinger Bands."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_minimum -100
#property indicator_maximum 100
#property indicator_level1 50.0
#property indicator_level2 0.0
#property indicator_level3 -50.0

#include <MyIncludes\CMO_Calculator.mqh>

//--- Plot Properties ---
#property indicator_label1  "CMO"
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
   DISPLAY_CMO_ONLY,
   DISPLAY_CMO_AND_MA,
   DISPLAY_CMO_AND_BANDS
  };

//--- Input Parameters ---
input group "CMO Settings"
input int                       InpPeriodCMO    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

input group "Overlay Settings"
input ENUM_DISPLAY_MODE         InpDisplayMode  = DISPLAY_CMO_AND_BANDS;
input int                       InpPeriodMA     = 20;
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE              InpMethodMA     = SMA;
input double                    InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferCMO[], BufferSignalMA[], BufferUpperBand[], BufferLowerBand[];

//--- Global calculator object ---
CCMOCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Binding Buffers
   SetIndexBuffer(0, BufferCMO,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalMA,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferUpperBand, INDICATOR_DATA);
   SetIndexBuffer(3, BufferLowerBand, INDICATOR_DATA);

//--- Setting Series flags
   ArraySetAsSeries(BufferCMO,       false);
   ArraySetAsSeries(BufferSignalMA,  false);
   ArraySetAsSeries(BufferUpperBand, false);
   ArraySetAsSeries(BufferLowerBand, false);

//--- Initialize Calculator based on Price Source
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CCMOCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CMO Pro HA(%d)", InpPeriodCMO));
     }
   else
     {
      g_calculator = new CCMOCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CMO Pro(%d)", InpPeriodCMO));
     }

//--- Initialize Calculator Parameters
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodCMO, InpPeriodMA, InpMethodMA, InpBandsDev))
     {
      Print("Failed to initialize CMO Pro Calculator.");
      return(INIT_FAILED);
     }

//--- Set Draw Begin
   int draw_begin = InpPeriodCMO + InpPeriodMA - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
//| Custom indicator calculation function                            |
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

      //--- Main Calculation
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                             BufferCMO, BufferSignalMA, BufferUpperBand, BufferLowerBand);

      //--- Handle Display Modes (Hide unused buffers)
      if(InpDisplayMode == DISPLAY_CMO_ONLY)
        {
         ArrayInitialize(BufferSignalMA, EMPTY_VALUE);
         ArrayInitialize(BufferUpperBand, EMPTY_VALUE);
         ArrayInitialize(BufferLowerBand, EMPTY_VALUE);
        }
      else
         if(InpDisplayMode == DISPLAY_CMO_AND_MA)
           {
            ArrayInitialize(BufferUpperBand, EMPTY_VALUE);
            ArrayInitialize(BufferLowerBand, EMPTY_VALUE);
           }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+