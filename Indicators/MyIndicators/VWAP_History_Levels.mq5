//+------------------------------------------------------------------+
//|                                        VWAP_History_Levels.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00" // Objects Only (No Buffers)
#property description "Draws Historical VWAP Close Levels as Support/Resistance."

#property indicator_chart_window
#property indicator_plots 0 // No buffers shown

#include <MyIncludes\VWAP_Calculator.mqh>

//--- Input Parameters
input group             "Daily Levels"
input bool              InpShowDaily      = true;
input int               InpDailyCount     = 3;        // Keep last N Levels
input color             InpDailyColor     = clrDeepPink;

input group             "Weekly Levels"
input bool              InpShowWeekly     = true;
input int               InpWeeklyCount    = 3;
input color             InpWeeklyColor    = clrDodgerBlue;

input group             "Monthly Levels"
input bool              InpShowMonthly    = true;
input int               InpMonthlyCount   = 2;
input color             InpMonthlyColor   = clrMediumTurquoise;

//--- Internal Calculators & Buffers (Hidden)
CVWAPCalculator *g_vwap_d;
CVWAPCalculator *g_vwap_w;
CVWAPCalculator *g_vwap_m;

double calc_daily[], calc_weekly[], calc_monthly[];

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
// Init Calculators
   g_vwap_d = new CVWAPCalculator();
   g_vwap_d.Init(PERIOD_SESSION, VOLUME_TICK, 0, InpShowDaily);

   g_vwap_w = new CVWAPCalculator();
   g_vwap_w.Init(PERIOD_WEEK, VOLUME_TICK, 0, InpShowWeekly);

   g_vwap_m = new CVWAPCalculator();
   g_vwap_m.Init(PERIOD_MONTH, VOLUME_TICK, 0, InpShowMonthly);

   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP Hist Levels");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   ObjectsDeleteAll(0, "VLevel_");
   delete g_vwap_d;
   delete g_vwap_w;
   delete g_vwap_m;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
   if(rates_total < 2)
      return 0;

// Resize internal buffers
   if(ArraySize(calc_daily) != rates_total)
     {
      ArrayResize(calc_daily, rates_total);
      ArrayResize(calc_weekly, rates_total);
      ArrayResize(calc_monthly, rates_total);
     }

// 1. Calculate VWAP History in background
   double odd[], even[];

   if(InpShowDaily)
     {
      g_vwap_d.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeBuffers(rates_total, odd, even, calc_daily);
     }

   if(InpShowWeekly)
     {
      g_vwap_w.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeBuffers(rates_total, odd, even, calc_weekly);
     }

   if(InpShowMonthly)
     {
      g_vwap_m.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeBuffers(rates_total, odd, even, calc_monthly);
     }

// 2. Manage Objects (Detect Period End)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 1;

   for(int i = start; i < rates_total; i++)
     {
      MqlDateTime dt, dt_prev;
      TimeToStruct(time[i], dt);
      TimeToStruct(time[i-1], dt_prev);

      // Look for transition at i
      // Valid Level is at i-1 (the close of previous session)

      // Daily
      if(InpShowDaily && dt.day_of_year != dt_prev.day_of_year)
        {
         CreateLevelObject(time[i-1], calc_daily[i-1], "D", InpDailyColor, InpDailyCount);
        }

      // Weekly (Monday check or week change)
      // Robust way: int week = (int)(time[i] / 604800);
      datetime t_week_start = iTime(_Symbol, PERIOD_W1, iBarShift(_Symbol, PERIOD_W1, time[i]));
      datetime t_prev_week_start = iTime(_Symbol, PERIOD_W1, iBarShift(_Symbol, PERIOD_W1, time[i-1]));

      if(InpShowWeekly && t_week_start != t_prev_week_start)
        {
         CreateLevelObject(time[i-1], calc_weekly[i-1], "W", InpWeeklyColor, InpWeeklyCount);
        }

      // Monthly
      if(InpShowMonthly && dt.mon != dt_prev.mon)
        {
         CreateLevelObject(time[i-1], calc_monthly[i-1], "M", InpMonthlyColor, InpMonthlyCount);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void MergeBuffers(int total, const double &src1[], const double &src2[], double &dst[])
  {
   for(int i=0; i<total; i++)
     {
      if(src1[i] != EMPTY_VALUE && src1[i] != 0)
         dst[i] = src1[i];
      else
         dst[i] = src2[i];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLevelObject(datetime time_start, double price, string suffix, color clr, int limit_count)
  {
   if(price == 0 || price == EMPTY_VALUE)
      return;

// Name includes specific Date to be unique
   string name_prefix = "VLevel_" + suffix + "_";
   string name = name_prefix + TimeToString(time_start, TIME_DATE); // Unique per day/week

   if(ObjectFind(0, name) >= 0)
      return; // Already exists

// Cleanup before creating new
   CleanOldObjects(name_prefix, limit_count);

   ObjectCreate(0, name, OBJ_TREND, 0, time_start, price, TimeCurrent()+PeriodSeconds()*100, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

// Label
   string text_name = name + "_txt";
   ObjectCreate(0, text_name, OBJ_TEXT, 0, time_start, price);
   ObjectSetString(0, text_name, OBJPROP_TEXT, "  " + suffix + " " + DoubleToString(price, _Digits));
   ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, text_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CleanOldObjects(string prefix, int max_count)
  {
   string objects[];
   int count = 0;
   int total = ObjectsTotal(0);

// Collect
   for(int i=0; i<total; i++)
     {
      string n = ObjectName(0, i);
      if(StringFind(n, prefix) == 0 && StringFind(n, "_txt") == -1)
        {
         ArrayResize(objects, count+1);
         objects[count] = n;
         count++;
        }
     }

// Delete Oldest
   if(count >= max_count)
     {
      ArraySort(objects); // String sort works for YYYY.MM.DD
      int to_delete = count - max_count + 1;
      for(int i=0; i<to_delete; i++)
        {
         ObjectDelete(0, objects[i]);
         ObjectDelete(0, objects[i] + "_txt");
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
