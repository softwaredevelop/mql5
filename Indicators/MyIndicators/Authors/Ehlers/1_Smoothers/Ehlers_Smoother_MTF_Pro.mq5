//+------------------------------------------------------------------+
//|                                     Ehlers_Smoother_MTF_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Multi-Timeframe (MTF) version of John Ehlers' Smoothers."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Smoother MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlueViolet
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT;
input ENUM_SMOOTHER_TYPE        InpSmootherType   = SUPERSMOOTHER;
input int                       InpPeriod         = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilterMTF[];

//--- Global variables ---
CEhlersSmootherCalculator *g_calculator;
bool                       g_is_mtf_mode = false;
ENUM_TIMEFRAMES            g_calc_timeframe;

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

   SetIndexBuffer(0, BufferFilterMTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilterMTF,  false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   string name = (InpSmootherType == SUPERSMOOTHER) ? "SuperSmoother" : "UltimateSmoother";
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CEhlersSmootherCalculator_HA();
   else
      g_calculator = new CEhlersSmootherCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpSmootherType, SOURCE_PRICE))
     {
      Print("Failed to initialize Ehlers Smoother Calculator.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s MTF(%s,%d)", name, EnumToString(g_calc_timeframe), InpPeriod));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s(%d)", name, InpPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
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
      if(htf_rates_total < InpPeriod + 3)
         return 0;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 || CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 || CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return 0;

      double htf_filter_buffer[];
      ArrayResize(htf_filter_buffer, htf_rates_total);
      g_calculator.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_filter_buffer);

      ArraySetAsSeries(htf_filter_buffer, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferFilterMTF, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            BufferFilterMTF[i] = htf_filter_buffer[htf_bar_shift];
         else
            BufferFilterMTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferFilterMTF, false);
      ArraySetAsSeries(time, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferFilterMTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
