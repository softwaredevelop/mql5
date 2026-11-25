//+------------------------------------------------------------------+
//|                                           KeltnerChannel_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "5.00" // Enterprise Edition: Two-Pointer MTF Fast-Path, Fixed HA Price Offsets & Atomic CopyRates
#property description "Professional Keltner Channels with 14 Pluggable MA Models, VWMA Routing, and Hybrid ATR."
#property description "Features unified Native & Two-Pointer Fast-Path MTF pipelines and zero-API live tick rendering."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOliveDrab
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOliveDrab
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Middle Band (Basis)
#property indicator_label3  "Basis"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOliveDrab
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Included Engines & Core Tools ---
#include <MyIncludes\KeltnerChannel_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Middle Line (MA) Settings ==="
input int                       InpMaPeriod       = 20;                  // Middle Line Smoothing Period
input ENUM_MA_TYPE              InpMaMethod       = EMA;                 // Middle Line MA Algorithm (14 Pluggable Models)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_TYPICAL_STD;   // Price Source (Standard / HA)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Channel (ATR) Settings ==="
input int                       InpAtrPeriod      = 10;                  // ATR Volatility Period
input double                    InpMultiplier     = 2.0;                 // ATR Multiplier
input ENUM_ATR_SOURCE           InpAtrSource      = ATR_SOURCE_STANDARD; // ATR Volatility Source (Standard / Hybrid HA)

input group "=== Visual Settings - Outer Bands ==="
input color                     InpColorUpper     = clrOliveDrab;        // Upper Band Color
input color                     InpColorLower     = clrOliveDrab;        // Lower Band Color
input ENUM_LINE_STYLE           InpStyleBands     = STYLE_DOT;           // Outer Bands Style
input int                       InpWidthBands     = 1;                   // Outer Bands Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "=== Visual Settings - Centerline (Basis) ==="
input bool                      InpShowMiddle     = true;                // Display Centerline Basis
input color                     InpColorMiddle    = clrOliveDrab;        // Centerline Color
input ENUM_LINE_STYLE           InpStyleMiddle    = STYLE_SOLID;         // Centerline Style
input int                       InpWidthMiddle    = 2;                   // Centerline Width

//--- Indicator Output Buffers ---
double BufferUpper[];
double BufferLower[];
double BufferMiddle[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_upper[], h_res_lower[], h_res_middle[];
datetime h_time[];

//--- Global Objects & State Management ---
CKeltnerChannelCalculator *g_calculator     = NULL;
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
   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorUpper);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleBands);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthBands);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorLower);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleBands);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthBands);

   if(InpShowMiddle)
     {
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorMiddle);
      PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleMiddle);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthMiddle);
     }
   else
     {
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   int warmup = MathMax(InpMaPeriod, InpAtrPeriod);
   int draw_begin = warmup;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, (g_is_mtf_mode ? 0 : InpMaPeriod - 1));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CKeltnerChannelCalculator_HA();
   else
      g_calculator = new CKeltnerChannelCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpMaPeriod, InpMaMethod, InpAtrPeriod, InpMultiplier, InpAtrSource, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Keltner Channel Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string ha_atr  = (InpAtrSource == ATR_SOURCE_HEIKIN_ASHI) ? "/HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("KC Pro%s%s(%d,%s,ATR%s %d,x%.1f)",
                                    ha_tag, tf_str,
                                    InpMaPeriod, EnumToString(InpMaMethod), ha_atr, InpAtrPeriod, InpMultiplier);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Upper Band");
   PlotIndexSetString(1, PLOT_LABEL, "Lower Band");
   PlotIndexSetString(2, PLOT_LABEL, "Basis");

// 5. Background MTF Sync Daemon
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
   int warmup = MathMax(InpMaPeriod, InpAtrPeriod);
   if(rates_total < warmup + 5 || CheckPointer(g_calculator) == POINTER_INVALID)
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
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0 && InpMaMethod == VWMA)
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, volume,
                                BufferMiddle, BufferUpper, BufferLower);
      else
         if(InpMaMethod == VWMA)
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, tick_volume,
                                   BufferMiddle, BufferUpper, BufferLower);
         else
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, price_type,
                                   BufferMiddle, BufferUpper, BufferLower);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = warmup + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform atomic full history sync once
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
         ArrayResize(h_time,       g_htf_count, 2048);
         ArrayResize(h_open,       g_htf_count, 2048);
         ArrayResize(h_high,       g_htf_count, 2048);
         ArrayResize(h_low,        g_htf_count, 2048);
         ArrayResize(h_close,      g_htf_count, 2048);
         ArrayResize(h_vol,        g_htf_count, 2048);
         ArrayResize(h_res_upper,  g_htf_count, 2048);
         ArrayResize(h_res_lower,  g_htf_count, 2048);
         ArrayResize(h_res_middle, g_htf_count, 2048);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_upper,  false);
         ArraySetAsSeries(h_res_lower,  false);
         ArraySetAsSeries(h_res_middle, false);
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

      // Compute HTF Keltner Channel on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, price_type, h_vol,
                             h_res_middle, h_res_upper, h_res_lower);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferUpper[i]  = EMPTY_VALUE;
            BufferLower[i]  = EMPTY_VALUE;
            BufferMiddle[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufferUpper[i]  = h_res_upper[htf_ptr];
         BufferLower[i]  = h_res_lower[htf_ptr];
         BufferMiddle[i] = h_res_middle[htf_ptr];
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
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, price_type, h_vol,
                                h_res_middle, h_res_upper, h_res_lower);
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

   double val_upper  = h_res_upper[live_idx];
   double val_lower  = h_res_lower[live_idx];
   double val_middle = h_res_middle[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferUpper[i]  = val_upper;
      BufferLower[i]  = val_lower;
      BufferMiddle[i] = val_middle;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpMaPeriod, InpAtrPeriod);
   int required_bars = warmup + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
