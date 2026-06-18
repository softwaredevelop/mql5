//+------------------------------------------------------------------+
//|                                                      LLD_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.53" // Fixed separate window scale, label collisions and Data Window visibility
#property description "Lead-Lag Dominance Index (LLDI) with 5-decimal live tracking and anchors."
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2  // Plot 1: LLDI, Plot 2: Optimal Lag (Hidden on chart, shown in Data Window)

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
#property indicator_label1  "LLDI"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrCrimson, clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 2: Optimal Lag (Invisible on chart, mapped to Data Window)
#property indicator_label2  "Optimal Lag"
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
input ENUM_ANCHOR_PERIOD InpAnchor         = ANCHOR_NONE; // Dynamic Anchored Reset Period
input int               InpWindowSize     = 50;       // Rolling Window size (Used if Anchor = NONE)
input int               InpMaxLag         = 10;       // Maximum Phase Shift (Lags)
input string            InpCustomStart    = "09:00";  // Custom Session Start (HH:MM, Broker Time)
input string            InpCustomEnd      = "18:00";  // Custom Session End (HH:MM, Broker Time)

//--- Buffers
double ExtZScoreBuffer[];
double ExtColorsBuffer[];
double ExtLagBuffer[];

//--- Aligned secondary symbol close prices array
double    g_close_B[];

//--- Calculator Engine Pointer
CLeadLagDominanceCalculator *g_calculator;

//--- Global states for weekend/asynchronous loading
bool      g_data_synced       = false;
string    g_obj_prefix        = "";
int       g_anchor_start_idx  = 0; // Dynamic anchor index tracker

//--- Parsed Custom Session hours
int                      g_start_hour        = 9;
int                      g_start_min         = 0;
int                      g_end_hour          = 18;
int                      g_end_min           = 0;

//+------------------------------------------------------------------+
//| EnsureDataReady (Multi-symbol history sync helper)               |
//+------------------------------------------------------------------+
bool EnsureDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
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
// FIXED: Include subwindow index in object name to prevent overlap collisions!
   string name = StringFormat("%sStatus_Sub_%d", g_obj_prefix, subwindow);

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
   g_data_synced = false;
   g_anchor_start_idx = 0;
   g_obj_prefix = StringFormat("LLD_%x_", ChartID());

//--- Verify if the secondary comparison symbol exists in broker offerings
   bool is_custom = false;
   if(!SymbolExist(InpSecondSymbol, is_custom))
     {
      string err_msg = StringFormat("LLD Pro Error: Symbol '%s' does not exist in your broker's database!", InpSecondSymbol);
      Alert(err_msg);
      Print(err_msg);
      return(INIT_FAILED);
     }

//--- Bind indicator buffers
   SetIndexBuffer(0, ExtZScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtLagBuffer,    INDICATOR_DATA); // FIXED: Set as INDICATOR_DATA for Data Window mapping

   ArraySetAsSeries(ExtZScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);
   ArraySetAsSeries(ExtLagBuffer, false);

//--- Configure Plot Properties
// Plot 1: LLDI Color Histogram
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetString(0, PLOT_LABEL, "LLDI");

// Plot 2: Optimal Lag (DRAW_NONE - Hidden on chart, shown in Data Window)
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(1, PLOT_LABEL, "Optimal Lag");

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
   ObjectsDeleteAll(0, g_obj_prefix);

