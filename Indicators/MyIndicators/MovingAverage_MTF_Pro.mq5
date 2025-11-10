//+------------------------------------------------------------------+
//|                                        MovingAverage_MTF_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Multi-Timeframe (MTF) Universal Moving Average (SMA, EMA, SMMA, LWMA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "MA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT;
input int                       InpPeriod         = 20;
input ENUM_MA_TYPE              InpMAType         = SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMA_MTF[];

//--- Global variables ---
CMovingAverageCalculator *g_calculator;
bool                      g_is_mtf_mode = false;
ENUM_TIMEFRAMES           g_calc_timeframe;

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

   SetIndexBuffer(0, BufferMA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA_MTF, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageCalculator_HA();
   else
      g_calculator = new CMovingAverageCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Failed to initialize Moving Average Calculator.");
      return(INIT_FAILED);
     }

   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string short_name;
   if(g_is_mtf_mode)
      short_name = StringFormat("%s MTF%s(%s,%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), EnumToString(g_calc_timeframe), InpPeriod);
   else
      short_name = StringFormat("%s%s(%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
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
      if(htf_rates_total < InpPeriod)
         return 0;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 || CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 || CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return 0;

      double htf_ma_buffer[];
      ArrayResize(htf_ma_buffer, htf_rates_total);
      g_calculator.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_ma_buffer);

      ArraySetAsSeries(htf_ma_buffer, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferMA_MTF, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            BufferMA_MTF[i] = htf_ma_buffer[htf_bar_shift];
         else
            BufferMA_MTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferMA_MTF, false);
      ArraySetAsSeries(time, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      g_calculator.Calculate(rates_total, price_type, open, high, low, close, BufferMA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
