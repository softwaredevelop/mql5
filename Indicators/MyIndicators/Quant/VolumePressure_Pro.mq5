//+------------------------------------------------------------------+
//|                                           VolumePressure_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.00" // Enterprise Edition: Two-Pointer MTF Fast-Path, 14-MA Smoothing, HA Candles & Neutral Zone
#property description "Volume Pressure (Close Location Value / Tick Delta Proxy) bounded -1.0 to +1.0."
#property description "Features 14 MA smoothing models (incl. VWMA), Synthetic Heikin Ashi, Neutral Zone, and MTF Fast-Path."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_minimum -1.1
#property indicator_maximum  1.1

//--- Plot: Histogram (0 = Bear, 1 = Bull, 2 = Neutral)
#property indicator_label1  "V_PRES"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrCrimson, clrMediumSeaGreen, clrDarkGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Included Engines & Core Tools ---
#include <MyIncludes\VolumePressure_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Candle Source Enum ---
enum ENUM_VP_CANDLE_SOURCE
  {
   VP_CANDLE_STANDARD,      // Standard OHLC Data
   VP_CANDLE_HEIKIN_ASHI    // Synthetic Heikin Ashi Candles
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES       InpTimeframe      = PERIOD_CURRENT;     // Calculation Timeframe (Current or HTF)

input group "=== Volume Pressure Core Settings ==="
input ENUM_VP_CANDLE_SOURCE InpCandleSource   = VP_CANDLE_STANDARD; // Candle Source (Standard / Heikin Ashi)
input int                   InpSmoothPeriod   = 1;                  // Smoothing Period (1 = Raw, >1 = Smoothed)
input ENUM_MA_TYPE          InpMAType         = EMA;                // Smoothing MA Algorithm (14 Pluggable Models)

input group "=== Visual & Threshold Settings ==="
input double                InpNeutralZone    = 0.0;                // Neutral Zone Half-Width around 0.0 (e.g. 0.15, 0 = Off)
input color                 InpColorBull      = clrMediumSeaGreen;  // Bullish Pressure Color
input color                 InpColorBear      = clrCrimson;         // Bearish Pressure Color
input color                 InpColorNeutral   = clrDarkGray;        // Neutral Chop Zone Color
input int                   InpWidthHist      = 2;                  // Histogram Bar Width

//--- Indicator Output Buffers ---
double BufVal[];
double BufCol[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_vp[];
datetime h_time[];

//--- Global Objects & State Management ---
CVolumePressureCalculator *g_calc           = NULL;
bool                      g_is_mtf_mode     = false;
ENUM_TIMEFRAMES           g_calc_timeframe;
bool                      g_data_ready      = false;
bool                      g_data_synced     = false;
int                       g_htf_count       = 0;
datetime                  g_last_htf_time   = 0;

//+------------------------------------------------------------------+
//| Helper: Map Value to 3-State Color Index                         |
//+------------------------------------------------------------------+
double GetColorIndex(const double val)
  {
   if(InpNeutralZone > 0.0)
     {
      if(val > InpNeutralZone)
         return 1.0; // Bullish (Green)
      if(val < -InpNeutralZone)
         return 0.0; // Bearish (Red)
      return 2.0;                           // Neutral Zone (Gray)
     }
   return (val >= 0.0) ? 1.0 : 0.0;
  }

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

// 2. Bind Output Buffers & Enforce Chronological Order
   SetIndexBuffer(0, BufVal, INDICATOR_DATA);
   SetIndexBuffer(1, BufCol, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufVal, false);
   ArraySetAsSeries(BufCol, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorBear);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorBull);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorNeutral);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthHist);

// Reference Levels
   if(InpNeutralZone > 0.0)
     {
      IndicatorSetInteger(INDICATOR_LEVELS, 2);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpNeutralZone);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -InpNeutralZone);
     }
   else
     {
      IndicatorSetInteger(INDICATOR_LEVELS, 0);
     }
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrDarkGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);

   int draw_begin = (InpSmoothPeriod > 1) ? InpSmoothPeriod - 1 : 0;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

// 4. Initialize Core Calculator Engine
   bool is_ha = (InpCandleSource == VP_CANDLE_HEIKIN_ASHI);
   g_calc = new CVolumePressureCalculator();

   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpSmoothPeriod, InpMAType, is_ha))
     {
      Print("Critical Error: Failed to initialize Volume Pressure Calculator.");
      return INIT_FAILED;
     }

   string ha_tag  = is_ha ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string sm_str  = (InpSmoothPeriod > 1) ? StringFormat("%s %d", EnumToString(InpMAType), InpSmoothPeriod) : "Raw";
   string name    = StringFormat("V_PRES Pro%s%s(%s)", ha_tag, tf_str, sm_str);

   IndicatorSetString(INDICATOR_SHORTNAME, name);
   PlotIndexSetString(0, PLOT_LABEL, "V_PRES");

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

   if(CheckPointer(g_calc) != POINTER_INVALID && g_calc != NULL)
     {
      delete g_calc;
      g_calc = NULL;
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
   int required_bars = MathMax(2, InpSmoothPeriod) + 5;
   if(rates_total < required_bars || CheckPointer(g_calc) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      bool use_vwma = (InpSmoothPeriod > 1 && InpMAType == VWMA);
      if(use_vwma)
        {
         long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(volume_limit > 0)
            g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, volume, BufVal);
         else
            g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, BufVal);
        }
      else
        {
         g_calc.Calculate(rates_total, prev_calculated, open, high, low, close, BufVal);
        }

      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
         BufCol[i] = GetColorIndex(BufVal[i]);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = MathMax(2, InpSmoothPeriod) + 10;
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
         ArrayResize(h_time,   g_htf_count, 2048);
         ArrayResize(h_open,   g_htf_count, 2048);
         ArrayResize(h_high,   g_htf_count, 2048);
         ArrayResize(h_low,    g_htf_count, 2048);
         ArrayResize(h_close,  g_htf_count, 2048);
         ArrayResize(h_vol,    g_htf_count, 2048);
         ArrayResize(h_res_vp, g_htf_count, 2048);

         ArraySetAsSeries(h_time,   false);
         ArraySetAsSeries(h_open,   false);
         ArraySetAsSeries(h_high,   false);
         ArraySetAsSeries(h_low,    false);
         ArraySetAsSeries(h_close,  false);
         ArraySetAsSeries(h_vol,    false);
         ArraySetAsSeries(h_res_vp, false);
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

      // Compute HTF Volume Pressure on Clean HTF Domain
      if(InpSmoothPeriod > 1 && InpMAType == VWMA)
         g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol, h_res_vp);
      else
         g_calc.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_vp);

      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufVal[i] = EMPTY_VALUE;
            BufCol[i] = 2.0;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double val = h_res_vp[htf_ptr];
         BufVal[i]  = val;
         BufCol[i]  = GetColorIndex(val);
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
         if(InpSmoothPeriod > 1 && InpMAType == VWMA)
            g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol, h_res_vp);
         else
            g_calc.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_vp);
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

   double val_vp  = h_res_vp[live_idx];
   double col_idx = GetColorIndex(val_vp);

   for(int i = start; i < rates_total; i++)
     {
      BufVal[i] = val_vp;
      BufCol[i] = col_idx;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(2, InpSmoothPeriod) + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
