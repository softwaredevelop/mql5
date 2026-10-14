//+------------------------------------------------------------------+
//|                                               Absorption_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.30" // Fixed: Eliminated MTF Array Out of Range in RVOL Single calculation
#property description "Institutional Multi-Timeframe Absorption Detector."
#property description "Detects Volume Spread Analysis (VSA) absorption anomalies with exact zone termination upon breach."

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2

//--- Plot 1: Bull Arrow (Dodger Blue)
#property indicator_label1  "Bull Abs"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

//--- Plot 2: Bear Arrow (Crimson Red)
#property indicator_label2  "Bear Abs"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES InpTimeframe            = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Indicator Settings ---"
input int             InpATRPeriod            = 14;                // ATR Period
input int             InpRVOLPeriod           = 20;                // RVOL Period (Relative Volume)
input int             InpHistoryBars          = 500;               // Limit object creation history (Bars)
input bool            InpShowObjects          = true;              // Toggle zone and rectangle visuals
input bool            InpShowArrows           = true;              // Toggle signal arrow visuals

input group "--- Zone Lifecycle & Truncation ---"
input bool            InpTruncateOnBreak      = true;              // Truncate zones strictly at breach candle
input bool            InpDeleteBrokenZones    = false;             // Delete broken zones completely from chart
input ENUM_LINE_STYLE InpBrokenZoneStyle      = STYLE_DOT;         // Border style for broken historical zones
input int             InpProjectionBars       = 3;                 // Active zone forward projection (Bars)

//--- Indicator Output Buffers
double BufBull[];
double BufBear[];
double BufATR[];
double BufRVOL[];
double BufState[]; // 0=None, 1=Bull, -1=Bear, 2=Climax, 0.5=Neut

//--- Active Zone Tracking Structure
struct SActiveZone
  {
   string            name;
   datetime          start_time;
   double            high;
   double            low;
   int               type; // 1 = Bull, -1 = Bear, 2 = Climax
  };

#define MAX_ACTIVE_ZONES 256
SActiveZone g_active_zones[MAX_ACTIVE_ZONES];
int         g_active_count = 0;

