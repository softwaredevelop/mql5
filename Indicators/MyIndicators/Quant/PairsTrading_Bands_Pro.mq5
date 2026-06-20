//+------------------------------------------------------------------+
//|                                       PairsTrading_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.50" // Upgraded to 3 dynamic Z-Score bands (7-channel layout)
#property description "Wyckoff-style Cointegration Bands on Main Chart."
#property description "Projects dynamic equilibrium line (Z=0), warning (Z=+-1.5), extreme (Z=+-2.0) and reversal (Z=+-2.5) bands."
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

//--- Plot 1: Cointegrated Equilibrium Line (Fair Value / Z=0)
#property indicator_label1  "Equilibrium Center"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Upper Outer Band (Z = Extreme / Sell Zone)
#property indicator_label2  "Upper Outer Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Plot 3: Lower Outer Band (Z = Extreme / Buy Zone)
#property indicator_label3  "Lower Outer Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDeepSkyBlue
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

//--- Plot 4: Upper Inner Band (Z = Warning Zone)
#property indicator_label4  "Upper Inner Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCoral
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Plot 5: Lower Inner Band (Z = Warning Zone)
#property indicator_label5  "Lower Inner Band"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLightSkyBlue
#property indicator_style5  STYLE_DOT
#property indicator_width5  1

//--- Plot 6: Upper Extreme Band (Z = Stop/Reversal Zone)
#property indicator_label6  "Upper Extreme Band"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCrimson
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7: Lower Extreme Band (Z = Stop/Reversal Zone)
#property indicator_label7  "Lower Extreme Band"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrDodgerBlue
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

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
input string            InpSecondSymbol       = "USOIL";     // Comparison Symbol (Symbol B)
input ENUM_ANCHOR_PERIOD InpAnchor             = ANCHOR_NONE; // Dynamic Anchored Reset Period
input int               InpLookback           = 120;         // Rolling Window size (Used if Anchor = NONE)
input string            InpCustomStart        = "09:00";     // Custom Session Start (HH:MM, Broker Time)
input string            InpCustomEnd          = "18:00";     // Custom Session End (HH:MM, Broker Time)

//--- Dynamic Channel Options (3 distinct Z-Score levels)
input bool              InpDrawCenterLine     = true;        // Draw Center Equilibrium Line?
input bool              InpDrawInnerBands     = true;        // Draw Inner (Warning) Bands?
input double            InpInnerMultiplier    = 1.5;         // Inner Band Z-Score Multiplier
input bool              InpDrawOuterBands     = true;        // Draw Outer (Extreme) Bands?
input double            InpOuterMultiplier    = 2.0;         // Outer Band Z-Score Multiplier
input bool              InpDrawExtremeBands   = true;        // Draw Extreme (Reversal) Bands?
input double            InpExtremeMultiplier  = 2.5;         // Extreme Band Z-Score Multiplier

//--- Buffers
double BufMiddle[];
double BufUpperOuter[];
double BufLowerOuter[];
double BufUpperInner[];
double BufLowerInner[];
double BufUpperExtreme[];
double BufLowerExtreme[];

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

//--- Verify if the secondary comparison symbol exists in broker offerings
   bool is_custom = false;
   if(!SymbolExist(InpSecondSymbol, is_custom))
     {
      string err_msg = StringFormat("PairsBands Pro Error: Symbol '%s' does not exist in your broker's database!", InpSecondSymbol);
      Alert(err_msg);
      Print(err_msg);
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufMiddle,       INDICATOR_DATA);
   SetIndexBuffer(1, BufUpperOuter,   INDICATOR_DATA);
   SetIndexBuffer(2, BufLowerOuter,   INDICATOR_DATA);
   SetIndexBuffer(3, BufUpperInner,   INDICATOR_DATA);
   SetIndexBuffer(4, BufLowerInner,   INDICATOR_DATA);
   SetIndexBuffer(5, BufUpperExtreme, INDICATOR_DATA);
   SetIndexBuffer(6, BufLowerExtreme, INDICATOR_DATA);

   ArraySetAsSeries(BufMiddle,       false);
   ArraySetAsSeries(BufUpperOuter,   false);
   ArraySetAsSeries(BufLowerOuter,   false);
   ArraySetAsSeries(BufUpperInner,   false);
   ArraySetAsSeries(BufLowerInner,   false);
   ArraySetAsSeries(BufUpperExtreme, false);
   ArraySetAsSeries(BufLowerExtreme, false);

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
   string short_name = StringFormat("PairsBands Pro(%s vs %s, %s)",
                                    _Symbol, InpSecondSymbol,
                                    (InpAnchor == ANCHOR_NONE ? (string)InpLookback : StringSubstr(anchor_name, 7)));

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Instantiate unified calculator
   g_calc = new CPairsTradingCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpLookback))
     {
      Print("Error: Failed to initialize PairsBands Calculator Engine.");
      return INIT_FAILED;
     }

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

