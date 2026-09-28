//+------------------------------------------------------------------+
//|                                         VScore_Dual_Widget_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.10" // Fixed: Weekly/Monthly Multi-Week History Depth Convergence
#property description "Dual-Timeframe Volume-Weighted Z-Score (V-Score) Chart HUD Widget."
#property description "Optimized for massive multi-window execution with full multi-week statistical stability."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Included Engines & Core Tools
#include <MyIncludes\VScore_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting candle source ---
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };
#endif

//--- Input Parameters ---
input group "--- Heads-Up Display Settings ---"
input int                       InpRefreshSeconds       = 3;                     // Background Timer Fallback (Seconds)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Slot 1: Tactical Flow (e.g. Daily / M15) ---"
input string                    InpSlot1Label           = "Daily";               // Slot 1 Custom Label
input ENUM_TIMEFRAMES           InpSlot1TF              = PERIOD_M15;            // Slot 1 Timeframe
input ENUM_VWAP_PERIOD          InpSlot1Reset           = PERIOD_SESSION;        // Slot 1 VWAP Anchor Reset
input int                       InpSlot1Period          = 20;                    // Slot 1 Volatility Period (Sigma)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Slot 2: Strategic Context (e.g. Weekly / H1) ---"
input string                    InpSlot2Label           = "Weekly";              // Slot 2 Custom Label
input ENUM_TIMEFRAMES           InpSlot2TF              = PERIOD_H1;             // Slot 2 Timeframe
input ENUM_VWAP_PERIOD          InpSlot2Reset           = PERIOD_WEEK;           // Slot 2 VWAP Anchor Reset
input int                       InpSlot2Period          = 20;                    // Slot 2 Volatility Period (Sigma)

input group "--- Calculation & Session Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;       // Candle Source
input int                       InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string                    InpCustomSessionStart   = "09:30";               // Custom Session Start (HH:MM)
input string                    InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Indicator Levels (Sigma Units) ---"
input double                    InpLevelFlowHigh        = 1.5;                   // High Warning Level (Bullish Flow)
input double                    InpLevelFlowLow         = -1.5;                  // Low Warning Level (Bearish Flow)
input double                    InpLevelClimaxHigh      = 2.0;                   // High Climax Level (Bullish Climax)
input double                    InpLevelClimaxLow       = -2.0;                  // Low Climax Level (Bearish Climax)
input double                    InpLevelExtremeHigh     = 2.5;                   // High Extreme Level (Bullish Exhaustion)
input double                    InpLevelExtremeLow      = -2.5;                  // Low Extreme Level (Bearish Exhaustion)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Widget Placement (Pixels) ---"
input int                       InpTableX               = 20;                    // Widget X Offset (From Left)
input int                       InpTableY               = 30;                    // Widget Y Offset (From Bottom)
input int                       InpFontSize             = 9;                     // UI Font Size

//--- Persistent Global Engines
CVScoreCalculator g_calc_slot1;
CVScoreCalculator g_calc_slot2;

//--- Persistent Slot State Tracking for True Incremental O(1) Processing
int               g_s1_prev_calc = 0;
int               g_s2_prev_calc = 0;
datetime          g_s1_last_bar_time = 0;
datetime          g_s2_last_bar_time = 0;

//--- Persistent Reusable Caches
MqlRates          g_s1_rates[], g_s2_rates[];
double            g_s1_open[], g_s1_high[], g_s1_low[], g_s1_close[], g_s1_res[];
long              g_s1_tvol[], g_s1_vol[];
datetime          g_s1_time[];

double            g_s2_open[], g_s2_high[], g_s2_low[], g_s2_close[], g_s2_res[];
long              g_s2_tvol[], g_s2_vol[];
datetime          g_s2_time[];

//--- UI State Guards
string            g_prefix = "";
bool              g_updating = false;
ulong             g_last_update_ms = 0;
double            g_last_rendered_vs1 = EMPTY_VALUE;
double            g_last_rendered_vs2 = EMPTY_VALUE;

