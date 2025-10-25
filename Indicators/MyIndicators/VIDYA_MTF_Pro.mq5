//+------------------------------------------------------------------+
//|                                               VIDYA_MTF_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.10" // REFACTORED: Handles current timeframe correctly.
#property description "Multi-Timeframe (MTF) Variable Index Dynamic Average (VIDYA)."
#property description "Displays VIDYA from a higher or the current timeframe on the chart."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "VIDYA MTF"

//--- Include the calculator engine ---
#include <MyIncludes\VIDYA_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT; // Default to current timeframe
input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA_MTF[];

//--- Global variables ---
CVIDYACalculator *g_calculator;
bool              g_is_mtf_mode = false;
ENUM_TIMEFRAMES   g_calc_timeframe;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
// --- Determine calculation mode (MTF or Current) ---
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
     {
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();
     }

   if(g_calc_timeframe < Period())
     {
      Print("Error: The selected timeframe must be higher than or equal to the current chart timeframe.");
      return(INIT_FAILED);
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// --- Standard buffer and calculator setup ---
   SetIndexBuffer(0, BufferVIDYA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA_MTF, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CVIDYACalculator_HA();
     }
   else
     {
      g_calculator = new CVIDYACalculator();
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO, InpPeriodEMA))
     {
      Print("Failed to create or initialize VIDYA Calculator object.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA MTF(%s,%d,%d)", EnumToString(g_calc_timeframe), InpPeriodCMO, InpPeriodEMA));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA(%d,%d)", InpPeriodCMO, InpPeriodEMA));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO + InpPeriodEMA);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
//| Custom indicator calculation function.                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

// --- Branching logic based on mode ---
   if(g_is_mtf_mode)
     {
      // --- MTF Mode ---
      int htf_rates_total = (int)SeriesInfoInteger(_Symbol, g_calc_timeframe, SERIES_BARS_COUNT);
      if(htf_rates_total < InpPeriodCMO + InpPeriodEMA)
         return 0;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 ||
         CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 ||
         CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
        {
         return 0; // Data not ready
        }

      double htf_vidya_buffer[];
      ArrayResize(htf_vidya_buffer, htf_rates_total);
      g_calculator.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_vidya_buffer);

      ArraySetAsSeries(htf_vidya_buffer, true);
      ArraySetAsSeries(htf_time, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferVIDYA_MTF, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            BufferVIDYA_MTF[i] = htf_vidya_buffer[htf_bar_shift];
         else
            BufferVIDYA_MTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferVIDYA_MTF, false);
      ArraySetAsSeries(time, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      // This is the simple logic from the original VIDYA_Pro.mq5
      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferVIDYA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
