//+------------------------------------------------------------------+
//|                                        VWAP_History_Levels.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Modernized: Full Workspace Ray Engine, Custom Session Support & Clean GC
#property description "Projects Historical Closing VWAP Levels (Daily, Weekly, Monthly, Custom) as S/R Rays."

#property indicator_chart_window
#property indicator_plots 0

//--- Included Engines
#include <MyIncludes\VWAP_Calculator.mqh>

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
input group "--- Calculation & Source Settings ---"
input ENUM_APPLIED_VOLUME InpVolumeType      = VOLUME_TICK;       // Volume Type
input ENUM_CANDLE_SOURCE  InpCandleSource     = CANDLE_STANDARD;   // Candle Source
input int                 InpTzShift          = 0;                 // Timezone Shift in hours vs Broker Time

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Daily Historical Levels (PD-VWAP) ---"
input bool                InpShowDaily        = true;              // Show Prior Daily VWAP Levels?
input int                 InpDailyCount       = 3;                 // Number of Daily Levels to Keep
input color               InpDailyColor       = clrDeepPink;       // Daily Level Color
input ENUM_LINE_STYLE     InpDailyStyle       = STYLE_SOLID;       // Daily Level Style
input int                 InpDailyWidth       = 1;                 // Daily Level Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Weekly Historical Levels (PW-VWAP) ---"
input bool                InpShowWeekly       = true;              // Show Prior Weekly VWAP Levels?
input int                 InpWeeklyCount      = 3;                 // Number of Weekly Levels to Keep
input color               InpWeeklyColor      = clrDodgerBlue;     // Weekly Level Color
input ENUM_LINE_STYLE     InpWeeklyStyle      = STYLE_SOLID;       // Weekly Level Style
input int                 InpWeeklyWidth      = 1;                 // Weekly Level Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Monthly Historical Levels (PM-VWAP) ---"
input bool                InpShowMonthly      = true;              // Show Prior Monthly VWAP Levels?
input int                 InpMonthlyCount     = 2;                 // Number of Monthly Levels to Keep
input color               InpMonthlyColor     = clrMediumTurquoise;// Monthly Level Color
input ENUM_LINE_STYLE     InpMonthlyStyle     = STYLE_SOLID;       // Monthly Level Style
input int                 InpMonthlyWidth     = 1;                 // Monthly Level Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Custom Session Levels (e.g., Prior London Session) ---"
input bool                InpShowCustom       = false;             // Show Prior Custom Session VWAP?
input string              InpCustomStart      = "08:00";           // Custom Session Start (HH:MM)
input string              InpCustomEnd        = "16:30";           // Custom Session End (HH:MM)
input int                 InpCustomCount      = 2;                 // Number of Custom Levels to Keep
input color               InpCustomColor      = clrGold;           // Custom Level Color
input ENUM_LINE_STYLE     InpCustomStyle      = STYLE_SOLID;       // Custom Level Style
input int                 InpCustomWidth      = 1;                 // Custom Level Width

input group "--- Visual & Label Settings ---"
input bool                InpShowLabels       = true;              // Show Text Labels on Chart?
input int                 InpLabelShift       = 8;                 // Label Shift (Bars Into Workspace)
input int                 InpFontSize         = 8;                 // Font Size

//--- Internal State Buffers
double calc_daily[];
double calc_weekly[];
double calc_monthly[];
double calc_custom[];

//--- Calculator Objects
CVWAPCalculator *g_vwap_d = NULL;
CVWAPCalculator *g_vwap_w = NULL;
CVWAPCalculator *g_vwap_m = NULL;
CVWAPCalculator *g_vwap_c = NULL;

const string g_prefix_line = "VLevel_";
const string g_prefix_lbl  = "VLevelLbl_";

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Initialize Daily Calculator
   if(InpShowDaily)
     {
      g_vwap_d = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? new CVWAPCalculator_HA() : new CVWAPCalculator();
      if(CheckPointer(g_vwap_d) == POINTER_INVALID || !g_vwap_d.Init(PERIOD_SESSION, InpVolumeType, InpTzShift, true, InpDailyCount * 5))
         return INIT_FAILED;
     }

// 2. Initialize Weekly Calculator
   if(InpShowWeekly)
     {
      g_vwap_w = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? new CVWAPCalculator_HA() : new CVWAPCalculator();
      if(CheckPointer(g_vwap_w) == POINTER_INVALID || !g_vwap_w.Init(PERIOD_WEEK, InpVolumeType, 0, true, InpWeeklyCount * 14))
         return INIT_FAILED;
     }

