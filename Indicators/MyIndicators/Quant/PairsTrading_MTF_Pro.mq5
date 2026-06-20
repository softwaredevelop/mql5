//+------------------------------------------------------------------+
//|                                             PairsTrading_MTF_Pro |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Refactored with single comparison symbol and hybrid block-copy alignment
#property description "Universal Dynamic & Anchored Cointegration (Z-Score) Monitor."
#property description "Displays Higher Timeframe Cointegration Z-Score directly on lower TF chart."
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
#property indicator_label1  "Spread Z-Score MTF"
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
input string            InpSecondSymbol       = "USOIL";   // Comparison Symbol (Symbol B)
input ENUM_TIMEFRAMES   InpTimeframe          = PERIOD_M5; // Target Higher Timeframe (Recommended: Higher than Chart)
input ENUM_ANCHOR_PERIOD InpAnchor             = ANCHOR_NONE; // Dynamic Anchored Reset Period
input int               InpLookback           = 120;       // Rolling Window size (Used if Anchor = NONE)
input string            InpCustomStart        = "09:00";   // Custom Session Start (HH:MM, Broker Time)
input string            InpCustomEnd          = "18:00";   // Custom Session End (HH:MM, Broker Time)

//--- Buffers
double ExtZScoreBuffer[];
double ExtColorsBuffer[];

//--- Internal HTF Data Caches
datetime h_time[];
double   h_close_A[];
double   h_close_B[];

//--- HTF Calculator Results
double   h_res_z[];

//--- Global HTF State Tracking
CPairsTradingCalculator *g_calc;
datetime                 g_last_htf_time     = 0;
int                      g_htf_count         = 0;
bool                     g_data_ready        = false;
int                      g_htf_anchor_start  = 0; // Dynamic anchor tracker on HTF timeline

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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_last_htf_time = 0;
   g_htf_count = 0;
   g_htf_anchor_start = 0;

//--- Verify if the secondary comparison symbol exists in broker offerings
   bool is_custom = false;
   if(!SymbolExist(InpSecondSymbol, is_custom))
     {
      string err_msg = StringFormat("PairsTrading MTF Error: Symbol '%s' does not exist in your broker's database!", InpSecondSymbol);
      Alert(err_msg);
      Print(err_msg);
      return(INIT_FAILED);
     }

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
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string short_name = StringFormat("PairsTrade MTF(%s vs %s, %s, %s)",
                                    _Symbol, InpSecondSymbol, tf_name,
                                    (InpAnchor == ANCHOR_NONE ? (string)InpLookback : StringSubstr(anchor_name, 7)));

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- Instantiate unified calculator
   g_calc = new CPairsTradingCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpLookback))
     {
      Print("Error: Failed to initialize PairsTrade MTF Calculator Engine.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calc) != POINTER_INVALID)
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

//--- Ensure both symbol histories are fully loaded on the HTF in the terminal
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars) ||
      !EnsureHTFDataReady(InpSecondSymbol, InpTimeframe, required_bars))
     {
      g_data_ready = false;
      return 0; // Wait for next tick to let history load
     }

//--- 1. Check if a new HTF bar has formed
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
      ArrayResize(h_res_z, g_htf_count);

      if(CopyTime(_Symbol, InpTimeframe, 0, g_htf_count, h_time) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- 2. High-Performance Hybrid Price Alignment on the HTF Timeline
      //--- Step A: Copy chart native symbol close prices via ultra-fast block copy
      if(CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close_A) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Step B: Sync comparison symbol prices via time-aligned fallback loop
      double default_close_B = iClose(InpSecondSymbol, InpTimeframe, 0);

      for(int j = 0; j < g_htf_count; j++)
        {
         int shift_B = iBarShift(InpSecondSymbol, InpTimeframe, h_time[j], false);
         if(shift_B >= 0)
            h_close_B[j] = iClose(InpSecondSymbol, InpTimeframe, shift_B);
         else
            h_close_B[j] = (j > 0) ? h_close_B[j-1] : default_close_B;
        }

      //--- 3. Calculate OLS Cointegration on HTF (Closed bars only!)
      //--- Notice the limit is 'g_htf_count - 1' (excluding the live forming bar)
      for(int j = InpLookback; j < g_htf_count - 1; j++)
        {
         // Filter out inactive custom hours on HTF
         if(InpAnchor == ANCHOR_CUSTOM_SESSION)
           {
            if(!IsTimeInSession(h_time[j], g_start_hour, g_start_min, g_end_hour, g_end_min))
              {
               h_res_z[j] = EMPTY_VALUE;
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
            htf_active_window = InpLookback;
         else
            htf_active_window = j - g_htf_anchor_start + 1;

         // Compute Z-Score on HTF and store it
         h_res_z[j] = g_calc.CalculateZScore(g_htf_count, j, htf_active_window, h_close_A, h_close_B);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 3. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpLookback)
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
            htf_active_window = InpLookback;
         else
            htf_active_window = live_idx - g_htf_anchor_start + 1;

         if(InpAnchor != ANCHOR_CUSTOM_SESSION || IsTimeInSession(htf_time_current, g_start_hour, g_start_min, g_end_hour, g_end_min))
           {
            h_res_z[live_idx] = g_calc.CalculateZScore(g_htf_count, live_idx, htf_active_window, h_close_A, h_close_B);
           }
         else
           {
            h_res_z[live_idx] = EMPTY_VALUE;
           }
        }
     }

//--- 4. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // This is the start of the forming step

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 5. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            double z = h_res_z[idx_htf];
            ExtZScoreBuffer[i] = z;

            //--- 5-Zone Thermal Color Mapping on mapped Z-Score
            if(z == EMPTY_VALUE || z == 0.0)
              {
               ExtColorsBuffer[i] = 0.0;
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
         else
           {
            ExtZScoreBuffer[i] = EMPTY_VALUE;
            ExtColorsBuffer[i] = 0.0;
           }
        }
      else
        {
         ExtZScoreBuffer[i] = EMPTY_VALUE;
         ExtColorsBuffer[i] = 0.0;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
