//+------------------------------------------------------------------+
//|                                                  MAMA_MTF_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.10" // REFACTORED: Handles current timeframe correctly.
#property description "Multi-Timeframe (MTF) version of John Ehlers' MAMA and FAMA."
#property description "Displays MAMA/FAMA from a higher or the current timeframe on the chart."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MAMA
#property indicator_label1  "MAMA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: FAMA
#property indicator_label2  "FAMA MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MyIncludes\MAMA_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT; // Default to current timeframe
input double                    InpFastLimit    = 0.5;   // Fast Limit for Alpha
input double                    InpSlowLimit    = 0.05;  // Slow Limit for Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMAMA_MTF[];
double    BufferFAMA_MTF[];

//--- Global variables ---
CMAMACalculator  *g_calculator;
bool              g_is_mtf_mode = false;
ENUM_TIMEFRAMES   g_calc_timeframe;

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
      Print("Error: The selected timeframe must be lower than the current chart timeframe.");
      return(INIT_FAILED);
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// --- Standard buffer and calculator setup ---
   SetIndexBuffer(0, BufferMAMA_MTF,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA_MTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA_MTF,  false);
   ArraySetAsSeries(BufferFAMA_MTF,  false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_calculator = new CMAMACalculator_HA();
     }
   else
     {
      g_calculator = new CMAMACalculator();
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to create or initialize MAMA Calculator object.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA MTF(%s)", EnumToString(g_calc_timeframe)));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 50);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 50);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

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
      if(htf_rates_total < 50)
         return 0; // MAMA warmup period

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 ||
         CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 ||
         CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
        {
         return 0; // Data not fully ready
        }

      double htf_mama_buffer[], htf_fama_buffer[];
      ArrayResize(htf_mama_buffer, htf_rates_total);
      ArrayResize(htf_fama_buffer, htf_rates_total);

      g_calculator.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_mama_buffer, htf_fama_buffer);

      ArraySetAsSeries(htf_mama_buffer, true);
      ArraySetAsSeries(htf_fama_buffer, true);
      ArraySetAsSeries(htf_time, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferMAMA_MTF, true);
      ArraySetAsSeries(BufferFAMA_MTF, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
           {
            BufferMAMA_MTF[i] = htf_mama_buffer[htf_bar_shift];
            BufferFAMA_MTF[i] = htf_fama_buffer[htf_bar_shift];
           }
         else
           {
            BufferMAMA_MTF[i] = EMPTY_VALUE;
            BufferFAMA_MTF[i] = EMPTY_VALUE;
           }
        }

      ArraySetAsSeries(BufferMAMA_MTF, false);
      ArraySetAsSeries(BufferFAMA_MTF, false);
      ArraySetAsSeries(time, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMAMA_MTF, BufferFAMA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
