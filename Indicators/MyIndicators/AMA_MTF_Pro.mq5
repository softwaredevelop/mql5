//+------------------------------------------------------------------+
//|                                                  AMA_MTF_Pro.mq5 |
//|                                     Copyright 2025, xxxxxxxx     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.00" // Unified MTF Engine Pattern
#property description "Multi-Timeframe (MTF) Adaptive Moving Average (AMA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "AMA MTF"

//--- Include the calculator engine ---
#include <MyIncludes\AMA_Calculator.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;     // Target Timeframe

input group "AMA Settings"
input int                       InpAmaPeriod      = 10;            // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;             // Fast EMA Period
input int                       InpSlowEmaPeriod  = 30;            // Slow EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD; // Price Source

//--- Indicator Buffers ---
double    BufferAMA_MTF[];

//--- MTF Globals (State & Data) ---
double    g_htf_buffer[];       // Internal buffer for HTF calculation results
int       g_htf_prev_calculated = 0;
double    g_buf_open[], g_buf_high[], g_buf_low[], g_buf_close[]; // HTF Price Data

//--- Global variables ---
CAMACalculator  *g_calculator;
bool             g_is_mtf_mode = false;
ENUM_TIMEFRAMES  g_calc_timeframe;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 1. Resolve Timeframe
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Setup Buffers
   SetIndexBuffer(0, BufferAMA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferAMA_MTF, false); // Standard indexing
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CAMACalculator_HA();
   else
      g_calculator = new CAMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod))
     {
      Print("Failed to initialize AMA Calculator.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AMA%s%s(%d,%d,%d)", type, tf_str, InpAmaPeriod, InpFastEmaPeriod, InpSlowEmaPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpAmaPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total < InpAmaPeriod)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferAMA_MTF);
      return(rates_total);
     }

//================================================================
// MODE 2: Multi-Timeframe (MTF Engine)
//================================================================

//--- A. Get HTF Data Count
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total < InpAmaPeriod)
      return(0);

//--- B. Reset HTF State if Full Recalculation needed
   if(prev_calculated == 0)
     {
      g_htf_prev_calculated = 0;
      ArrayInitialize(BufferAMA_MTF, EMPTY_VALUE);
     }

//--- C. Fetch HTF Price Data
// We check for < 0 to handle potential data access errors gracefully
   if(CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_open) < 0 ||
      CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_high) < 0 ||
      CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_low) < 0 ||
      CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_close) < 0)
     {
      return(0); // Data not ready
     }

//--- D. Resize HTF Buffer
   if(ArraySize(g_htf_buffer) != htf_rates_total)
      ArrayResize(g_htf_buffer, htf_rates_total);

//--- E. Calculate HTF AMA (Incremental)
// Step back 1 bar to ensure the open candle is always updated
   int htf_calc_start = (g_htf_prev_calculated > 0) ? g_htf_prev_calculated - 1 : 0;

   g_calculator.Calculate(htf_rates_total, htf_calc_start, price_type,
                          g_buf_open, g_buf_high, g_buf_low, g_buf_close,
                          g_htf_buffer);

   g_htf_prev_calculated = htf_rates_total;

//--- F. Map HTF Values to Current Chart (The "Staircase")

// CRITICAL: Set HTF buffer as SERIES for mapping
// This aligns index 0 with the newest bar, matching iBarShift behavior.
   ArraySetAsSeries(g_htf_buffer, true);

// Ensure 'time' array is NOT series for our loop (0 = Oldest)
   ArraySetAsSeries(time, false);

   int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = limit; i < rates_total; i++)
     {
      datetime current_time = time[i];

      // iBarShift returns the index relative to the newest bar (0 = Newest)
      int htf_index = iBarShift(_Symbol, g_calc_timeframe, current_time, false);

      if(htf_index >= 0 && htf_index < htf_rates_total)
        {
         BufferAMA_MTF[i] = g_htf_buffer[htf_index];
        }
      else
        {
         BufferAMA_MTF[i] = EMPTY_VALUE;
        }
     }

// CRITICAL: Restore HTF buffer to non-series for next calculation cycle
   ArraySetAsSeries(g_htf_buffer, false);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
