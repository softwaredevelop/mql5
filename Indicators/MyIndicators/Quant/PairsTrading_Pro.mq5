//+------------------------------------------------------------------+
//|                                             PairsTrading_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.30" // Added custom session time-range anchor reset and night filtering
#property description "Universal Dynamic & Anchored Cointegration (Z-Score) Monitor."
#property description "Supports custom broker-time session ranges to eliminate gap distortion."
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Standardized window limits to prevent single-spike scale squishing!
#property indicator_minimum -3.5
#property indicator_maximum 3.5

//--- Institutional Levels Configuration (Perfect alignment under fixed scale)
#property indicator_level1 2.5
#property indicator_level2 2.0
#property indicator_level3 1.5
#property indicator_level4 -1.5
#property indicator_level5 -2.0
#property indicator_level6 -2.5

#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot: Color Histogram (5-Zone Thermal Palette)
#property indicator_label1  "Spread Z-Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// 5-Color Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bull Flow         (Coral - warning)
// 2: Bull Extreme      (OrangeRed - Sell Spread zone)
// 3: Bear Flow         (LightSkyBlue - warning)
// 4: Bear Extreme      (DeepSkyBlue - Buy Spread zone)
#property indicator_color1  clrGray, clrCoral, clrOrangeRed, clrLightSkyBlue, clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\PairsTrading_Calculator.mqh>

//--- Anchored Timeframe Resets Enum
enum ENUM_ANCHOR_PERIOD
  {
   ANCHOR_NONE,           // Standard rolling window (InpLookback)
   ANCHOR_SESSION,        // Reset every day (Daily VWAP style)
   ANCHOR_WEEK,           // Reset every week (Weekly VWAP style)
   ANCHOR_MONTH,          // Reset every month (Monthly VWAP style)
   ANCHOR_CUSTOM_SESSION  // Reset based on custom broker-time start/end range
  };

//--- Input Parameters
input string            InpSymbolA      = "UKOIL";  // Symbol A (Brent Proxy, e.g. UKOIL or BRENT)
input string            InpSymbolB      = "USOIL";  // Symbol B (WTI Proxy, e.g. USOIL or WTI)
input ENUM_ANCHOR_PERIOD InpAnchor       = ANCHOR_NONE; // Dynamic Anchored Reset Period
input int               InpLookback     = 120;      // Rolling Window size (Used if Anchor = NONE)
input string            InpCustomStart  = "09:00";  // Custom Session Start (HH:MM, Broker Time)
input string            InpCustomEnd    = "18:00";  // Custom Session End (HH:MM, Broker Time)

//--- Buffers
double ExtZScoreBuffer[];
double ExtColorsBuffer[];

//--- Aligned price arrays
double g_sync_close_A[];
double g_sync_close_B[];

//--- Global Engine and State Tracking
CPairsTradingCalculator *g_calc;
bool                     g_data_synced       = false;
int                      g_anchor_start_idx  = 0; // Dynamic anchor index tracker

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
//| Determines if broker time is within custom active session        |
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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_synced = false;
   g_anchor_start_idx = 0;

   SetIndexBuffer(0, ExtZScoreBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorsBuffer, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(ExtZScoreBuffer, false);
   ArraySetAsSeries(ExtColorsBuffer, false);

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

// Configure shortname dynamically based on mode
   string anchor_name = EnumToString(InpAnchor);
   string short_name = StringFormat("PairsTrade Pro(%s vs %s, %s)",
                                    InpSymbolA, InpSymbolB,
                                    (InpAnchor == ANCHOR_NONE ? (string)InpLookback : StringSubstr(anchor_name, 7)));

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   g_calc = new CPairsTradingCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpLookback))
     {
      Print("Error: Failed to initialize PairsTrading Calculator.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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
   int required_bars = InpLookback + 10;
   if(InpAnchor != ANCHOR_NONE)
      required_bars = 1000; // Need larger history depth for monthly/weekly/custom anchors

//--- Ensure both symbol histories are fully loaded in the terminal
   if(!EnsureDataReady(InpSymbolA, _Period, required_bars) ||
      !EnsureDataReady(InpSymbolB, _Period, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- Get standalone default fallback values to ensure absolute chart independence
   double default_close_A = iClose(InpSymbolA, _Period, 0);
   double default_close_B = iClose(InpSymbolB, _Period, 0);

//--- 1. Advanced Bar-Time Synchronization & Alignment Loop (O(1) incremental)
   ArrayResize(g_sync_close_A, rates_total);
   ArrayResize(g_sync_close_B, rates_total);

   int loop_start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start < 0)
      loop_start = 0;

   for(int i = loop_start; i < rates_total; i++)
     {
      // Sync Symbol A Price
      int shift_A = iBarShift(InpSymbolA, _Period, time[i], false);
      if(shift_A >= 0)
         g_sync_close_A[i] = iClose(InpSymbolA, _Period, shift_A);
      else
         g_sync_close_A[i] = (i > 0) ? g_sync_close_A[i-1] : default_close_A; // FIXED: chart-independent fallback

      // Sync Symbol B Price
      int shift_B = iBarShift(InpSymbolB, _Period, time[i], false);
      if(shift_B >= 0)
         g_sync_close_B[i] = iClose(InpSymbolB, _Period, shift_B);
      else
         g_sync_close_B[i] = (i > 0) ? g_sync_close_B[i-1] : default_close_B; // FIXED: chart-independent fallback
     }

//--- 2. Calculate the rolling OLS Cointegration Z-Score
   int calc_start = (prev_calculated == 0) ? InpLookback : prev_calculated - 1;
   if(calc_start < InpLookback)
      calc_start = InpLookback;

   for(int i = calc_start; i < rates_total; i++)
     {
      //--- A. Filter out inactive hours if custom session anchor is selected
      if(InpAnchor == ANCHOR_CUSTOM_SESSION)
        {
         if(!IsTimeInSession(time[i], g_start_hour, g_start_min, g_end_hour, g_end_min))
           {
            ExtZScoreBuffer[i] = EMPTY_VALUE; // Plot absolutely nothing overnight to keep statistics pure!
            ExtColorsBuffer[i] = 0.0;
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
         active_window_size = InpLookback;
        }
      else
        {
         active_window_size = i - g_anchor_start_idx + 1;
        }

      //--- D. Calculate Z-Score
      double z = g_calc.CalculateZScore(rates_total, i, active_window_size, g_sync_close_A, g_sync_close_B);
      ExtZScoreBuffer[i] = z;

      //--- 3. 5-Zone Thermal Color Mapping
      if(z == 0.0)
        {
         ExtColorsBuffer[i] = 0.0; // Seed/Unstable bars stay Gray
        }
      else
         if(z >= 2.0)
           {
            ExtColorsBuffer[i] = 2.0; // Index 2: OrangeRed (Sell Spread)
           }
         else
            if(z >= 1.5)
              {
               ExtColorsBuffer[i] = 1.0; // Index 1: Coral (Sell Warning)
              }
            else
               if(z <= -2.0)
                 {
                  ExtColorsBuffer[i] = 4.0; // Index 4: DeepSkyBlue (Buy Spread)
                 }
               else
                  if(z <= -1.5)
                    {
                     ExtColorsBuffer[i] = 3.0; // Index 3: LightSkyBlue (Buy Warning)
                    }
                  else
                    {
                     ExtColorsBuffer[i] = 0.0; // Index 0: Gray (Neutral Noise)
                    }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