//+------------------------------------------------------------------+
//| Dynamic Lookback Bar Resolver (Enhanced Multi-Week Depth)        |
//+------------------------------------------------------------------+
int ResolveRequiredBars(const ENUM_TIMEFRAMES tf, const ENUM_VWAP_PERIOD reset, const int period)
  {
   int tf_sec = PeriodSeconds(tf);
   if(tf_sec < 1)
      tf_sec = 60;

// FIXED: Guarantee sufficient historical depth for multi-week/multi-month variance convergence
   int min_depth = 500;
   if(reset == PERIOD_WEEK)
      min_depth = 2000;  // Minimum 2000 bars for H1 ensures 12+ full historical weeks
   else
      if(reset == PERIOD_MONTH)
         min_depth = 3000;

   int anchor_bars = 100;
   switch(reset)
     {
      case PERIOD_SESSION:
         anchor_bars = (int)(86400 / tf_sec) + 20;
         break;
      case PERIOD_WEEK:
         anchor_bars = (int)(7 * 86400 / tf_sec) + 100;
         break;
      case PERIOD_MONTH:
         anchor_bars = (int)(31 * 86400 / tf_sec) + 200;
         break;
      case PERIOD_CUSTOM_SESSION:
         anchor_bars = (int)(86400 / tf_sec) + 20;
         break;
     }

   int req = MathMax(min_depth, period + anchor_bars);
   return MathMin(req, 3000);
  }

//+------------------------------------------------------------------+
//| High-Performance O(1) Slot Value Processor                       |
//+------------------------------------------------------------------+
double UpdateSlotValue(CVScoreCalculator &calc,
                       const ENUM_TIMEFRAMES tf,
                       const ENUM_VWAP_PERIOD reset,
                       const int period,
                       int &prev_calc,
                       datetime &last_bar_time,
                       MqlRates &rates_cache[],
                       double &open_cache[], double &high_cache[], double &low_cache[], double &close_cache[],
                       long &tvol_cache[], long &vol_cache[], datetime &time_cache[],
                       double &res_cache[])
  {
   int required_bars = ResolveRequiredBars(tf, reset, period);

   if(!CDataSync::EnsureHTFDataReady(_Symbol, tf, required_bars))
      return EMPTY_VALUE;

   int htf_bars = iBars(_Symbol, tf);
   if(htf_bars < required_bars)
      return EMPTY_VALUE;

   int count = MathMin(htf_bars, required_bars);

// Single Atomic API Query
   if(CopyRates(_Symbol, tf, 0, count, rates_cache) != count)
      return EMPTY_VALUE;

// Detect Bar Rollover or History Resync
   datetime current_htf_time = rates_cache[count - 1].time;
   bool new_bar = (current_htf_time != last_bar_time);

   if(new_bar || prev_calc == 0 || ArraySize(res_cache) != count)
     {
      last_bar_time = current_htf_time;
      prev_calc = 0; // Full pass on new candle to establish baseline

      ArrayResize(open_cache,  count);
      ArraySetAsSeries(open_cache,  false);
      ArrayResize(high_cache,  count);
      ArraySetAsSeries(high_cache,  false);
      ArrayResize(low_cache,   count);
      ArraySetAsSeries(low_cache,   false);
      ArrayResize(close_cache, count);
      ArraySetAsSeries(close_cache, false);
      ArrayResize(tvol_cache,  count);
      ArraySetAsSeries(tvol_cache,  false);
      ArrayResize(vol_cache,   count);
      ArraySetAsSeries(vol_cache,   false);
      ArrayResize(time_cache,  count);
      ArraySetAsSeries(time_cache,  false);
      ArrayResize(res_cache,   count);
      ArraySetAsSeries(res_cache,   false);

      for(int i = 0; i < count; i++)
        {
         open_cache[i]  = rates_cache[i].open;
         high_cache[i]  = rates_cache[i].high;
         low_cache[i]   = rates_cache[i].low;
         close_cache[i] = rates_cache[i].close;
         tvol_cache[i]  = rates_cache[i].tick_volume;
         vol_cache[i]   = (rates_cache[i].real_volume > 0) ? rates_cache[i].real_volume : rates_cache[i].tick_volume;
         time_cache[i]  = rates_cache[i].time;
        }
     }
   else
     {
      // Fast Live Tick Path: Update active bar strictly in RAM
      int last_idx = count - 1;
      open_cache[last_idx]  = rates_cache[last_idx].open;
      high_cache[last_idx]  = rates_cache[last_idx].high;
      low_cache[last_idx]   = rates_cache[last_idx].low;
      close_cache[last_idx] = rates_cache[last_idx].close;
      tvol_cache[last_idx]  = rates_cache[last_idx].tick_volume;
      vol_cache[last_idx]   = (rates_cache[last_idx].real_volume > 0) ? rates_cache[last_idx].real_volume : rates_cache[last_idx].tick_volume;
      time_cache[last_idx]  = rates_cache[last_idx].time;
     }

// Incremental O(1) Calculation
   calc.Calculate(count, prev_calc, time_cache, open_cache, high_cache, low_cache, close_cache, tvol_cache, vol_cache, res_cache);
   prev_calc = count;

   return res_cache[count - 1];
  }

