//+------------------------------------------------------------------+
//|                                     Bollinger_Bands_PercentB.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.00" // Enterprise Edition: MTF Fast-Path, Fixed HA Price Offsets & Atomic CopyRates
#property description "Bollinger Bands %B Suite. Shows the position of price relative to the volatility bands."
#property description "Features unified Native & MTF pipelines, 14 MA models, and Heikin Ashi pricing."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Reference Equilibrium Levels
#property indicator_level1      0.0
#property indicator_level2      0.5
#property indicator_level3      1.0
#property indicator_levelcolor  clrDarkGray
#property indicator_levelstyle  STYLE_DOT

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Plot 1: %B Value Line
#property indicator_label1  "%B"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrTeal
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "=== Bollinger Bands Core Settings ==="
input int                       InpPeriod       = 20;                // Smoothing Period
input double                    InpDeviation    = 2.0;               // Band Dispersion Multiplier
input ENUM_MA_TYPE              InpMAType       = SMA;               // Centerline MA Algorithm (14 Pluggable Models)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "=== Visual Settings ==="
input color                     InpColorPercentB= clrTeal;           // %B Line Color
input ENUM_LINE_STYLE           InpStylePercentB= STYLE_SOLID;       // %B Line Style
input int                       InpWidthPercentB= 1;                 // %B Line Width

//--- Indicator Output Buffers ---
double BufferPercentB[];

//--- Internal Working Buffers (With Memory Capacity Reservations) ---
double BufferUpper_Internal[];
double BufferLower_Internal[];
double BufferMA_Internal[];
double BufferPrice_Internal[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_ma[], h_res_upper[], h_res_lower[], h_res_price[], h_res_pb[];
datetime h_time[];

//--- Global Objects & State Management ---
CBollingerBandsCalculator *g_calculator     = NULL;
bool                      g_is_mtf_mode     = false;
ENUM_TIMEFRAMES           g_calc_timeframe;
bool                      g_data_ready      = false;
bool                      g_data_synced     = false;
int                       g_htf_count       = 0;
datetime                  g_last_htf_time   = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Direction Guard
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

// 2. Bind Output Buffers
   SetIndexBuffer(0, BufferPercentB, INDICATOR_DATA);
   ArraySetAsSeries(BufferPercentB, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorPercentB);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStylePercentB);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPercentB);

   int draw_begin = InpPeriod - 1;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

// 3. Initialize Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CBollingerBandsCalculator_HA();
   else
      g_calculator = new CBollingerBandsCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpDeviation, InpMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Bollinger Bands Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("%%B%s%s(%d, %.2f, %s)", ha_tag, tf_str, InpPeriod, InpDeviation, EnumToString(InpMAType));

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

// 4. Background MTF Sync Daemon
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID && g_calculator != NULL)
     {
      delete g_calculator;
      g_calculator = NULL;
     }

   ArrayFree(BufferUpper_Internal);
   ArrayFree(BufferLower_Internal);
   ArrayFree(BufferMA_Internal);
   ArrayFree(BufferPrice_Internal);
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

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