//--- Internal HTF Data Caches (Persistent BSS memory to prevent heap-thrashing)
double   h_open[], h_high[], h_low[], h_close[], h_volume[];
double   h_res_atr[], h_res_rvol[], h_res_state[];
double   h_res_bull[], h_res_bear[];
long     h_vol_long[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CATRCalculator            *g_atr  = NULL;
CRelativeVolumeCalculator *g_rvol = NULL;
string                     g_prefix = "";

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;
datetime        g_last_bar_time = 0; // State cache to detect fresh candle opens

//+------------------------------------------------------------------+
//| Forward Declarations of Internal Helpers                         |
//+------------------------------------------------------------------+
void RenderZone(const string name, const datetime t_start, const double price_high,
                const datetime t_end, const double price_low, const color fill_col,
                const bool is_broken);
int  FindZoneBreakBar(const int signal_idx, const double zone_high, const double zone_low,
                      const int zone_type, const int total_bars, const double &c[]);
void RegisterActiveZone(const string name, const datetime start_t, const double z_high,
                        const double z_low, const int z_type);
void MaintainActiveZones(const datetime live_time, const double current_close, const bool is_new_bar);

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;
   g_last_bar_time = 0;
   g_active_count  = 0;

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// Unique ChartID Namespace Isolation (Guarantees zero collisions across multi-window setups)
   g_prefix = StringFormat("AbsZ_%I64d_", ChartID());
   ObjectsDeleteAll(0, g_prefix);

// 2. Bind Buffers
   SetIndexBuffer(0, BufBull,  INDICATOR_DATA);
   SetIndexBuffer(1, BufBear,  INDICATOR_DATA);
   SetIndexBuffer(2, BufATR,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufRVOL,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufState, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufBull,  false);
   ArraySetAsSeries(BufBear,  false);
   ArraySetAsSeries(BufATR,   false);
   ArraySetAsSeries(BufRVOL,  false);
   ArraySetAsSeries(BufState, false);

// Dynamic Plot Visibility
   if(!InpShowArrows)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(0, PLOT_ARROW, 233); // Wingdings Bull arrow
      PlotIndexSetInteger(1, PLOT_ARROW, 234); // Wingdings Bear arrow
     }

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Initialize Calculation Engines
   g_atr = new CATRCalculator();
   if(CheckPointer(g_atr) != POINTER_INVALID)
      g_atr.Init(InpATRPeriod, ATR_POINTS);

   g_rvol = new CRelativeVolumeCalculator();
   if(CheckPointer(g_rvol) != POINTER_INVALID)
      g_rvol.Init(InpRVOLPeriod);

   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   IndicatorSetString(INDICATOR_SHORTNAME, "Absorption Pro" + tf_str);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Background Timer for MTF synchronization
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   ObjectsDeleteAll(0, g_prefix);

   if(CheckPointer(g_atr) != POINTER_INVALID)
     {
      delete g_atr;
      g_atr = NULL;
     }
   if(CheckPointer(g_rvol) != POINTER_INVALID)
     {
      delete g_rvol;
      g_rvol = NULL;
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Helper: Forward scanner to locate earliest breach candle         |
//+------------------------------------------------------------------+
int FindZoneBreakBar(const int signal_idx, const double zone_high, const double zone_low,
                     const int zone_type, const int total_bars, const double &c[])
  {
   for(int k = signal_idx + 1; k < total_bars; k++)
     {
      if(zone_type == 1 && c[k] < zone_low)
         return k; // Bullish absorption violated downwards
      if(zone_type == -1 && c[k] > zone_high)
         return k; // Bearish absorption violated upwards
      if(zone_type == 2 && (c[k] > zone_high || c[k] < zone_low))
         return k; // Climax absorption breached
     }
   return -1; // Unbroken up to latest available bar
  }

//+------------------------------------------------------------------+
//| Helper: Render or update graphical zone rectangle                |
//+------------------------------------------------------------------+
void RenderZone(const string name, const datetime t_start, const double price_high,
                const datetime t_end, const double price_low, const color fill_col,
                const bool is_broken)
  {
   if(is_broken && InpDeleteBrokenZones)
     {
      ObjectDelete(0, name);
      return;
     }

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_start, price_high, t_end, price_low);
      ObjectSetInteger(0, name, OBJPROP_COLOR, fill_col);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   else
     {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t_start);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 0, price_high);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t_end);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 1, price_low);
     }

   ObjectSetInteger(0, name, OBJPROP_STYLE, is_broken ? InpBrokenZoneStyle : STYLE_SOLID);
  }

//+------------------------------------------------------------------+
//| Helper: Register unbroken zone into the active tracking pool     |
//+------------------------------------------------------------------+
void RegisterActiveZone(const string name, const datetime start_t, const double z_high,
                        const double z_low, const int z_type)
  {
   if(g_active_count >= MAX_ACTIVE_ZONES)
      return; // Fixed memory capacity safety guard

   g_active_zones[g_active_count].name       = name;
   g_active_zones[g_active_count].start_time = start_t;
   g_active_zones[g_active_count].high       = z_high;
   g_active_zones[g_active_count].low        = z_low;
   g_active_zones[g_active_count].type       = z_type;
   g_active_count++;
  }