// 3. Initialize Monthly Calculator
   if(InpShowMonthly)
     {
      g_vwap_m = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? new CVWAPCalculator_HA() : new CVWAPCalculator();
      if(CheckPointer(g_vwap_m) == POINTER_INVALID || !g_vwap_m.Init(PERIOD_MONTH, InpVolumeType, 0, true, InpMonthlyCount * 60))
         return INIT_FAILED;
     }

// 4. Initialize Custom Session Calculator
   if(InpShowCustom)
     {
      g_vwap_c = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? new CVWAPCalculator_HA() : new CVWAPCalculator();
      if(CheckPointer(g_vwap_c) == POINTER_INVALID || !g_vwap_c.Init(InpCustomStart, InpCustomEnd, InpVolumeType, true, InpCustomCount * 5, InpTzShift))
         return INIT_FAILED;
     }

   string ha_tag = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VWAP Hist Levels%s", ha_tag));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_vwap_d) != POINTER_INVALID)
     {
      delete g_vwap_d;
      g_vwap_d = NULL;
     }
   if(CheckPointer(g_vwap_w) != POINTER_INVALID)
     {
      delete g_vwap_w;
      g_vwap_w = NULL;
     }
   if(CheckPointer(g_vwap_m) != POINTER_INVALID)
     {
      delete g_vwap_m;
      g_vwap_m = NULL;
     }
   if(CheckPointer(g_vwap_c) != POINTER_INVALID)
     {
      delete g_vwap_c;
      g_vwap_c = NULL;
     }

   ObjectsDeleteAll(0, g_prefix_line);
   ObjectsDeleteAll(0, g_prefix_lbl);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Helper: Merge Odd/Even buffers into a single linear cache        |
