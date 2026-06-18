//+------------------------------------------------------------------+
//|                                                  LLD_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.21" // Standardized HTF synchronization and alignment logic
#property description "Lead-Lag Dominance Index (LLDI) Multi-Timeframe Oscillator."
#property description "Displays Higher Timeframe LLDI color histogram directly on lower TF chart."
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2  // Plot 1: LLDI MTF, Plot 2: Optimal Lag MTF (Hidden on chart, shown in Data Window)

//--- Institutional Levels Configuration (Z-Score standard layout)
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5
#property indicator_level4 -1.5
#property indicator_level5 -2.0
#property indicator_level6 -2.5

#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Lead-Lag Dominance Index (LLDI Color Histogram)
#property indicator_label1  "LLDI MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrCrimson, clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 2: Optimal Lag (Invisible on chart, mapped to Data Window)
#property indicator_label2  "Optimal Lag MTF"
#property indicator_type2   DRAW_NONE

#include <MyIncludes\LLD_Calculator.mqh>

//--- Anchored Timeframe Resets Enum
enum ENUM_ANCHOR_PERIOD
  {
   ANCHOR_NONE,           // Standard rolling window (InpWindowSize)
   ANCHOR_SESSION,        // Reset every day (Daily VWAP style)
   ANCHOR_WEEK,           // Reset every week (Weekly VWAP style)
   ANCHOR_MONTH,          // Reset every month (Monthly VWAP style)
   ANCHOR_CUSTOM_SESSION  // Reset based on custom broker-time start/end range
  };

//--- Input Parameters
input string            InpSecondSymbol   = "BTCUSD"; // Comparison Symbol
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_M5; // Target Higher Timeframe (Recommended: Higher than Chart)
input ENUM_ANCHOR_PERIOD InpAnchor         = ANCHOR_NONE; // Dynamic Anchored Reset Period
input int               InpWindowSize     = 50;       // Rolling Window size (Used if Anchor = NONE)
input int               InpMaxLag         = 10;       // Maximum Phase Shift (Lags)
input string            InpCustomStart    = "09:00";  // Custom Session Start (HH:MM, Broker Time)
input string            InpCustomEnd      = "18:00";  // Custom Session End (HH:MM, Broker Time)

//--- Buffers
double BufferLLDI[];
double BufferColors[];
double BufferLag[];

//--- Internal HTF Data Caches
datetime h_time[];
double   h_close_A[];
double   h_close_B[];

//--- HTF Calculator Results
double   h_res_lldi[];
double   h_res_lag[];

//--- Aligned secondary symbol close prices array (Global Cache)
double   g_close_B[];

//--- Global Engine and State Tracking
CLeadLagDominanceCalculator *g_calculator;
datetime                 g_last_htf_time     = 0;
int                      g_htf_count         = 0;
bool                     g_data_ready        = false;
int                      g_htf_anchor_start  = 0; // Dynamic anchor tracker on HTF timeline
bool                     g_data_synced       = false;
string                   g_prefix            = "";

//--- Parsed Custom Session hours
int                      g_start_hour        = 9;
int                      g_start_min         = 0;
int                      g_end_hour          = 18;
int                      g_end_min           = 0;

//+------------------------------------------------------------------+
//| EnsureHTFDataReady                                               |
//+------------------------------------------------------------------+
bool EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      SymbolSelect(symbol, true);
     }
   datetime times[];
   int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
   return (copied >= required_bars);
  }

//+------------------------------------------------------------------+
//| IsTimeInSession                                                  |
//+------------------------------------------------------------------+
bool IsTimeInSession(datetime time_val, int start_hour, int start_min, int end_hour, int end_min)
  {
   MqlDateTime dt;
   TimeToStruct(time_val, dt);
   int current_min = dt.hour * 60 + dt.min;
   int start_total = start_hour * 60 + start_min;
   int end_total   = end_hour * 60 + end_min;

   if(end_total < start_total) // Overlapping midnight session
     {
      return (current_min >= start_total || current_min < end_total);
     }
   else
     {
      return (current_min >= start_total && current_min < end_total);
     }
  }

