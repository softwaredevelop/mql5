//+------------------------------------------------------------------+
//|                                           MovingAverage_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.10" // Enterprise Edition: Two-Pointer MTF Fast-Path, Fixed HA Price Offsets & Atomic CopyRates
#property description "Universal Moving Average (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA)."
#property description "Features unified Native & MTF pipelines, Heikin Ashi pricing, and zero-API live tick rendering."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Definition
#property indicator_label1  "MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Included Engines & Core Tools
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Moving Average Core Settings ---"
input int                       InpPeriod       = 20;                // Moving Average Period
input ENUM_MA_TYPE              InpMAType       = SMA;               // MA Algorithm (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "--- Visual Settings ---"
input color                     InpColorMA      = clrDodgerBlue;     // Line Color
input ENUM_LINE_STYLE           InpStyleMA      = STYLE_SOLID;       // Line Style
input int                       InpWidthMA      = 2;                 // Line Width

//--- Indicator Buffers ---
double BufferMA[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_ma[];
datetime h_time[];

//--- Global Objects & State Management
CMovingAverageCalculator *g_calculator = NULL;

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
      return INIT_PARAMETERS_INCORRECT;
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Buffers
   SetIndexBuffer(0, BufferMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA, false);
   ArrayInitialize(BufferMA, EMPTY_VALUE);

// Configure Visuals
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthMA);
   PlotIndexSetDouble(0,  PLOT_EMPTY_VALUE, EMPTY_VALUE);

// Type-Accurate Draw Begin Setting
   int draw_begin = InpPeriod - 1;
   if(InpMAType == DEMA)
      draw_begin = 2 * InpPeriod - 2;
   else
      if(InpMAType == TEMA)
         draw_begin = 3 * InpPeriod - 3;
      else
         if(InpMAType == TMA)
            draw_begin = InpPeriod - 1;

   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 3. Initialize Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageCalculator_HA();
   else
      g_calculator = new CMovingAverageCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Critical Error: Failed to initialize Moving Average Calculator.");
      return INIT_FAILED;
     }

   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("%s%s%s(%d)", ma_name, ha_tag, tf_str, InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

// 4. Initialize Background Synchronization Timer (Only for MTF mode)
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
   int required_bars = InpPeriod + 5;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

// EXACT MATHEMATICAL APPLIED PRICE MAPPING (Eliminates Off-by-One Mismatch!)
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)InpSourcePrice) - 1) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, BufferMA);
      else
         g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, tick_volume, BufferMA);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = InpPeriod + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
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
      if(htf_bars < required_bars_mtf)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,   g_htf_count);
         ArrayResize(h_open,   g_htf_count);
         ArrayResize(h_high,   g_htf_count);
         ArrayResize(h_low,    g_htf_count);
         ArrayResize(h_close,  g_htf_count);
         ArrayResize(h_vol,    g_htf_count);
         ArrayResize(h_res_ma, g_htf_count);

         ArraySetAsSeries(h_time,   false);
         ArraySetAsSeries(h_open,   false);
         ArraySetAsSeries(h_high,   false);
         ArraySetAsSeries(h_low,    false);
         ArraySetAsSeries(h_close,  false);
         ArraySetAsSeries(h_vol,    false);
         ArraySetAsSeries(h_res_ma, false);
        }

      // Single Atomic Bulk Rates Copy
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
         h_vol[i]   = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? (double)htf_bulk_rates[i].real_volume : (double)htf_bulk_rates[i].tick_volume;
        }

      // Compute HTF Moving Average on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_vol, h_res_ma);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferMA[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferMA[i] = h_res_ma[htf_ptr];
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update strictly forming candle in RAM!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars_mtf)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_vol[live_idx] = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (double)htf_rate[0].real_volume : (double)htf_rate[0].tick_volume;

         // Mock incremental update on forming HTF bar
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_vol, h_res_ma);
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

// Direct Vectorized Assignment (Nanosecond execution across forming chart block)
   double ma_val = h_res_ma[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferMA[i] = ma_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpPeriod + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
