//+------------------------------------------------------------------+
//|                                                  KAMA_MTF_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Multi-Timeframe (MTF) version of Kaufman's Adaptive Moving Average (KAMA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "KAMA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\KAMA_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;
input int                       InpErPeriod       = 10;    // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;     // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;    // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferKAMA_MTF[];

//--- Global variables ---
CKamaCalculator *g_calculator;
bool             g_is_mtf_mode = false;
ENUM_TIMEFRAMES  g_calc_timeframe;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      Print("Error: The selected timeframe must be higher than or equal to the current chart timeframe.");
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

   SetIndexBuffer(0, BufferKAMA_MTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA_MTF,  false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CKamaCalculator_HA();
   else
      g_calculator = new CKamaCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod))
     {
      Print("Failed to initialize KAMA Calculator.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KAMA MTF%s(%s)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), EnumToString(g_calc_timeframe)));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("KAMA%s(%d,%d,%d)", (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpErPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { if(CheckPointer(g_calculator) != POINTER_INVALID) delete g_calculator; }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

   if(g_is_mtf_mode)
     {
      // --- MTF Mode ---
      int htf_rates_total = (int)SeriesInfoInteger(_Symbol, g_calc_timeframe, SERIES_BARS_COUNT);
      if(htf_rates_total < InpErPeriod)
         return 0;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 || CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 || CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return 0;

      double htf_kama_buffer[];
      ArrayResize(htf_kama_buffer, htf_rates_total);
      g_calculator.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_kama_buffer);

      ArraySetAsSeries(htf_kama_buffer, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferKAMA_MTF, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            BufferKAMA_MTF[i] = htf_kama_buffer[htf_bar_shift];
         else
            BufferKAMA_MTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferKAMA_MTF, false);
      ArraySetAsSeries(time, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferKAMA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