//--- Ensure both symbol histories are fully loaded in the terminal
   if(!EnsureDataReady(_Symbol, _Period, required_bars) ||
      !EnsureDataReady(InpSecondSymbol, _Period, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- Retrieve chart-independent default close values for index-0 fallbacks
   double default_close_B = iClose(InpSecondSymbol, _Period, 0);

//--- 1. Advanced Bar-Time Synchronization & Alignment Loop (O(1) incremental)
   ArrayResize(g_sync_close_A, rates_total);
   ArrayResize(g_sync_close_B, rates_total);

   int loop_start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   if(loop_start < 0)
      loop_start = 0;

   for(int i = loop_start; i < rates_total; i++)
     {
      // Symbol A is the native chart symbol -> direct O(1) memory access
      g_sync_close_A[i] = close[i];

      // Sync Symbol B Price
      int shift_B = iBarShift(InpSecondSymbol, _Period, time[i], false);
      if(shift_B >= 0)
         g_sync_close_B[i] = iClose(InpSecondSymbol, _Period, shift_B);
      else
         g_sync_close_B[i] = (i > 0) ? g_sync_close_B[i-1] : default_close_B;
     }

//--- 2. Calculate the rolling OLS Cointegration Bands (O(1) incremental)
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
            BufMiddle[i]       = EMPTY_VALUE;
            BufUpperOuter[i]   = EMPTY_VALUE;
            BufLowerOuter[i]   = EMPTY_VALUE;
            BufUpperInner[i]   = EMPTY_VALUE;
            BufLowerInner[i]   = EMPTY_VALUE;
            BufUpperExtreme[i] = EMPTY_VALUE;
            BufLowerExtreme[i] = EMPTY_VALUE;
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

      //--- D. Execute unified calculator math and fetch dynamic OLS parameters
      //--- By running CalculateZScore, the engine automatically populates beta, alpha, and std_dev internally
      double z = g_calc.CalculateZScore(rates_total, i, active_window_size, g_sync_close_A, g_sync_close_B);

      double beta    = g_calc.GetBeta();
      double alpha   = g_calc.GetAlpha();
      double std_dev = g_calc.GetStdDev();

      if(active_window_size >= 15 && std_dev > 0.0)
        {
         // Center Line (Z=0.0 Equilibrium): A_hat = beta * B_t + alpha
         double fair_price = beta * g_sync_close_B[i] + alpha;

         BufMiddle[i]       = InpDrawCenterLine ? fair_price : EMPTY_VALUE;

         // Outer extreme bands (Default Z = +-2.0)
         BufUpperOuter[i]   = InpDrawOuterBands ? (fair_price + InpOuterMultiplier * std_dev) : EMPTY_VALUE;
         BufLowerOuter[i]   = InpDrawOuterBands ? (fair_price - InpOuterMultiplier * std_dev) : EMPTY_VALUE;

         // Inner warning bands (Default Z = +-1.5)
         BufUpperInner[i]   = InpDrawInnerBands ? (fair_price + InpInnerMultiplier * std_dev) : EMPTY_VALUE;
         BufLowerInner[i]   = InpDrawInnerBands ? (fair_price - InpInnerMultiplier * std_dev) : EMPTY_VALUE;

         // Extreme Outer bands (Default Z = +-2.5)
         BufUpperExtreme[i] = InpDrawExtremeBands ? (fair_price + InpExtremeMultiplier * std_dev) : EMPTY_VALUE;
         BufLowerExtreme[i] = InpDrawExtremeBands ? (fair_price - InpExtremeMultiplier * std_dev) : EMPTY_VALUE;
        }
      else
        {
         BufMiddle[i]       = close[i];
         BufUpperOuter[i]   = close[i];
         BufLowerOuter[i]   = close[i];
         BufUpperInner[i]   = close[i];
         BufLowerInner[i]   = close[i];
         BufUpperExtreme[i] = close[i];
         BufLowerExtreme[i] = close[i];
        }
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
      int required_bars = InpLookback + 5;
      if(EnsureDataReady(InpSecondSymbol, _Period, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