//+------------------------------------------------------------------+
//| Helper: O(1) Real-time maintenance of active zones with caching  |
//+------------------------------------------------------------------+
void MaintainActiveZones(const datetime live_time, const double current_close, const bool is_new_bar)
  {
   datetime projection_time = live_time + (datetime)(PeriodSeconds(g_calc_timeframe) * InpProjectionBars);

   for(int z = g_active_count - 1; z >= 0; z--)
     {
      bool break_occurred = false;
      if(g_active_zones[z].type == 1 && current_close < g_active_zones[z].low)
         break_occurred = true;
      else
         if(g_active_zones[z].type == -1 && current_close > g_active_zones[z].high)
            break_occurred = true;
         else
            if(g_active_zones[z].type == 2 && (current_close > g_active_zones[z].high || current_close < g_active_zones[z].low))
               break_occurred = true;

      if(break_occurred)
        {
         // Freeze the right boundary precisely at breach time
         if(InpTruncateOnBreak)
            ObjectSetInteger(0, g_active_zones[z].name, OBJPROP_TIME, 1, live_time);

         ObjectSetInteger(0, g_active_zones[z].name, OBJPROP_STYLE, InpBrokenZoneStyle);

         if(InpDeleteBrokenZones)
            ObjectDelete(0, g_active_zones[z].name);

         // O(1) Swap-and-Pop removal from active pool (Zero heap overhead)
         g_active_zones[z] = g_active_zones[g_active_count - 1];
         g_active_count--;
        }
      else
         if(is_new_bar)
           {
            // DIRTY-FLAG CACHING: Update boundary ONLY once when a new bar actually opens!
            ObjectSetInteger(0, g_active_zones[z].name, OBJPROP_TIME, 1, projection_time);
           }
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
   int warmup = InpATRPeriod + InpRVOLPeriod;
   if(rates_total < warmup || !g_atr || !g_rvol)
      return 0;

// Chronological alignment enforcement
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

   datetime current_live_time = time[rates_total - 1];
   bool is_new_candle = (current_live_time != g_last_bar_time);
   if(is_new_candle)
      g_last_bar_time = current_live_time;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, BufATR);

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
         g_rvol.Calculate(rates_total, prev_calculated, volume, BufRVOL);
      else
         g_rvol.Calculate(rates_total, prev_calculated, tick_volume, BufRVOL);

      // On clean startup or history refresh: wipe and rebuild zone state deterministically
      if(prev_calculated == 0)
        {
         g_active_count = 0;
         ObjectsDeleteAll(0, g_prefix);
        }

      int start = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
      int draw_limit = rates_total - InpHistoryBars;
      if(draw_limit < warmup)
         draw_limit = warmup;
      if(prev_calculated == 0 && start < draw_limit)
         start = draw_limit;

      for(int i = start; i < rates_total; i++)
        {
         BufBull[i]  = EMPTY_VALUE;
         BufBear[i]  = EMPTY_VALUE;
         BufState[i] = 0.0;

         double atr = BufATR[i];
         if(atr <= 0.0)
            continue;

         double body        = MathAbs(close[i] - open[i]);
         double total_range = high[i] - low[i];
         double rvol        = BufRVOL[i];

         bool is_bull   = false;
         bool is_bear   = false;
         bool is_climax = false;

         bool high_effort = (rvol > 2.0);
         bool low_result  = (body < (0.35 * atr));

         if(high_effort && low_result)
           {
            double close_pos = (total_range > 1.0e-9) ? ((close[i] - low[i]) / total_range) : 0.5;
            if(close_pos > 0.66)
              {
               BufState[i] = 1.0;
               is_bull = true;
              }
            else
               if(close_pos < 0.33)
                 {
                  BufState[i] = -1.0;
                  is_bear = true;
                 }
               else
                 {
                  BufState[i] = 0.5;
                 }
           }
         else
            if(rvol > 3.5 && body < (0.6 * atr))
              {
               BufState[i] = 2.0;
               is_climax = true;
              }

         if(is_bull || is_bear || is_climax)
           {
            if(InpShowArrows)
              {
               if(is_bull)
                  BufBull[i] = low[i] - atr * 0.3;
               if(is_bear)
                  BufBear[i] = high[i] + atr * 0.3;
              }

            if(InpShowObjects)
              {
               string name = StringFormat("%s%I64d", g_prefix, (long)time[i]);
               color zone_col = is_bull ? clrLightSteelBlue : (is_bear ? clrMistyRose : clrWheat);
               int zone_type = is_bull ? 1 : (is_bear ? -1 : 2);

               // Exact Forward Sweep to establish breach status
               int break_bar = FindZoneBreakBar(i, high[i], low[i], zone_type, rates_total, close);
               bool is_broken = (break_bar != -1);

               datetime end_time = 0;
               if(is_broken)
                 {
                  end_time = InpTruncateOnBreak ? time[break_bar] : (time[rates_total - 1] + (datetime)(PeriodSeconds() * InpProjectionBars));
                 }
               else
                 {
                  end_time = time[rates_total - 1] + (datetime)(PeriodSeconds() * InpProjectionBars);
                  RegisterActiveZone(name, time[i], high[i], low[i], zone_type);
                 }

               RenderZone(name, time[i], high[i], end_time, low[i], zone_col, is_broken);
              }
           }
        }

      // Fast O(1) Active Zone Maintenance on live forming ticks with Dirty-Flag GUI optimization
      if(InpShowObjects && g_active_count > 0)
        {
         MaintainActiveZones(current_live_time, close[rates_total - 1], is_new_candle);
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars = warmup + 10;
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

      // Reallocate persistent cache registers ONLY when capacity changes
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,       g_htf_count);
         ArrayResize(h_open,       g_htf_count);
         ArrayResize(h_high,       g_htf_count);
         ArrayResize(h_low,        g_htf_count);
         ArrayResize(h_close,      g_htf_count);
         ArrayResize(h_volume,     g_htf_count);
         ArrayResize(h_vol_long,   g_htf_count);
         ArrayResize(h_res_atr,    g_htf_count);
         ArrayResize(h_res_rvol,   g_htf_count);
         ArrayResize(h_res_state,  g_htf_count);
         ArrayResize(h_res_bull,   g_htf_count);
         ArrayResize(h_res_bear,   g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_volume,     false);
         ArraySetAsSeries(h_vol_long,   false);
         ArraySetAsSeries(h_res_atr,    false);
         ArraySetAsSeries(h_res_rvol,   false);
         ArraySetAsSeries(h_res_state,  false);
         ArraySetAsSeries(h_res_bull,   false);
         ArraySetAsSeries(h_res_bear,   false);
        }

      // Atomic bulk rates copy
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]     = htf_bulk_rates[i].time;
         h_open[i]     = htf_bulk_rates[i].open;
         h_high[i]     = htf_bulk_rates[i].high;
         h_low[i]      = htf_bulk_rates[i].low;
         h_close[i]    = htf_bulk_rates[i].close;
         h_volume[i]   = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? (double)htf_bulk_rates[i].real_volume : (double)htf_bulk_rates[i].tick_volume;
         h_vol_long[i] = (long)h_volume[i];
        }

      // Calculate HTF Baseline Indicators
      g_atr.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_atr);
      g_rvol.Calculate(g_htf_count, 0, h_vol_long, h_res_rvol);

      // Reset HTF state and arrows
      ArrayInitialize(h_res_state, 0.0);
      ArrayInitialize(h_res_bull,  EMPTY_VALUE);
      ArrayInitialize(h_res_bear,  EMPTY_VALUE);

      if(InpShowObjects)
        {
         g_active_count = 0;
         ObjectsDeleteAll(0, g_prefix);
        }

      // Evaluate VSA on HTF History
      datetime cutoff_time = TimeCurrent() - InpHistoryBars * PeriodSeconds(g_calc_timeframe);

      for(int i = warmup; i < g_htf_count; i++)
        {
         double atr = h_res_atr[i];
         if(atr <= 0.0)
            continue;

         double body        = MathAbs(h_close[i] - h_open[i]);
         double total_range = h_high[i] - h_low[i];
         double r_vol       = h_res_rvol[i];

         bool is_bull   = false;
         bool is_bear   = false;
         bool is_climax = false;

         bool high_effort = (r_vol > 2.0);
         bool low_result  = (body < (0.35 * atr));

         if(high_effort && low_result)
           {
            double close_pos = (total_range > 1.0e-9) ? ((h_close[i] - h_low[i]) / total_range) : 0.5;
            if(close_pos > 0.66)
              {
               h_res_state[i] = 1.0;
               is_bull = true;
              }
            else
               if(close_pos < 0.33)
                 {
                  h_res_state[i] = -1.0;
                  is_bear = true;
                 }
               else
                 {
                  h_res_state[i] = 0.5;
                 }
           }
         else
            if(r_vol > 3.5 && body < (0.6 * atr))
              {
               h_res_state[i] = 2.0;
               is_climax = true;
              }

         if((is_bull || is_bear || is_climax) && h_time[i] >= cutoff_time)
           {
            if(InpShowArrows)
              {
               if(is_bull)
                  h_res_bull[i] = h_low[i] - atr * 0.3;
               if(is_bear)
                  h_res_bear[i] = h_high[i] + atr * 0.3;
              }

            if(InpShowObjects)
              {
               string name = StringFormat("%s%I64d", g_prefix, (long)h_time[i]);
               color zone_col = is_bull ? clrLightSteelBlue : (is_bear ? clrMistyRose : clrWheat);
               int zone_type = is_bull ? 1 : (is_bear ? -1 : 2);

               int break_bar = FindZoneBreakBar(i, h_high[i], h_low[i], zone_type, g_htf_count, h_close);
               bool is_broken = (break_bar != -1);

               datetime end_time = 0;
               if(is_broken)
                 {
                  end_time = InpTruncateOnBreak ? h_time[break_bar] : (h_time[g_htf_count - 1] + (datetime)(PeriodSeconds(g_calc_timeframe) * InpProjectionBars));
                 }
               else
                 {
                  end_time = h_time[g_htf_count - 1] + (datetime)(PeriodSeconds(g_calc_timeframe) * InpProjectionBars);
                  RegisterActiveZone(name, h_time[i], h_high[i], h_low[i], zone_type);
                 }

               RenderZone(name, h_time[i], h_high[i], end_time, h_low[i], zone_col, is_broken);
              }
           }
        }

      g_data_ready = true;

      // Full Historical Projection to Chart Buffers (Two-Pointer Style)
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufATR[i]   = EMPTY_VALUE;
            BufRVOL[i]  = EMPTY_VALUE;
            BufState[i] = 0.0;
            BufBull[i]  = EMPTY_VALUE;
            BufBear[i]  = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         BufATR[i]   = h_res_atr[htf_ptr];
         BufRVOL[i]  = h_res_rvol[htf_ptr];
         BufState[i] = h_res_state[htf_ptr];
         BufBull[i]  = h_res_bull[htf_ptr];
         BufBear[i]  = h_res_bear[htf_ptr];
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update forming candle in RAM!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
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
         h_volume[live_idx]   = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (double)htf_rate[0].real_volume : (double)htf_rate[0].tick_volume;
         h_vol_long[live_idx] = (long)h_volume[live_idx]; // Update forming volume in persistent cache!

         // Mock incremental calculation on forming bar
         g_atr.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_atr);

         // SAFE CALL: Passes full h_vol_long array of size g_htf_count! Zero out-of-range!
         h_res_rvol[live_idx] = g_rvol.CalculateSingle(g_htf_count, h_vol_long, live_idx);

         // Real-time VSA evaluation on forming HTF bar
         double body_live  = MathAbs(h_close[live_idx] - h_open[live_idx]);
         double range_live = h_high[live_idx] - h_low[live_idx];
         double atr_live   = h_res_atr[live_idx];
         double rvol_live  = h_res_rvol[live_idx];

         h_res_state[live_idx] = 0.0;
         h_res_bull[live_idx]  = EMPTY_VALUE;
         h_res_bear[live_idx]  = EMPTY_VALUE;

         if(atr_live > 0.0)
           {
            bool is_b = false, is_s = false, is_c = false;
            if(rvol_live > 2.0 && body_live < (0.35 * atr_live))
              {
               double c_pos = (range_live > 1.0e-9) ? ((h_close[live_idx] - h_low[live_idx]) / range_live) : 0.5;
               if(c_pos > 0.66)
                 {
                  h_res_state[live_idx] = 1.0;
                  is_b = true;
                 }
               else
                  if(c_pos < 0.33)
                    {
                     h_res_state[live_idx] = -1.0;
                     is_s = true;
                    }
                  else
                    {
                     h_res_state[live_idx] = 0.5;
                    }
              }
            else
               if(rvol_live > 3.5 && body_live < (0.6 * atr_live))
                 {
                  h_res_state[live_idx] = 2.0;
                  is_c = true;
                 }

            if(InpShowArrows)
              {
               if(is_b)
                  h_res_bull[live_idx] = h_low[live_idx] - atr_live * 0.3;
               if(is_s)
                  h_res_bear[live_idx] = h_high[live_idx] + atr_live * 0.3;
              }
           }

         if(InpShowObjects && g_active_count > 0)
            MaintainActiveZones(h_time[live_idx], h_close[live_idx], is_new_candle);
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

// Direct Vectorized Assignment (Nanosecond execution across chart buffers)
   double atr_val   = h_res_atr[live_idx];
   double rvol_val  = h_res_rvol[live_idx];
   double state_val = h_res_state[live_idx];
   double bull_val  = h_res_bull[live_idx];
   double bear_val  = h_res_bear[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufATR[i]   = atr_val;
      BufRVOL[i]  = rvol_val;
      BufState[i] = state_val;
      BufBull[i]  = bull_val;
      BufBear[i]  = bear_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpATRPeriod + InpRVOLPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
