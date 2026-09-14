//+------------------------------------------------------------------+
//|                                             Rolling_VWAP_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20"
#property description "Professional Rolling Volume Weighted Average Price (Rolling VWAP)."
#property description "Continuous non-resetting algorithm supporting Bar and Time window models."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot: Single Continuous Rolling VWAP Stream
#property indicator_label1  "Rolling VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Included Core Suite Frameworks
#include <MyIncludes\Rolling_VWAP_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Candle Source Enum
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Standard OHLC Data
   CANDLE_HEIKIN_ASHI    // Heikin Ashi Smoothed Data
  };
#endif

//--- Inputs
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Rolling Window Configuration ---"
input ENUM_ROLLING_TYPE         InpRollingType    = ROLLING_BARS;      // Window Type (Bars vs Time)
input int                       InpRollingWindow  = 144;               // Window Length (Bars or Minutes)

input group "--- Calculation Sources ---"
input ENUM_APPLIED_VOLUME       InpVolumeType     = VOLUME_TICK;       // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource   = CANDLE_STANDARD;   // Candle Source

input group "--- Visual Styling ---"
input color                     InpColorVWAP      = clrDeepSkyBlue;    // Line Color
input ENUM_LINE_STYLE           InpStyleVWAP      = STYLE_SOLID;       // Line Style
input int                       InpWidthVWAP      = 2;                 // Line Width

//--- Indicator Output Buffer
double    BufferRollingVWAP[];

//--- Internal HTF Data Caches (Strict Chronological Indexing)
double    h_open[], h_high[], h_low[], h_close[];
long      h_tick_vol[], h_vol[];
double    h_res_vwap[];
datetime  h_time[];

//--- Global Dynamic Calculator Pointer
CRollingVWAPCalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Resolve Timeframe and Direction Guard
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Rolling VWAP Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Output Buffer
   SetIndexBuffer(0, BufferRollingVWAP, INDICATOR_DATA);
   ArraySetAsSeries(BufferRollingVWAP, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArrayInitialize(BufferRollingVWAP, EMPTY_VALUE);

// 3. Configure Visual Properties
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthVWAP);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Instantiate Calculation Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CRollingVWAPCalculator_HA();
   else
      g_calculator = new CRollingVWAPCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Rolling VWAP Critical Error: Failed to instantiate engine pointer.");
      return INIT_FAILED;
     }

   if(!g_calculator.Init(InpRollingType, InpRollingWindow, InpVolumeType, true))
     {
      Print("Rolling VWAP Critical Error: Engine initialization failed.");
      return INIT_FAILED;
     }

// 5. Compose Indicator Title
   string ha_tag   = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string type_str = (InpRollingType == ROLLING_BARS) ? "Bars" : "Min";
   string short_name = StringFormat("Rolling_VWAP%s%s(%d %s)", ha_tag, tf_str, InpRollingWindow, type_str);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

// 6. Asynchronous Background Sync Daemon for MTF
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
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
//| Custom indicator calculation iteration                           |
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
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce strict chronological alignment on inputs
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Native Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                             tick_volume, volume, BufferRollingVWAP);
      return rates_total;
     }

//===================================================================
// MODE 2: Synchronized MTF Engine
//===================================================================
   int required_bars = (InpRollingType == ROLLING_BARS) ? (InpRollingWindow + 10) : 50;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000); // Enterprise memory guard

      // Resize all HTF caching structures
      ArrayResize(h_time,     g_htf_count);
      ArrayResize(h_open,     g_htf_count);
      ArrayResize(h_high,     g_htf_count);
      ArrayResize(h_low,      g_htf_count);
      ArrayResize(h_close,    g_htf_count);
      ArrayResize(h_tick_vol, g_htf_count);
      ArrayResize(h_vol,      g_htf_count);
      ArrayResize(h_res_vwap, g_htf_count);

      // Force chronological array directions
      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_tick_vol, false);
      ArraySetAsSeries(h_vol,      false);
      ArraySetAsSeries(h_res_vwap, false);

      // Copy HTF pricing and volume arrays
      if(CopyTime(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_time)     != g_htf_count ||
         CopyOpen(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_open)     != g_htf_count ||
         CopyHigh(_Symbol,       g_calc_timeframe, 0, g_htf_count, h_high)     != g_htf_count ||
         CopyLow(_Symbol,        g_calc_timeframe, 0, g_htf_count, h_low)      != g_htf_count ||
         CopyClose(_Symbol,      g_calc_timeframe, 0, g_htf_count, h_close)    != g_htf_count ||
         CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_tick_vol) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
         CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, h_vol);
      else
         ArrayCopy(h_vol, h_tick_vol, 0, 0, g_htf_count);

      // Full calculation pass on synchronized HTF historical bars
      g_calculator.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                             h_tick_vol, h_vol, h_res_vwap);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];
      long tv[1], v[1];

      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,       g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,       g_calc_timeframe, shift, 1, o)     == 1 &&
         CopyHigh(_Symbol,       g_calc_timeframe, shift, 1, h)     == 1 &&
         CopyLow(_Symbol,        g_calc_timeframe, shift, 1, l)     == 1 &&
         CopyClose(_Symbol,      g_calc_timeframe, shift, 1, c)     == 1 &&
         CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, tv)    == 1)
        {
         h_time[live_idx]     = t_bar[0];
         h_open[live_idx]     = o[0];
         h_high[live_idx]     = h[0];
         h_low[live_idx]      = l[0];
         h_close[live_idx]    = c[0];
         h_tick_vol[live_idx] = tv[0];

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = v[0];
         else
            h_vol[live_idx] = tv[0];

         // Mock update strictly on forming candle
         g_calculator.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                h_tick_vol, h_vol, h_res_vwap);
        }
     }

// Forming LTF Block Flat-Force Anchor (Staircase Warp Prevention)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++;

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Chronological Projection Mapping to Chart Timeframe
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
            BufferRollingVWAP[i] = h_res_vwap[idx_htf];
         else
            BufferRollingVWAP[i] = EMPTY_VALUE;
        }
      else
        {
         BufferRollingVWAP[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = (InpRollingType == ROLLING_BARS) ? (InpRollingWindow + 10) : 50;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