//--- Dynamic Engine Allocation
   g_calculator = new CLeadLagDominanceCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpWindowSize, InpMaxLag))
     {
      Print("LLD System: Failed to initialize Engine.");
      return(INIT_FAILED);
     }

   string anchor_name = EnumToString(InpAnchor);
   string short_name = StringFormat("LLDI(%s, %s, %d)",
                                    InpSecondSymbol,
                                    (InpAnchor == ANCHOR_NONE ? (string)InpWindowSize : StringSubstr(anchor_name, 7)),
                                    InpMaxLag);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 5); // Default separate window digits to 5

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
   ObjectsDeleteAll(0, g_obj_prefix);

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
//--- Ensure secondary symbol history is ready
   int required_bars = InpWindowSize + InpMaxLag + 10;
   if(InpAnchor != ANCHOR_NONE)
      required_bars = 1000; // Need larger history depth for monthly/weekly/custom anchors

   if(!EnsureDataReady(InpSecondSymbol, _Period, required_bars))
     {
      g_data_synced = false;
      return 0;
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

//--- 2. Incremental Tick Calculation with dynamic Anchored/VWAP resets
   int start_index = (prev_calculated == 0) ? InpWindowSize + InpMaxLag + 5 : prev_calculated - 1;
   if(start_index < InpWindowSize + InpMaxLag + 5)
      start_index = InpWindowSize + InpMaxLag + 5;

   for(int i = start_index; i < rates_total; i++)
     {
      //--- A. Filter out inactive hours if custom session anchor is selected
      if(InpAnchor == ANCHOR_CUSTOM_SESSION)
        {
         if(!IsTimeInSession(time[i], g_start_hour, g_start_min, g_end_hour, g_end_min))
           {
            ExtZScoreBuffer[i] = EMPTY_VALUE; // Plot absolutely nothing overnight to keep statistics pure!
            ExtColorsBuffer[i] = 0.0;
            ExtLagBuffer[i]    = 0.0;
            continue;
           }
        }

      //--- B. Check if a new Anchor period has started (Stateful tracking)
      bool new_period = false;

      switch(InpAnchor)
        {
         case ANCHOR_SESSION:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year)
               new_period = true;
            break;
           }
         case ANCHOR_WEEK:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.day_of_week < dt_prev.day_of_week)
               new_period = true;
            break;
           }
         case ANCHOR_MONTH:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_curr.mon != dt_prev.mon || dt_curr.year != dt_prev.year)
               new_period = true;
            break;
           }
         case ANCHOR_CUSTOM_SESSION:
           {
            MqlDateTime dt_curr, dt_prev;
            TimeToStruct(time[i], dt_curr);
            TimeToStruct(time[i-1], dt_prev);

            int min_curr = dt_curr.hour * 60 + dt_curr.min;
            int min_prev = dt_prev.hour * 60 + dt_prev.min;
            int start_min = g_start_hour * 60 + g_start_min;

            bool day_changed = (dt_curr.day_of_year != dt_prev.day_of_year || dt_curr.year != dt_prev.year);

            if(day_changed)
              {
               if(min_curr >= start_min)
                  new_period = true;
              }
            else
              {
               if(min_prev < start_min && min_curr >= start_min)
                  new_period = true;
              }
            break;
           }
         default:
            break;
        }

      if(new_period)
        {
         g_anchor_start_idx = i;
        }

      //--- C. Compute the dynamic window size
      int active_window_size = 0;
      if(InpAnchor == ANCHOR_NONE)
        {
         active_window_size = InpWindowSize;
        }
      else
        {
         active_window_size = i - g_anchor_start_idx + 1;
        }

      //--- D. Run mathematical engine calculations with dynamic window and state arrays
      double lldi_val = 0.0;
      double lag_val = 0.0;

      if(g_calculator.CalculateDominance(rates_total, i, active_window_size, close, g_close_B, lldi_val, lag_val))
        {
         ExtZScoreBuffer[i] = lldi_val;
         ExtLagBuffer[i]    = lag_val;
        }
      else
        {
         ExtZScoreBuffer[i] = 0.0;
         ExtLagBuffer[i]    = 0.0;
        }
     }

//--- 3. Colorize the histogram based on Dominance regime (O(1) incremental)
   int start_pos = InpWindowSize + InpMaxLag + 1;
   int loop_start_color = MathMax(start_pos, prev_calculated - 1);

   for(int i = loop_start_color; i < rates_total; i++)
     {
      double z = ExtZScoreBuffer[i];

      if(z == EMPTY_VALUE)
        {
         ExtColorsBuffer[i] = 2.0; // Gray
        }
      else
         if(z > 0.02)
           {
            ExtColorsBuffer[i] = 0.0; // Index 0: DodgerBlue (Second Symbol leads)
           }
         else
            if(z < -0.02)
              {
               ExtColorsBuffer[i] = 1.0; // Index 1: Crimson (Chart Symbol leads)
              }
            else
              {
               ExtColorsBuffer[i] = 2.0; // Index 2: Gray (Tied / Symmetrical)
              }
     }

//--- 4. Update status label on the last historical bar
   int subwindow = ChartWindowFind();
   if(subwindow >= 0 && rates_total > 0)
     {
      UpdateStatusLabel(subwindow, ExtZScoreBuffer[rates_total - 1], ExtLagBuffer[rates_total - 1]);
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
      if(EnsureDataReady(InpSecondSymbol, _Period, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