//+------------------------------------------------------------------+
//| CreateButton (HUD Element)                                       |
//+------------------------------------------------------------------+
void CreateButton(const string name, const string text, const int x, const int y, const int w, const int h, const color bg_color, const color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0,  name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| RenderVScoreCell (Dynamic 7-Zone Super-Thermal Palette)          |
//+------------------------------------------------------------------+
void RenderVScoreCell(const string symbol, const double val, const string slot_tag, const int x, const int y, const int w, const int h)
  {
   string name = g_prefix + "_" + symbol + "_" + slot_tag;
   string text = "";
   color  bg_color = clrWhite;
   color  text_color = clrBlack;

   if(val == EMPTY_VALUE)
     {
      text = "Sync...";
      bg_color = clrWhite;
      text_color = clrSilver;
     }
   else
     {
      text = DoubleToString(val, 2) + " σ";

      if(val >= InpLevelExtremeHigh)
        {
         bg_color = clrMidnightBlue;
         text_color = clrWhite;
        }
      else
         if(val >= InpLevelClimaxHigh)
           {
            bg_color = clrDeepSkyBlue;
            text_color = clrWhite;
           }
         else
            if(val >= InpLevelFlowHigh)
              {
               bg_color = clrLightSkyBlue;
               text_color = clrBlack;
              }
            else
               if(val <= InpLevelExtremeLow)
                 {
                  bg_color = clrDarkRed;
                  text_color = clrWhite;
                 }
               else
                  if(val <= InpLevelClimaxLow)
                    {
                     bg_color = clrOrangeRed;
                     text_color = clrWhite;
                    }
                  else
                     if(val <= InpLevelFlowLow)
                       {
                        bg_color = clrCoral;
                        text_color = clrBlack;
                       }
                     else
                       {
                        bg_color = clrWhite;
                        text_color = clrDarkGray;
                       }
     }

   CreateButton(name, text, x, y, w, h, bg_color, text_color);
  }

//+------------------------------------------------------------------+
//| RenderDashboard (Dual-Slot HUD Layout Engine)                    |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating)
      return;

   g_updating = true;

   int col_w_sym = 90;
   int col_w_vs  = 95;
   int row_h     = 22;

   string sym = _Symbol;

// 1. Compute Slot 1 and Slot 2 Values in O(1)
   double vs_slot1 = UpdateSlotValue(g_calc_slot1, InpSlot1TF, InpSlot1Reset, InpSlot1Period,
                                     g_s1_prev_calc, g_s1_last_bar_time,
                                     g_s1_rates, g_s1_open, g_s1_high, g_s1_low, g_s1_close,
                                     g_s1_tvol, g_s1_vol, g_s1_time, g_s1_res);

   double vs_slot2 = UpdateSlotValue(g_calc_slot2, InpSlot2TF, InpSlot2Reset, InpSlot2Period,
                                     g_s2_prev_calc, g_s2_last_bar_time,
                                     g_s2_rates, g_s2_open, g_s2_high, g_s2_low, g_s2_close,
                                     g_s2_tvol, g_s2_vol, g_s2_time, g_s2_res);

// 2. Change Guard: Only touch GDI and Redraw if rounded values changed!
   bool changed = (MathAbs(vs_slot1 - g_last_rendered_vs1) >= 0.005 ||
                   MathAbs(vs_slot2 - g_last_rendered_vs2) >= 0.005 ||
                   g_last_rendered_vs1 == EMPTY_VALUE);

   if(!changed)
     {
      g_updating = false;
      return;
     }

   g_last_rendered_vs1 = vs_slot1;
   g_last_rendered_vs2 = vs_slot2;

// 3. Render Table Header (Y coordinates grow UPWARDS)
   int header_y = InpTableY + row_h + 2;

   string s1_tf = StringSubstr(EnumToString(InpSlot1TF), 7);
   string s2_tf = StringSubstr(EnumToString(InpSlot2TF), 7);

   string s1_header = InpSlot1Label + " (" + s1_tf + ")";
   string s2_header = InpSlot2Label + " (" + s2_tf + ")";

   CreateButton(g_prefix + "H_Sym", "Symbol", InpTableX, header_y, col_w_sym, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_S1",  s1_header, InpTableX + col_w_sym + 2, header_y, col_w_vs, row_h, clrDarkSlateGray, clrWhite);
   CreateButton(g_prefix + "H_S2",  s2_header, InpTableX + col_w_sym + col_w_vs + 4, header_y, col_w_vs, row_h, clrDarkSlateGray, clrWhite);

// 4. Render Data Row
   int row_y = InpTableY;
   CreateButton(g_prefix + "_SymLbl_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack);

// Render Dual Cells side-by-side
   RenderVScoreCell(sym, vs_slot1, "Slot1", InpTableX + col_w_sym + 2, row_y, col_w_vs, row_h);
   RenderVScoreCell(sym, vs_slot2, "Slot2", InpTableX + col_w_sym + col_w_vs + 4, row_y, col_w_vs, row_h);

   ChartRedraw(0);
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_updating          = false;
   g_last_update_ms    = 0;
   g_last_rendered_vs1 = EMPTY_VALUE;
   g_last_rendered_vs2 = EMPTY_VALUE;
   g_s1_prev_calc      = 0;
   g_s2_prev_calc      = 0;
   g_s1_last_bar_time  = 0;
   g_s2_last_bar_time  = 0;

   g_prefix = StringFormat("VSDW_%I64d_", ChartID());
   ObjectsDeleteAll(0, g_prefix);

   bool is_ha = (InpCandleSource == CANDLE_HEIKIN_ASHI);

   if(InpSlot1Reset == PERIOD_CUSTOM_SESSION)
      g_calc_slot1.Init(InpSlot1Period, InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, InpTzShift, is_ha, 100);
   else
      g_calc_slot1.Init(InpSlot1Period, InpSlot1Reset, InpVolumeType, InpTzShift, is_ha, 100);

   if(InpSlot2Reset == PERIOD_CUSTOM_SESSION)
      g_calc_slot2.Init(InpSlot2Period, InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, InpTzShift, is_ha, 100);
   else
      g_calc_slot2.Init(InpSlot2Period, InpSlot2Reset, InpVolumeType, InpTzShift, is_ha, 100);

   RenderDashboard();

   EventSetTimer(InpRefreshSeconds);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
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
   ulong current_ms = GetTickCount64();
   if(current_ms - g_last_update_ms >= 200)
     {
      g_last_update_ms = current_ms;
      RenderDashboard();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderDashboard();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
