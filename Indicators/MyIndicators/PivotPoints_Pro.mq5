//+------------------------------------------------------------------+
//|                                              PivotPoints_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.40" // Enterprise Refactor: Dual State-Guards (Zero GDI overhead on live ticks)
#property description "Professional Pivot Points with Native Workspace & Chart Shift Support."
#property description "Optimized for massive multi-window execution with zero tick latency."

#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   13

//--- Plot definitions (Data Window Registration)
#property indicator_label1  "Pivot Point"
#property indicator_type1   DRAW_NONE
#property indicator_label2  "R1"
#property indicator_type2   DRAW_NONE
#property indicator_label3  "S1"
#property indicator_type3   DRAW_NONE
#property indicator_label4  "R2"
#property indicator_type4   DRAW_NONE
#property indicator_label5  "S2"
#property indicator_type5   DRAW_NONE
#property indicator_label6  "R3"
#property indicator_type6   DRAW_NONE
#property indicator_label7  "S3"
#property indicator_type7   DRAW_NONE
#property indicator_label8  "S1-S2"
#property indicator_type8   DRAW_NONE
#property indicator_label9  "PP-S1"
#property indicator_type9   DRAW_NONE
#property indicator_label10 "PP-R1"
#property indicator_type10  DRAW_NONE
#property indicator_label11 "R1-R2"
#property indicator_type11  DRAW_NONE
#property indicator_label12 "R2-R3"
#property indicator_type12  DRAW_NONE
#property indicator_label13 "S2-S3"
#property indicator_type13  DRAW_NONE

#include <MyIncludes\PivotPoint_Calculator.mqh>

//--- Inputs
input group             "Timeframe Settings"
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_D1;          // Pivot Timeframe

input group             "Calculation Settings"
input ENUM_PIVOT_TYPE   InpPivotType      = PIVOT_CLASSIC;      // Pivot Formula
input ENUM_PIVOT_SOURCE InpSourceType     = PIVOT_SRC_STANDARD; // Price Source (Std/HA)

input group             "Visual Settings - Pivot Point"
input color             InpColorPP        = clrGold;            // PP Color
input ENUM_LINE_STYLE   InpStylePP        = STYLE_SOLID;        // PP Style
input int               InpWidthPP        = 2;                  // PP Width

input group             "Visual Settings - Resistance"
input color             InpColorRes       = clrDodgerBlue;      // Resistance Color
input ENUM_LINE_STYLE   InpStyleRes       = STYLE_SOLID;        // Resistance Style
input int               InpWidthRes       = 1;                  // Resistance Width

input group             "Visual Settings - Support"
input color             InpColorSup       = clrFireBrick;       // Support Color
input ENUM_LINE_STYLE   InpStyleSup       = STYLE_SOLID;        // Support Style
input int               InpWidthSup       = 1;                  // Support Width

input group             "Visual Settings - Medians"
input bool              InpShowMedians    = true;               // Show Median Levels
input color             InpColorMed       = clrSilver;          // Median Color
input ENUM_LINE_STYLE   InpStyleMed       = STYLE_DOT;          // Median Style
input int               InpWidthMed       = 1;                  // Median Width

input group             "Labels"
input bool              InpShowLabels     = true;               // Show Labels
input int               InpLabelShift     = 8;                  // Label Shift (Bars Into Workspace)
input int               InpFontSize       = 8;                  // Font Size

//--- Buffers
double BufferPP[];
double BufferR1[], BufferS1[];
double BufferR2[], BufferS2[];
double BufferR3[], BufferS3[];
double BufferM1[], BufferM2[], BufferM3[], BufferM4[], BufferM5[], BufferM6[];

//--- Static Global Engine Instance (Zero heap allocation)
CPivotPointCalculator g_calculator;

//--- State Guards for Zero-Lag Execution
datetime g_last_rendered_period = 0;
datetime g_last_bar_time        = 0;

string   g_prefix_line          = "";
string   g_prefix_lbl           = "";

