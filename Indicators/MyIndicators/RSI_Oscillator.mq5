//+------------------------------------------------------------------+
//|                                               RSI_Oscillator.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00"
#property description "RSI Oscillator (Histogram of RSI vs Signal Line) with selectable price source."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  2
#property indicator_label1  "RSI Oscillator"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

#include <MyIncludes\RSI_Pro_Calculator.mqh>

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
input int                      InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;
input group                    "Signal Line Settings"
input int                      InpPeriodMA     = 14;
input ENUM_MA_METHOD           InpMethodMA     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CRSIProCalculator_HA();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Osc HA(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }
   else
     {
      g_calculator = new CRSIProCalculator();
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Osc(%d,%d)", InpPeriodRSI, InpPeriodMA));
     }

//--- We pass a dummy deviation value (0.0) as it's not used for the oscillator
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, 0.0))
     {
      Print("Failed to initialize RSI Pro Calculator for Oscillator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI + InpPeriodMA - 1);
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
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Step 1: Use the Pro calculator to get the core RSI and MA values
   double rsi_buffer[], ma_buffer[], dummy_upper[], dummy_lower[];
   ArrayResize(rsi_buffer, rates_total);
   ArrayResize(ma_buffer, rates_total);
   ArrayResize(dummy_upper, rates_total);
   ArrayResize(dummy_lower, rates_total);

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   g_calculator.Calculate(rates_total, price_type, open, high, low, close,
                          rsi_buffer, ma_buffer, dummy_upper, dummy_lower);

//--- Step 2: Calculate the final Oscillator value (RSI - MA)
   int start_pos = InpPeriodRSI + InpPeriodMA - 1;
   for(int i = start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = rsi_buffer[i] - ma_buffer[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
