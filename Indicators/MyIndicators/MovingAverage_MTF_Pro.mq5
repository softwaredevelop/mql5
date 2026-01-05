//+------------------------------------------------------------------+
//|                                        MovingAverage_MTF_Pro.mq5 |
//|                                    Copyright 2025, xxxxxxxx      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Unified MTF Engine Pattern
#property description "Multi-Timeframe (MTF) Universal Moving Average."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "MA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1; // Target Timeframe

input group "MA Settings"
input int                       InpPeriod         = 20;
input ENUM_MA_TYPE              InpMAType         = SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMA_MTF[];

//--- MTF Globals ---
double    g_htf_buffer[];       // Internal buffer for HTF calculation
int       g_htf_prev_calculated = 0;
double    g_buf_open[], g_buf_high[], g_buf_low[], g_buf_close[]; // HTF Price Data

//--- Global variables ---
CMovingAverageCalculator *g_calculator;
bool                      g_is_mtf_mode = false;
ENUM_TIMEFRAMES           g_calc_timeframe;

//+------------------------------------------------------------------+
int OnInit()
  {
//--- 1. Resolve Timeframe
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      Print("Error: Target timeframe must be >= current timeframe.");
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Buffer Setup
   SetIndexBuffer(0, BufferMA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA_MTF, false); // Standard indexing
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageCalculator_HA();
   else
      g_calculator = new CMovingAverageCalculator();

   if(!g_calculator.Init(InpPeriod, InpMAType))
      return(INIT_FAILED);

//--- 4. Short Name
   string ma_name = EnumToString(InpMAType);
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";

   string short_name = StringFormat("%s%s%s(%d)", ma_name, type, tf_str, InpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

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

//================================================================
// MODE 1: Current Timeframe
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMA_MTF);
      return(rates_total);
     }

//================================================================
// MODE 2: MTF Engine
//================================================================

//--- A. Get HTF Data Count
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total < InpPeriod)
      return 0;

//--- B. Reset State on Full Recalc
   if(prev_calculated == 0)
     {
      g_htf_prev_calculated = 0;
      ArrayInitialize(BufferMA_MTF, EMPTY_VALUE);
     }

//--- C. Fetch HTF Data
   if(CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_open) < 0 ||
      CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_high) < 0 ||
      CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_low) < 0 ||
      CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_close) < 0)
     {
      return 0;
     }

//--- D. Resize HTF Buffer
   if(ArraySize(g_htf_buffer) != htf_rates_total)
      ArrayResize(g_htf_buffer, htf_rates_total);

//--- E. Calculate HTF (Incremental)
   int htf_calc_start = (g_htf_prev_calculated > 0) ? g_htf_prev_calculated - 1 : 0;

   g_calculator.Calculate(htf_rates_total, htf_calc_start, price_type,
                          g_buf_open, g_buf_high, g_buf_low, g_buf_close,
                          g_htf_buffer);

   g_htf_prev_calculated = htf_rates_total;

//--- F. Map to Current Chart (The Staircase)
// CRITICAL: Set HTF buffer as SERIES to match iBarShift (0 = Newest)
   ArraySetAsSeries(g_htf_buffer, true);

// Ensure 'time' is NOT series for our loop (0 = Oldest)
   ArraySetAsSeries(time, false);

   int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = limit; i < rates_total; i++)
     {
      datetime current_time = time[i];
      int htf_index = iBarShift(_Symbol, g_calc_timeframe, current_time, false);

      if(htf_index >= 0 && htf_index < htf_rates_total)
        {
         BufferMA_MTF[i] = g_htf_buffer[htf_index];
        }
      else
        {
         BufferMA_MTF[i] = EMPTY_VALUE;
        }
     }

// CRITICAL: Restore HTF buffer to non-series for next calculation
   ArraySetAsSeries(g_htf_buffer, false);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