// Forward declarations
void UpdateExtendedLevels(const PivotLevels &levels);
void UpdateLabels(const PivotLevels &levels, const datetime current_time);
void SetLevelRay(const string name, const double price, const datetime t1, const datetime t2, const color col, const ENUM_LINE_STYLE style, const int width);
void CreateLabel(const string name, const double price, const color col, const datetime target_time, const bool small=false);

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_rendered_period = 0;
   g_last_bar_time        = 0;

   g_prefix_line = StringFormat("PivLine_%I64d_", ChartID());
   g_prefix_lbl  = StringFormat("PivLbl_%I64d_",  ChartID());

   SetIndexBuffer(0, BufferPP, INDICATOR_DATA);
   SetIndexBuffer(1, BufferR1, INDICATOR_DATA);
   SetIndexBuffer(2, BufferS1, INDICATOR_DATA);
   SetIndexBuffer(3, BufferR2, INDICATOR_DATA);
   SetIndexBuffer(4, BufferS2, INDICATOR_DATA);
   SetIndexBuffer(5, BufferR3, INDICATOR_DATA);
   SetIndexBuffer(6, BufferS3, INDICATOR_DATA);

   SetIndexBuffer(7, BufferM1, INDICATOR_DATA);
   SetIndexBuffer(8, BufferM2, INDICATOR_DATA);
   SetIndexBuffer(9, BufferM3, INDICATOR_DATA);
   SetIndexBuffer(10, BufferM4, INDICATOR_DATA);
   SetIndexBuffer(11, BufferM5, INDICATOR_DATA);
   SetIndexBuffer(12, BufferM6, INDICATOR_DATA);