// EXACT MATHEMATICAL APPLIED PRICE MAPPING (Eliminates Off-by-One Mismatch)
   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)InpSourcePrice) - 1) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      if(ArraySize(BufferUpper_Internal) != rates_total)
        {
         ArrayResize(BufferUpper_Internal, rates_total, 2048);
         ArrayResize(BufferLower_Internal, rates_total, 2048);
         ArrayResize(BufferMA_Internal,    rates_total, 2048);
         ArrayResize(BufferPrice_Internal, rates_total, 2048);

         ArraySetAsSeries(BufferUpper_Internal, false);
         ArraySetAsSeries(BufferLower_Internal, false);
         ArraySetAsSeries(BufferMA_Internal,    false);
         ArraySetAsSeries(BufferPrice_Internal, false);
        }

      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0 && InpMAType == VWMA)
         g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume,
                                BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);
      else
         if(InpMAType == VWMA)
            g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, tick_volume,
                                   BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);
         else
            g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                                   BufferMA_Internal, BufferUpper_Internal, BufferLower_Internal);

      g_calculator.GetPriceBuffer(BufferPrice_Internal);

      int start_pos  = InpPeriod - 1;
      int loop_start = MathMax(start_pos, (prev_calculated > 0 ? prev_calculated - 1 : 0));

      for(int i = loop_start; i < rates_total; i++)
        {
         double band_width = BufferUpper_Internal[i] - BufferLower_Internal[i];
         if(band_width > 0.0)
            BufferPercentB[i] = (BufferPrice_Internal[i] - BufferLower_Internal[i]) / band_width;
         else
            BufferPercentB[i] = 0.5;
        }

      // Pre-warmup zone filling
      int fill_limit = MathMin(start_pos, rates_total);
      for(int i = (prev_calculated == 0 ? 0 : prev_calculated - 1); i < fill_limit; i++)
         BufferPercentB[i] = EMPTY_VALUE;

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

      // Resize all HTF caching arrays with capacity reservation
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,      g_htf_count, 2048);
         ArrayResize(h_open,      g_htf_count, 2048);
         ArrayResize(h_high,      g_htf_count, 2048);
         ArrayResize(h_low,       g_htf_count, 2048);
         ArrayResize(h_close,     g_htf_count, 2048);
         ArrayResize(h_vol,       g_htf_count, 2048);
         ArrayResize(h_res_ma,    g_htf_count, 2048);
         ArrayResize(h_res_upper, g_htf_count, 2048);
         ArrayResize(h_res_lower, g_htf_count, 2048);
         ArrayResize(h_res_price, g_htf_count, 2048);
         ArrayResize(h_res_pb,    g_htf_count, 2048);

         ArraySetAsSeries(h_time,      false);
         ArraySetAsSeries(h_open,      false);
         ArraySetAsSeries(h_high,      false);
         ArraySetAsSeries(h_low,       false);
         ArraySetAsSeries(h_close,     false);
         ArraySetAsSeries(h_vol,       false);
         ArraySetAsSeries(h_res_ma,    false);
         ArraySetAsSeries(h_res_upper, false);
         ArraySetAsSeries(h_res_lower, false);
         ArraySetAsSeries(h_res_price, false);
         ArraySetAsSeries(h_res_pb,    false);
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

      // Compute HTF Bollinger Bands
      g_calculator.Calculate(g_htf_count, 0, price_type, h_open, h_high, h_low, h_close, h_vol,
                             h_res_ma, h_res_upper, h_res_lower);
      g_calculator.GetPriceBuffer(h_res_price);

      // Compute Clean HTF %B
      for(int i = 0; i < g_htf_count; i++)
        {
         if(i < InpPeriod - 1)
           {
            h_res_pb[i] = EMPTY_VALUE;
            continue;
           }

         double bw = h_res_upper[i] - h_res_lower[i];
         h_res_pb[i] = (bw > 0.0) ? ((h_res_price[i] - h_res_lower[i]) / bw) : 0.5;
        }

      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferPercentB[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferPercentB[i] = h_res_pb[htf_ptr];
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: Update forming candle strictly in RAM
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

         // Recompute strictly forming bar in RAM
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, h_low, h_close, h_vol,
                                h_res_ma, h_res_upper, h_res_lower);
         g_calculator.GetPriceBuffer(h_res_price);

         double bw = h_res_upper[live_idx] - h_res_lower[live_idx];
         h_res_pb[live_idx] = (bw > 0.0) ? ((h_res_price[live_idx] - h_res_lower[live_idx]) / bw) : 0.5;
        }
     }

// Binary Search for forming bar block start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

   double val_pb = h_res_pb[live_idx];

   for(int i = start; i < rates_total; i++)
      BufferPercentB[i] = val_pb;

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