//+------------------------------------------------------------------+
//| UpdateStatusLabel                                                |
//| Renders an institutional colored text summary with subwindow lock|
//+------------------------------------------------------------------+
void UpdateStatusLabel(int subwindow, double last_lldi, double last_lag)
  {
   string name = StringFormat("%sStatus_Sub_%d", g_prefix, subwindow);

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, subwindow, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 15);
      ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
     }

   string dominance_text = "";
   color text_color = clrGray;

   string str_lag = DoubleToString(MathAbs(last_lag), 0);
   string str_strength = DoubleToString(MathAbs(last_lldi), 5);

   if(last_lldi == EMPTY_VALUE || last_lldi == 0.0)
     {
      dominance_text = "REGIME: SYNCHRONIZING / NO ACTIVE DATA";
      text_color = clrGray;
     }
   else
      if(last_lldi > 0.02)
        {
         dominance_text = StringFormat("REGIME: %s LEADS %s | Lead Time: %s bars | Strength: %s",
                                       InpSecondSymbol, _Symbol, str_lag, str_strength);
         text_color = clrDodgerBlue;
        }
      else
         if(last_lldi < -0.02)
           {
            dominance_text = StringFormat("REGIME: %s LEADS %s | Lead Time: %s bars | Strength: %s",
                                          _Symbol, InpSecondSymbol, str_lag, str_strength);
            text_color = clrCrimson;
           }
         else
           {
            dominance_text = StringFormat("REGIME: SYMMETRICAL / CO-DEPENDENT | Difference: %s", str_strength);
            text_color = clrGray;
           }

   ObjectSetString(0, name, OBJPROP_TEXT, dominance_text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_last_htf_time = 0;
   g_htf_count = 0;
   g_htf_anchor_start = 0;
   g_prefix = StringFormat("LLD_%x_", ChartID());

//--- Verify if the secondary comparison symbol exists in broker offerings
   bool is_custom = false;
   if(!SymbolExist(InpSecondSymbol, is_custom))
     {
      string err_msg = StringFormat("LLD MTF Error: Symbol '%s' does not exist in your broker's database!", InpSecondSymbol);
      Alert(err_msg);
      Print(err_msg);
      return(INIT_FAILED);
     }

//--- Bind indicator buffers
   SetIndexBuffer(0, BufferLLDI, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferLag,    INDICATOR_DATA); // Map to INDICATOR_DATA for Data Window visibility

   ArraySetAsSeries(BufferLLDI, false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferLag, false);

// Configure Plots
// Plot 1: LLDI MTF Color Histogram
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetString(0, PLOT_LABEL, "LLDI MTF");

// Plot 2: Optimal Lag MTF (DRAW_NONE - Hidden on chart, shown in Data Window)
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(1, PLOT_LABEL, "Optimal Lag MTF");

//--- Parse custom session times
   string parts[];
   if(StringSplit(InpCustomStart, ':', parts) == 2)
     {
      g_start_hour = (int)StringToInteger(parts[0]);
      g_start_min  = (int)StringToInteger(parts[1]);
     }
   if(StringSplit(InpCustomEnd, ':', parts) == 2)
     {
      g_end_hour = (int)StringToInteger(parts[0]);
      g_end_min  = (int)StringToInteger(parts[1]);
     }

//--- Clean stale objects
   ObjectsDeleteAll(0, g_prefix);

//--- Dynamic Engine Allocation
   g_calculator = new CLeadLagDominanceCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpWindowSize, InpMaxLag))
     {
      Print("Error: Failed to initialize LLD MTF Calculator Engine.");
      return INIT_FAILED;
     }

   string anchor_name = EnumToString(InpAnchor);
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string short_name = StringFormat("LLDI MTF(%s, %s, %s, %d)",
                                    InpSecondSymbol, tf_name,
                                    (InpAnchor == ANCHOR_NONE ? (string)InpWindowSize : StringSubstr(anchor_name, 7)),
                                    InpMaxLag);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 5);

//--- Initialize 1-second timer for weekend/async chart refreshes
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
     }
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
//--- Ensure both primary and secondary symbol histories are fully loaded on the HTF
   int required_bars = InpWindowSize + InpMaxLag + 10;
   if(InpAnchor != ANCHOR_NONE)
      required_bars = 1000; // Need larger history depth for monthly/weekly/custom anchors

   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars) ||
      !EnsureHTFDataReady(InpSecondSymbol, InpTimeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- 1. Advanced Bar-Time Price Alignment Loop (O(1) incremental)
   ArrayResize(g_close_B, rates_total);

   int loop_start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start < 0)
      loop_start = 0;

   double default_close_B = iClose(InpSecondSymbol, _Period, 0);

   for(int i = loop_start; i < rates_total; i++)
     {
      int shift = iBarShift(InpSecondSymbol, _Period, time[i], false);
      if(shift >= 0)
        {
         g_close_B[i] = iClose(InpSecondSymbol, _Period, shift);
        }
      else
        {
         g_close_B[i] = (i > 0) ? g_close_B[i-1] : default_close_B;
        }
     }

