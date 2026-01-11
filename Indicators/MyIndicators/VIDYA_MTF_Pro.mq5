//+------------------------------------------------------------------+
//|                                               VIDYA_MTF_Pro.mq5  |
//|                                     Copyright 2025, xxxxxxxx     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.30" // Unified MTF Engine Pattern
#property description "Multi-Timeframe (MTF) Variable Index Dynamic Average (VIDYA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "VIDYA MTF"

#include <MyIncludes\VIDYA_Calculator.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;

input group "VIDYA Settings"
input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA_MTF[];

//--- MTF Globals ---
double    g_htf_buffer[];
int       g_htf_prev_calculated = 0;
double    g_buf_open[], g_buf_high[], g_buf_low[], g_buf_close[];

//--- Global variables ---
CVIDYACalculator *g_calculator;
bool              g_is_mtf_mode = false;
ENUM_TIMEFRAMES   g_calc_timeframe;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      Print("Error: Target timeframe must be >= current timeframe.");
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

   SetIndexBuffer(0, BufferVIDYA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA_MTF, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYACalculator_HA();
   else
      g_calculator = new CVIDYACalculator();

   if(!g_calculator.Init(InpPeriodCMO, InpPeriodEMA))
      return(INIT_FAILED);

   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA%s(%d,%d)", tf_str, InpPeriodCMO, InpPeriodEMA));
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO + InpPeriodEMA);

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
   if(rates_total < 2)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferVIDYA_MTF);
      return(rates_total);
     }

// --- MTF Logic ---
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total < InpPeriodCMO + InpPeriodEMA)
      return 0;

   if(prev_calculated == 0)
     {
      g_htf_prev_calculated = 0;
      ArrayInitialize(BufferVIDYA_MTF, EMPTY_VALUE);
     }

   if(CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_open) < 0 ||
      CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_high) < 0 ||
      CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_low) < 0 ||
      CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_close) < 0)
     {
      return 0;
     }

   if(ArraySize(g_htf_buffer) != htf_rates_total)
      ArrayResize(g_htf_buffer, htf_rates_total);

   int htf_calc_start = (g_htf_prev_calculated > 0) ? g_htf_prev_calculated - 1 : 0;

   g_calculator.Calculate(htf_rates_total, htf_calc_start, price_type,
                          g_buf_open, g_buf_high, g_buf_low, g_buf_close,
                          g_htf_buffer);

   g_htf_prev_calculated = htf_rates_total;

// --- Mapping ---
   ArraySetAsSeries(g_htf_buffer, true); // Flip for mapping
   ArraySetAsSeries(time, false);

   int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = limit; i < rates_total; i++)
     {
      int htf_index = iBarShift(_Symbol, g_calc_timeframe, time[i], false);
      if(htf_index >= 0 && htf_index < htf_rates_total)
         BufferVIDYA_MTF[i] = g_htf_buffer[htf_index];
      else
         BufferVIDYA_MTF[i] = EMPTY_VALUE;
     }

   ArraySetAsSeries(g_htf_buffer, false); // Restore

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