// Chronological Safety
   ArraySetAsSeries(BufferPP, false);
   ArraySetAsSeries(BufferR1, false);
   ArraySetAsSeries(BufferS1, false);
   ArraySetAsSeries(BufferR2, false);
   ArraySetAsSeries(BufferS2, false);
   ArraySetAsSeries(BufferR3, false);
   ArraySetAsSeries(BufferS3, false);
   ArraySetAsSeries(BufferM1, false);
   ArraySetAsSeries(BufferM2, false);
   ArraySetAsSeries(BufferM3, false);
   ArraySetAsSeries(BufferM4, false);
   ArraySetAsSeries(BufferM5, false);
   ArraySetAsSeries(BufferM6, false);

   for(int i = 0; i < 13; i++)
     {
      PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }

   if(InpTimeframe < Period())
     {
      Print("Error: Pivot Timeframe must be >= Current Chart Timeframe.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!g_calculator.Init(InpPivotType, InpSourceType))
      return INIT_FAILED;

   string label = StringFormat("PivotPro(%s)", EnumToString(InpTimeframe));
   IndicatorSetString(INDICATOR_SHORTNAME, label);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, g_prefix_line);
   ObjectsDeleteAll(0, g_prefix_lbl);
   ChartRedraw(0);
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
   if(rates_total < 2)
      return 0;

   ArraySetAsSeries(time, false);
   datetime current_time = time[rates_total - 1];

   PivotLevels levels;
   if(!g_calculator.CalculateLevels(current_time, InpTimeframe, levels))
      return 0;

// 1. Maintain Buffers for Data Window & iCustom compatibility (O(1) on live ticks!)
   if(prev_calculated == 0)
     {
      // Efficient initial pass: Find start of active period in O(log N)
      int period_start_bar = ArrayBsearch(time, levels.period_start);
      if(period_start_bar < 0)
         period_start_bar = 0;

      for(int i = 0; i < period_start_bar; i++)
        {
         BufferPP[i] = EMPTY_VALUE;
         BufferR1[i] = EMPTY_VALUE;
         BufferS1[i] = EMPTY_VALUE;
         BufferR2[i] = EMPTY_VALUE;
         BufferS2[i] = EMPTY_VALUE;
         BufferR3[i] = EMPTY_VALUE;
         BufferS3[i] = EMPTY_VALUE;
         BufferM1[i] = EMPTY_VALUE;
         BufferM2[i] = EMPTY_VALUE;
         BufferM3[i] = EMPTY_VALUE;
         BufferM4[i] = EMPTY_VALUE;
         BufferM5[i] = EMPTY_VALUE;
         BufferM6[i] = EMPTY_VALUE;
        }

      for(int i = period_start_bar; i < rates_total; i++)
        {
         BufferPP[i] = levels.PP;
         BufferR1[i] = levels.R1;
         BufferS1[i] = levels.S1;
         BufferR2[i] = levels.R2;
         BufferS2[i] = levels.S2;
         BufferR3[i] = levels.R3;
         BufferS3[i] = levels.S3;

         if(InpShowMedians && levels.PP != EMPTY_VALUE)
           {
            BufferM1[i] = (levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE) ? (levels.S1 + levels.S2) * 0.5 : EMPTY_VALUE;
            BufferM2[i] = (levels.S1 != EMPTY_VALUE) ? (levels.S1 + levels.PP) * 0.5 : EMPTY_VALUE;
            BufferM3[i] = (levels.R1 != EMPTY_VALUE) ? (levels.PP + levels.R1) * 0.5 : EMPTY_VALUE;
            BufferM4[i] = (levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE) ? (levels.R1 + levels.R2) * 0.5 : EMPTY_VALUE;
            BufferM5[i] = (levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE) ? (levels.R2 + levels.R3) * 0.5 : EMPTY_VALUE;
            BufferM6[i] = (levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE) ? (levels.S2 + levels.S3) * 0.5 : EMPTY_VALUE;
           }
        }
     }
   else
     {
      // Single live forming bar assignment (Zero loops!)
      int i = rates_total - 1;
      BufferPP[i] = levels.PP;
      BufferR1[i] = levels.R1;
      BufferS1[i] = levels.S1;
      BufferR2[i] = levels.R2;
      BufferS2[i] = levels.S2;
      BufferR3[i] = levels.R3;
      BufferS3[i] = levels.S3;

      if(InpShowMedians && levels.PP != EMPTY_VALUE)
        {
         BufferM1[i] = (levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE) ? (levels.S1 + levels.S2) * 0.5 : EMPTY_VALUE;
         BufferM2[i] = (levels.S1 != EMPTY_VALUE) ? (levels.S1 + levels.PP) * 0.5 : EMPTY_VALUE;
         BufferM3[i] = (levels.R1 != EMPTY_VALUE) ? (levels.PP + levels.R1) * 0.5 : EMPTY_VALUE;
         BufferM4[i] = (levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE) ? (levels.R1 + levels.R2) * 0.5 : EMPTY_VALUE;
         BufferM5[i] = (levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE) ? (levels.R2 + levels.R3) * 0.5 : EMPTY_VALUE;
         BufferM6[i] = (levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE) ? (levels.S2 + levels.S3) * 0.5 : EMPTY_VALUE;
        }
     }

// 2. State-Guards: Only execute GDI updates when period or candle actually changes!
   bool period_changed = (levels.period_start != g_last_rendered_period);
   bool bar_changed    = (current_time != g_last_bar_time);

// A) Ray Lines: ONLY updated when a new HTF period begins (Once every 4 hours or day!)
   if(period_changed)
     {
      UpdateExtendedLevels(levels);
      g_last_rendered_period = levels.period_start;
     }

// B) Labels: ONLY updated when a new bar opens or period changes (Once per candle!)
   if(period_changed || bar_changed)
     {
      if(InpShowLabels)
         UpdateLabels(levels, current_time);
      else
         ObjectsDeleteAll(0, g_prefix_lbl);

      g_last_bar_time = current_time;
     }

// On live ticks: ZERO GDI operations executed!
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Render Extended Lines across Entire Workspace                    |
//+------------------------------------------------------------------+
void UpdateExtendedLevels(const PivotLevels &levels)
  {
   datetime t_start = levels.period_start;
   datetime t_end   = t_start + (datetime)PeriodSeconds(InpTimeframe);

// Main Levels
   SetLevelRay("PP", levels.PP, t_start, t_end, InpColorPP,  InpStylePP,  InpWidthPP);
   SetLevelRay("R1", levels.R1, t_start, t_end, InpColorRes, InpStyleRes, InpWidthRes);
   SetLevelRay("R2", levels.R2, t_start, t_end, InpColorRes, InpStyleRes, InpWidthRes);
   SetLevelRay("R3", levels.R3, t_start, t_end, InpColorRes, InpStyleRes, InpWidthRes);
   SetLevelRay("S1", levels.S1, t_start, t_end, InpColorSup, InpStyleSup, InpWidthSup);
   SetLevelRay("S2", levels.S2, t_start, t_end, InpColorSup, InpStyleSup, InpWidthSup);
   SetLevelRay("S3", levels.S3, t_start, t_end, InpColorSup, InpStyleSup, InpWidthSup);

// Median Levels
   if(InpShowMedians && levels.PP != EMPTY_VALUE)
     {
      if(levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE)
         SetLevelRay("M_S1_S2", (levels.S1 + levels.S2) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.S1 != EMPTY_VALUE)
         SetLevelRay("M_PP_S1", (levels.S1 + levels.PP) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R1 != EMPTY_VALUE)
         SetLevelRay("M_PP_R1", (levels.PP + levels.R1) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE)
         SetLevelRay("M_R1_R2", (levels.R1 + levels.R2) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE)
         SetLevelRay("M_R2_R3", (levels.R2 + levels.R3) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE)
         SetLevelRay("M_S2_S3", (levels.S2 + levels.S3) * 0.5, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
     }
   else
     {
      string med_keys[] = {"M_S1_S2", "M_PP_S1", "M_PP_R1", "M_R1_R2", "M_R2_R3", "M_S2_S3"};
      for(int i = 0; i < 6; i++)
         ObjectDelete(0, g_prefix_line + med_keys[i]);
     }
  }

//+------------------------------------------------------------------+
//| Set or Update a Ray Line Object                                  |
//+------------------------------------------------------------------+
void SetLevelRay(const string name,
                 const double price,
                 const datetime t1,
                 const datetime t2,
                 const color col,
                 const ENUM_LINE_STYLE style,
                 const int width)
  {
   string objName = g_prefix_line + name;

   if(price == EMPTY_VALUE || price <= 0.0)
     {
      ObjectDelete(0, objName);
      return;
     }

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_TREND, 0, t1, price, t2, price);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true); // Stays in background
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
     }
   else
     {
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0,  objName, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0,  objName, OBJPROP_PRICE, 1, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
     }
  }