//--- 2. Check if a new HTF bar has formed
   datetime htf_time_current = iTime(_Symbol, InpTimeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, InpTimeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 1000);

      ArrayResize(h_time, g_htf_count);
      ArrayResize(h_close_A, g_htf_count);
      ArrayResize(h_close_B, g_htf_count);
      ArrayResize(h_res_lldi, g_htf_count);
      ArrayResize(h_res_lag, g_htf_count);

      if(CopyTime(_Symbol, InpTimeframe, 0, g_htf_count, h_time) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- 3. Linear Price Alignment on the HTF Timeline using safe fallbacks
      double default_close_A = iClose(_Symbol, InpTimeframe, 0);
      default_close_B = iClose(InpSecondSymbol, InpTimeframe, 0);

      for(int j = 0; j < g_htf_count; j++)
        {
         int shift_A = iBarShift(_Symbol, InpTimeframe, h_time[j], false);
         if(shift_A >= 0)
            h_close_A[j] = iClose(_Symbol, InpTimeframe, shift_A);
         else
            h_close_A[j] = (j > 0) ? h_close_A[j-1] : default_close_A;

         int shift_B = iBarShift(InpSecondSymbol, InpTimeframe, h_time[j], false);
         if(shift_B >= 0)
            h_close_B[j] = iClose(InpSecondSymbol, InpTimeframe, shift_B);
         else
            h_close_B[j] = (j > 0) ? h_close_B[j-1] : default_close_B;
        }

      //--- 4. Calculate OLS Cointegration on HTF (Closed bars only!)
      //--- Notice the limit is 'g_htf_count - 1' (excluding the live forming bar)
      for(int j = InpWindowSize; j < g_htf_count - 1; j++)
        {
         // Filter out inactive custom hours on HTF
         if(InpAnchor == ANCHOR_CUSTOM_SESSION)
           {
            if(!IsTimeInSession(h_time[j], g_start_hour, g_start_min, g_end_hour, g_end_min))
              {
               h_res_lldi[j] = EMPTY_VALUE;
               h_res_lag[j]  = 0.0;
               continue;
              }
           }

         // Stateful anchor period tracking on HTF timeline
         bool htf_new_period = false;
         if(j > 0)
           {
            switch(InpAnchor)
              {
               case ANCHOR_SESSION:
                 {
                  MqlDateTime dt_curr, dt_prev;
                  TimeToStruct(h_time[j], dt_curr);
                  TimeToStruct(h_time[j-1], dt_prev);
                  if(dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year)
                     htf_new_period = true;
                  break;
                 }
               case ANCHOR_WEEK:
                 {
                  MqlDateTime dt_curr, dt_prev;
                  TimeToStruct(h_time[j], dt_curr);
                  TimeToStruct(h_time[j-1], dt_prev);
                  if(dt_curr.day_of_week < dt_prev.day_of_week)
                     htf_new_period = true;
                  break;
                 }
               case ANCHOR_MONTH:
                 {
                  MqlDateTime dt_curr, dt_prev;
                  TimeToStruct(h_time[j], dt_curr);
                  TimeToStruct(h_time[j-1], dt_prev);
                  if(dt_curr.mon != dt_prev.mon || dt_curr.year != dt_prev.year)
                     htf_new_period = true;
                  break;
                 }
               case ANCHOR_CUSTOM_SESSION:
                 {
                  MqlDateTime dt_curr, dt_prev;
                  TimeToStruct(h_time[j], dt_curr);
                  TimeToStruct(h_time[j-1], dt_prev);
                  int min_curr = dt_curr.hour * 60 + dt_curr.min;
                  int min_prev = dt_prev.hour * 60 + dt_prev.min;
                  int start_min = g_start_hour * 60 + g_start_min;
                  bool day_changed = (dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year);
                  if(day_changed)
                    {
                     if(min_curr >= start_min)
                        htf_new_period = true;
                    }
                  else
                    {
                     if(min_prev < start_min && min_curr >= start_min)
                        htf_new_period = true;
                    }
                  break;
                 }
               default:
                  break;
              }
           }

         if(htf_new_period)
           {
            g_htf_anchor_start = j;
           }

         int htf_active_window = 0;
         if(InpAnchor == ANCHOR_NONE)
            htf_active_window = InpWindowSize;
         else
            htf_active_window = j - g_htf_anchor_start + 1;

         // Compute LLDI and Lag on HTF (Single-index O(1) calculation)
         double lldi_val = 0.0;
         double lag_val = 0.0;
         g_calculator.CalculateDominance(g_htf_count, j, htf_active_window, h_close_A, h_close_B, lldi_val, lag_val);

         h_res_lldi[j] = lldi_val;
         h_res_lag[j]  = lag_val;
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 5. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpWindowSize)
     {
      double single_c_A[1], single_c_B[1];

      // Synchronized live price copying from the forming HTF bar 0
      int shift_A = iBarShift(_Symbol, InpTimeframe, htf_time_current, false);
      int shift_B = iBarShift(InpSecondSymbol, InpTimeframe, htf_time_current, false);

      if(shift_A >= 0 && shift_B >= 0 &&
         CopyClose(_Symbol, InpTimeframe, shift_A, 1, single_c_A) == 1 &&
         CopyClose(InpSecondSymbol, InpTimeframe, shift_B, 1, single_c_B) == 1)
        {
         h_close_A[live_idx] = single_c_A[0];
         h_close_B[live_idx] = single_c_B[0];

         // Determine dynamic window for forming bar
         int htf_active_window = 0;
         if(InpAnchor == ANCHOR_NONE)
            htf_active_window = InpWindowSize;
         else
            htf_active_window = live_idx - g_htf_anchor_start + 1;

         if(InpAnchor != ANCHOR_CUSTOM_SESSION || IsTimeInSession(htf_time_current, g_start_hour, g_start_min, g_end_hour, g_end_min))
           {
            double lldi_val = 0.0;
            double lag_val = 0.0;
            g_calculator.CalculateDominance(g_htf_count, live_idx, htf_active_window, h_close_A, h_close_B, lldi_val, lag_val);
            h_res_lldi[live_idx] = lldi_val;
            h_res_lag[live_idx]  = lag_val;
           }
         else
           {
            h_res_lldi[live_idx] = EMPTY_VALUE;
            h_res_lag[live_idx]  = 0.0;
           }
        }
     }

//--- 6. Dynamically adjust 'start' to the beginning of the current forming HTF bar
//--- This forces the entire forming LTF step block to remain perfectly flat, updating on every tick!
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // This is the start of the forming step on lower TF chart

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 7. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            double z = h_res_lldi[idx_htf];
            BufferLLDI[i] = z;
            BufferLag[i]  = h_res_lag[idx_htf];

            //--- 5-Zone Thermal Color Mapping on mapped Z-Score
            if(z == EMPTY_VALUE || z == 0.0)
              {
               BufferColors[i] = 2.0;
              }
            else
               if(z > 0.02)
                 {
                  BufferColors[i] = 0.0; // Index 0: DodgerBlue (Second Symbol leads)
                 }
               else
                  if(z < -0.02)
                    {
                     BufferColors[i] = 1.0; // Index 1: Crimson (Chart Symbol leads)
                    }
                  else
                    {
                     BufferColors[i] = 2.0; // Index 2: Gray (Tied / Symmetrical)
                    }
           }
         else
           {
            BufferLLDI[i] = EMPTY_VALUE;
            BufferColors[i] = 2.0;
            BufferLag[i]    = 0.0;
           }
        }
      else
        {
         BufferLLDI[i] = EMPTY_VALUE;
         BufferColors[i] = 2.0;
         BufferLag[i]    = 0.0;
        }
     }

//--- 8. Update status label on the last historical bar
   int subwindow = ChartWindowFind();
   if(subwindow >= 0 && rates_total > 0)
     {
      UpdateStatusLabel(subwindow, BufferLLDI[rates_total - 1], BufferLag[rates_total - 1]);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//| Handles loading checks and force-redraws                         |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_data_synced)
     {
      int required_bars = InpWindowSize + InpMaxLag + 5;
      if(EnsureHTFDataReady(InpSecondSymbol, _Period, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