//+------------------------------------------------------------------+
void MergeOddEvenBuffers(const int total, const double &odd[], const double &even[], double &dst[])
  {
   if(ArraySize(dst) != total)
     {
      ArrayResize(dst, total);
      ArraySetAsSeries(dst, false);
     }

   for(int i = 0; i < total; i++)
     {
      if(odd[i] != EMPTY_VALUE && odd[i] > 0.0)
         dst[i] = odd[i];
      else
         if(even[i] != EMPTY_VALUE && even[i] > 0.0)
            dst[i] = even[i];
         else
            dst[i] = EMPTY_VALUE;
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
   if(rates_total < 2)
      return 0;

// Chronological Safety
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

   double odd[], even[];

// 1. Calculate History Buffers
   if(InpShowDaily && CheckPointer(g_vwap_d) != POINTER_INVALID)
     {
      g_vwap_d.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeOddEvenBuffers(rates_total, odd, even, calc_daily);
     }

   if(InpShowWeekly && CheckPointer(g_vwap_w) != POINTER_INVALID)
     {
      g_vwap_w.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeOddEvenBuffers(rates_total, odd, even, calc_weekly);
     }

   if(InpShowMonthly && CheckPointer(g_vwap_m) != POINTER_INVALID)
     {
      g_vwap_m.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeOddEvenBuffers(rates_total, odd, even, calc_monthly);
     }

   if(InpShowCustom && CheckPointer(g_vwap_c) != POINTER_INVALID)
     {
      g_vwap_c.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, odd, even);
      MergeOddEvenBuffers(rates_total, odd, even, calc_custom);
     }

// 2. Scan Period Transitions & Project S/R Ray Levels
   int scan_start = (prev_calculated == 0) ? 1 : (prev_calculated - 1);
   if(scan_start < 1)
      scan_start = 1;

   for(int i = scan_start; i < rates_total; i++)
     {
      // --- Daily Transitions (PD-VWAP) ---
      if(InpShowDaily)
        {
         datetime curr_t = time[i]     + (datetime)(InpTzShift * 3600);
         datetime prev_t = time[i - 1] + (datetime)(InpTzShift * 3600);
         MqlDateTime dt_c, dt_p;
         TimeToStruct(curr_t, dt_c);
         TimeToStruct(prev_t, dt_p);

         if(dt_c.day_of_year != dt_p.day_of_year || dt_c.year != dt_p.year)
           {
            CaptureHistoricLevel(time[i - 1], calc_daily[i - 1], "PD-VWAP", InpDailyColor, InpDailyStyle, InpDailyWidth, InpDailyCount);
           }
        }

      // --- Weekly Transitions (PW-VWAP) ---
      if(InpShowWeekly)
        {
         MqlDateTime dt_c, dt_p;
         TimeToStruct(time[i], dt_c);
         TimeToStruct(time[i - 1], dt_p);

         if(dt_c.day_of_week < dt_p.day_of_week)
           {
            CaptureHistoricLevel(time[i - 1], calc_weekly[i - 1], "PW-VWAP", InpWeeklyColor, InpWeeklyStyle, InpWeeklyWidth, InpWeeklyCount);
           }
        }

      // --- Monthly Transitions (PM-VWAP) ---
      if(InpShowMonthly)
        {
         MqlDateTime dt_c, dt_p;
         TimeToStruct(time[i], dt_c);
         TimeToStruct(time[i - 1], dt_p);

         if(dt_c.mon != dt_p.mon || dt_c.year != dt_p.year)
           {
            CaptureHistoricLevel(time[i - 1], calc_monthly[i - 1], "PM-VWAP", InpMonthlyColor, InpMonthlyStyle, InpMonthlyWidth, InpMonthlyCount);
           }
        }

      // --- Custom Session Transitions (PS-VWAP) ---
      if(InpShowCustom && CheckPointer(g_vwap_c) != POINTER_INVALID)
        {
         bool is_inside_now  = g_vwap_c.IsTimeInSession(time[i]);
         bool is_inside_prev = g_vwap_c.IsTimeInSession(time[i - 1]);

         // Session just closed
         if(!is_inside_now && is_inside_prev)
           {
            CaptureHistoricLevel(time[i - 1], calc_custom[i - 1], "PS-VWAP", InpCustomColor, InpCustomStyle, InpCustomWidth, InpCustomCount);
           }
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Capture and Project Historic VWAP Level Ray                      |
//+------------------------------------------------------------------+
void CaptureHistoricLevel(const datetime time_close,
                          const double price,
                          const string tag,
                          const color clr,
                          const ENUM_LINE_STYLE style,
                          const int width,
                          const int limit_count)
  {
   if(price <= 0.0 || price == EMPTY_VALUE)
      return;

   string name_prefix = g_prefix_line + tag + "_";
   string obj_name    = name_prefix + TimeToString(time_close, TIME_DATE | TIME_MINUTES);

   if(ObjectFind(0, obj_name) >= 0)
      return; // Already registered

// Clean older rays before creating new one
   CleanOldObjects(name_prefix, limit_count);

   datetime t_end = time_close + PeriodSeconds() * 100;

// 1. Create Full-Workspace Extended Ray Line
   ObjectCreate(0, obj_name, OBJ_TREND, 0, time_close, price, t_end, price);
   ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, obj_name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);

// 2. Create Text Label in Chart Shift Workspace
   if(InpShowLabels)
     {
      string lbl_name = g_prefix_lbl + tag + "_" + TimeToString(time_close, TIME_DATE | TIME_MINUTES);
      ObjectCreate(0, lbl_name, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, lbl_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, lbl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl_name, OBJPROP_HIDDEN, true);

      datetime lbl_time = iTime(_Symbol, Period(), 0) + PeriodSeconds(Period()) * InpLabelShift;
      string label_text = StringFormat("  %s (%s)", tag, DoubleToString(price, _Digits));

      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label_text);
      ObjectSetDouble(0, lbl_name, OBJPROP_PRICE, price);
      ObjectSetInteger(0, lbl_name, OBJPROP_TIME, lbl_time);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, InpFontSize);
     }
  }

//+------------------------------------------------------------------+
//| High-Performance Garbage Collector (Pre-allocated Array GC)       |
//+------------------------------------------------------------------+
void CleanOldObjects(const string prefix, const int max_count)
  {
   int total_objs = ObjectsTotal(0);
   if(total_objs < 1)
      return;

   string objects[];
   ArrayResize(objects, total_objs);

   int count = 0;
   for(int i = 0; i < total_objs; i++)
     {
      string n = ObjectName(0, i);
      if(StringFind(n, prefix) == 0 && StringFind(n, g_prefix_lbl) == -1)
        {
         objects[count] = n;
         count++;
        }
     }

   if(count >= max_count)
     {
      ArrayResize(objects, count);
      ArraySort(objects); // Lexicographical sort by Date/Time string

      int to_delete = count - max_count + 1;
      for(int i = 0; i < to_delete; i++)
        {
         string line_name = objects[i];
         string lbl_name  = line_name;
         StringReplace(lbl_name, g_prefix_line, g_prefix_lbl);

         ObjectDelete(0, line_name);
         ObjectDelete(0, lbl_name);
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