//+------------------------------------------------------------------+
//| Update Labels in Workspace                                       |
//+------------------------------------------------------------------+
void UpdateLabels(const PivotLevels &levels, const datetime current_time)
  {
   datetime target_time = current_time + (datetime)(PeriodSeconds(Period()) * InpLabelShift);

   CreateLabel("PP", levels.PP, InpColorPP, target_time);
   CreateLabel("R1", levels.R1, InpColorRes, target_time);
   CreateLabel("R2", levels.R2, InpColorRes, target_time);
   CreateLabel("R3", levels.R3, InpColorRes, target_time);
   CreateLabel("S1", levels.S1, InpColorSup, target_time);
   CreateLabel("S2", levels.S2, InpColorSup, target_time);
   CreateLabel("S3", levels.S3, InpColorSup, target_time);

   if(InpShowMedians && levels.PP != EMPTY_VALUE)
     {
      if(levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE)
         CreateLabel("S1-S2", (levels.S1 + levels.S2) * 0.5, InpColorMed, target_time, true);
      if(levels.S1 != EMPTY_VALUE)
         CreateLabel("PP-S1", (levels.S1 + levels.PP) * 0.5, InpColorMed, target_time, true);
      if(levels.R1 != EMPTY_VALUE)
         CreateLabel("PP-R1", (levels.PP + levels.R1) * 0.5, InpColorMed, target_time, true);
      if(levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE)
         CreateLabel("R1-R2", (levels.R1 + levels.R2) * 0.5, InpColorMed, target_time, true);
      if(levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE)
         CreateLabel("R2-R3", (levels.R2 + levels.R3) * 0.5, InpColorMed, target_time, true);
      if(levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE)
         CreateLabel("S2-S3", (levels.S2 + levels.S3) * 0.5, InpColorMed, target_time, true);
     }
   else
     {
      string med_keys[] = {"S1-S2", "PP-S1", "PP-R1", "R1-R2", "R2-R3", "S2-S3"};
      for(int i = 0; i < 6; i++)
         ObjectDelete(0, g_prefix_lbl + med_keys[i]);
     }
  }

//+------------------------------------------------------------------+
//| Helper: Create or Update Text Label                              |
//+------------------------------------------------------------------+
void CreateLabel(const string name, const double price, const color col, const datetime target_time, const bool small=false)
  {
   string objName = g_prefix_lbl + name;

   if(price == EMPTY_VALUE || price <= 0.0)
     {
      ObjectDelete(0, objName);
      return;
     }

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_TEXT, 0, target_time, price);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true); // Stays in background
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetString(0,  objName, OBJPROP_TEXT, "  " + name);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, small ? MathMax(6, InpFontSize - 2) : InpFontSize);
     }
   else
     {
      ObjectSetDouble(0,  objName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, objName, OBJPROP_TIME, target_time);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
