//+------------------------------------------------------------------+
//|                                  Laguerre_Adaptive_Channel_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.20" // Enterprise Refactor: Zero-Lag MTF Fast-Path & Fused Memory
#property description "Volatility channel around John Ehlers' Adaptive Laguerre Filter baseline."
#property description "Supports ER, ATR, and Standard Deviation dynamic bands with Native & MTF Support."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Adaptive Baseline (Keltner Median Line)
#property indicator_label1  "Adaptive Baseline"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Upper Volatility Band
#property indicator_label2  "Upper Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSlateGray
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Lower Volatility Band
#property indicator_label3  "Lower Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSlateGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\Laguerre_Adaptive_Channel_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;       // Target Higher Timeframe

input group "--- Adaptive Baseline Settings ---"
input ENUM_ADAPTIVE_METHOD      InpAdaptiveMethod = METHOD_EFFICIENCY_RATIO; // Adaptive Baseline Method
input int                       InpAdaptivePeriod = 10;                  // Volatility/ER/StDev Period
input double                    InpGammaMin       = 0.136;               // Minimum Gamma (Max Speed)
input double                    InpGammaMax       = 0.882;               // Maximum Gamma (Max Smooth)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice     = PRICE_CLOSE_STD;     // Price Source

input group "--- Channel Width Settings ---"
input ENUM_CHANNEL_WIDTH_METHOD InpWidthMethod    = WIDTH_METHOD_ATR;    // Volatility Band Method (ATR/StDev)
input int                       InpWidthPeriod    = 10;                  // Volatility Band Lookback Period
input double                    InpMultiplier     = 2.0;                 // Volatility Band Multiplier

//--- Visual Indicator Buffers ---
double    BufferBaseline[];
double    BufferUpper[];
double    BufferLower[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_baseline[], h_res_upper[], h_res_lower[];
datetime  h_time[];

//--- Global Objects & State Management
CLaguerreAdaptiveChannelCalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Buffers
   SetIndexBuffer(0, BufferBaseline, INDICATOR_DATA);
   SetIndexBuffer(1, BufferUpper,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferLower,    INDICATOR_DATA);

   ArraySetAsSeries(BufferBaseline, false);
   ArraySetAsSeries(BufferUpper,    false);
   ArraySetAsSeries(BufferLower,    false);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

// 3. Initialize Physical Adaptive Channel Calculator
   g_calculator = new CLaguerreAdaptiveChannelCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpAdaptiveMethod, InpAdaptivePeriod, InpGammaMin, InpGammaMax,
                         InpWidthMethod, InpWidthPeriod, InpMultiplier, is_ha))
     {
      Print("Critical Error: Failed to allocate or initialize Adaptive Channel Calculator.");
      return(INIT_FAILED);
     }

// 4. Dynamic Setup of Indicator Shortname
   string method_str = "";
   switch(InpAdaptiveMethod)
     {
      case METHOD_EFFICIENCY_RATIO:
         method_str = "ER";
         break;
      case METHOD_ATR:
         method_str = "ATR";
         break;
      case METHOD_STAND_DEV:
         method_str = "StDev";
         break;
     }

   string width_str = (InpWidthMethod == WIDTH_METHOD_ATR) ? "ATR" : "StDev";
   string tf_str    = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Laguerre Adaptive Channel%s%s(%s,%s,%.1f)",
                                    is_ha ? " HA" : "",
                                    tf_str,
                                    method_str,
                                    width_str,
                                    InpMultiplier);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   int draw_begin = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 10;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
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
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 15;
   if(rates_total < required_bars || !g_calculator)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                             BufferBaseline, BufferUpper, BufferLower);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform full history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      ArrayResize(h_time,         g_htf_count);
      ArrayResize(h_open,         g_htf_count);
      ArrayResize(h_high,         g_htf_count);
      ArrayResize(h_low,          g_htf_count);
      ArrayResize(h_close,        g_htf_count);
      ArrayResize(h_res_baseline, g_htf_count);
      ArrayResize(h_res_upper,    g_htf_count);
      ArrayResize(h_res_lower,    g_htf_count);

      ArraySetAsSeries(h_time,         false);
      ArraySetAsSeries(h_open,         false);
      ArraySetAsSeries(h_high,         false);
      ArraySetAsSeries(h_low,          false);
      ArraySetAsSeries(h_close,        false);
      ArraySetAsSeries(h_res_baseline, false);
      ArraySetAsSeries(h_res_upper,    false);
      ArraySetAsSeries(h_res_lower,    false);

      // Atomic bulk rates copy (Single API call replaces 5 calls!)
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
        }

      // Compute HTF Adaptive Channel Values across history
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_res_baseline, h_res_upper, h_res_lower);
      g_data_ready = true;

      // Full Historical Projection to Chart Buffers (Only on new HTF candle)
      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);
         if(shift_htf >= 0)
           {
            int idx_htf = g_htf_count - 1 - shift_htf;
            if(idx_htf >= 0 && idx_htf < g_htf_count)
              {
               BufferBaseline[i] = h_res_baseline[idx_htf];
               BufferUpper[i]    = h_res_upper[idx_htf];
               BufferLower[i]    = h_res_lower[idx_htf];
              }
            else
              {
               BufferBaseline[i] = EMPTY_VALUE;
               BufferUpper[i] = EMPTY_VALUE;
               BufferLower[i] = EMPTY_VALUE;
              }
           }
         else
           {
            BufferBaseline[i] = EMPTY_VALUE;
            BufferUpper[i] = EMPTY_VALUE;
            BufferLower[i] = EMPTY_VALUE;
           }
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update strictly forming block!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      // Single atomic API call instead of 4 separate copies!
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         // Mock update strictly on forming candle
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_res_baseline, h_res_upper, h_res_lower);
        }
     }

// Instant Binary Search for Forming Block Start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Direct Vectorized Assignment (Zero API calls, Nanosecond Execution across 3 buffers)
   double base_val  = h_res_baseline[live_idx];
   double upper_val = h_res_upper[live_idx];
   double lower_val = h_res_lower[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferBaseline[i] = base_val;
      BufferUpper[i]    = upper_val;
      BufferLower[i]    = lower_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = MathMax(InpAdaptivePeriod * 2, InpWidthPeriod) + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
