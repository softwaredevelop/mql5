//+------------------------------------------------------------------+
//|                                                 ALMA_MTF_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.20" // Unified MTF Engine Pattern
#property description "Multi-Timeframe (MTF) Arnaud Legoux Moving Average (ALMA)."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "ALMA MTF"

//--- Include the calculator engine ---
#include <MyIncludes\ALMA_Calculator.mqh>

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_H1;     // Target Timeframe

input group "ALMA Settings"
input int                       InpAlmaPeriod   = 9;       // Window size (period)
input double                    InpAlmaOffset   = 0.85;    // Offset (0 to 1)
input double                    InpAlmaSigma    = 6.0;     // Sigma (smoothness)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD; // Applied price

//--- Indicator Buffers ---
double    BufferALMA_MTF[];

//--- MTF Globals (State & Data) ---
double    g_htf_buffer[];       // Internal buffer for HTF calculation results
int       g_htf_prev_calculated = 0;
double    g_buf_open[], g_buf_high[], g_buf_low[], g_buf_close[]; // HTF Price Data

//--- Global variables ---
CALMACalculator *g_calculator;
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
   SetIndexBuffer(0, BufferALMA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferALMA_MTF, false); // Standard indexing
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CALMACalculator_HA();
   else
      g_calculator = new CALMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpAlmaPeriod, InpAlmaOffset, InpAlmaSigma))
     {
      Print("Failed to initialize ALMA Calculator.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ALMA%s%s(%d, %.2f, %.1f)", type, tf_str, InpAlmaPeriod, InpAlmaOffset, InpAlmaSigma));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpAlmaPeriod);
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
   if(rates_total < InpAlmaPeriod)
      return(0);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferALMA_MTF);
      return(rates_total);
     }

//================================================================
// MODE 2: Multi-Timeframe (MTF Engine)
//================================================================

//--- A. Get HTF Data Count
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total < InpAlmaPeriod)
      return(0);

//--- B. Reset HTF State if Full Recalculation needed
   if(prev_calculated == 0)
     {
      g_htf_prev_calculated = 0;
      ArrayInitialize(BufferALMA_MTF, EMPTY_VALUE);
     }

//--- C. Fetch HTF Price Data
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

//--- E. Calculate HTF ALMA (Incremental)
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
         BufferALMA_MTF[i] = g_htf_buffer[htf_index];
        }
      else
        {
         BufferALMA_MTF[i] = EMPTY_VALUE;
        }
     }

// CRITICAL: Restore HTF buffer to non-series for next calculation cycle
   ArraySetAsSeries(g_htf_buffer, false);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
