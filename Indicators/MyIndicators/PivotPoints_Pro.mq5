//+------------------------------------------------------------------+
//|                                              PivotPoints_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.30" // Streamlined: Permanent Extended Workspace Support
#property description "Professional Pivot Points with Native Workspace & Chart Shift Support."

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

//--- Global Objects & Constants
CPivotPointCalculator *g_calculator = NULL;
const string           g_prefix_line = "PivotLine_";
const string           g_prefix_lbl  = "PivotLabel_";

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
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

// Chronological Safety (0 = Oldest bar)
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

   ArrayInitialize(BufferPP, EMPTY_VALUE);
   ArrayInitialize(BufferR1, EMPTY_VALUE);
   ArrayInitialize(BufferS1, EMPTY_VALUE);
   ArrayInitialize(BufferR2, EMPTY_VALUE);
   ArrayInitialize(BufferS2, EMPTY_VALUE);
   ArrayInitialize(BufferR3, EMPTY_VALUE);
   ArrayInitialize(BufferS3, EMPTY_VALUE);
   ArrayInitialize(BufferM1, EMPTY_VALUE);
   ArrayInitialize(BufferM2, EMPTY_VALUE);
   ArrayInitialize(BufferM3, EMPTY_VALUE);
   ArrayInitialize(BufferM4, EMPTY_VALUE);
   ArrayInitialize(BufferM5, EMPTY_VALUE);
   ArrayInitialize(BufferM6, EMPTY_VALUE);

// Configure all plots to DRAW_NONE to delegate rendering to the ray object engine
   for(int i = 0; i < 13; i++)
     {
      PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   if(InpTimeframe < Period())
     {
      Print("Error: Pivot Timeframe must be >= Current Chart Timeframe.");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_calculator = new CPivotPointCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPivotType, InpSourceType))
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
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }

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

// 1. Maintain Buffers for Data Window & iCustom compatibility
   int limit = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   for(int i = limit; i < rates_total; i++)
     {
      if(time[i] >= levels.period_start)
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
            BufferM1[i] = (levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE) ? (levels.S1 + levels.S2) / 2.0 : EMPTY_VALUE;
            BufferM2[i] = (levels.S1 != EMPTY_VALUE) ? (levels.S1 + levels.PP) / 2.0 : EMPTY_VALUE;
            BufferM3[i] = (levels.R1 != EMPTY_VALUE) ? (levels.PP + levels.R1) / 2.0 : EMPTY_VALUE;
            BufferM4[i] = (levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE) ? (levels.R1 + levels.R2) / 2.0 : EMPTY_VALUE;
            BufferM5[i] = (levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE) ? (levels.R2 + levels.R3) / 2.0 : EMPTY_VALUE;
            BufferM6[i] = (levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE) ? (levels.S2 + levels.S3) / 2.0 : EMPTY_VALUE;
           }
        }
      else
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
     }

// 2. Render Full-Workspace Extended Levels across the Chart Shift zone
   UpdateExtendedLevels(levels);

// 3. Update Text Labels
   if(InpShowLabels)
      UpdateLabels(levels);
   else
      ObjectsDeleteAll(0, g_prefix_lbl);

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Render Extended Lines across Entire Workspace                    |
//+------------------------------------------------------------------+
void UpdateExtendedLevels(const PivotLevels &levels)
  {
   datetime t_start = levels.period_start;
   datetime t_end   = t_start + PeriodSeconds(InpTimeframe);

// Main Levels
   SetLevelRay("PP", levels.PP, t_start, t_end, InpColorPP, InpStylePP, InpWidthPP);
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
         SetLevelRay("M_S1_S2", (levels.S1 + levels.S2) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.S1 != EMPTY_VALUE)
         SetLevelRay("M_PP_S1", (levels.S1 + levels.PP) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R1 != EMPTY_VALUE)
         SetLevelRay("M_PP_R1", (levels.PP + levels.R1) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE)
         SetLevelRay("M_R1_R2", (levels.R1 + levels.R2) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE)
         SetLevelRay("M_R2_R3", (levels.R2 + levels.R3) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
      if(levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE)
         SetLevelRay("M_S2_S3", (levels.S2 + levels.S3) / 2.0, t_start, t_end, InpColorMed, InpStyleMed, InpWidthMed);
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
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
     }

   ObjectSetInteger(0, objName, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, objName, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
  }

//+------------------------------------------------------------------+
//| Update Labels in Workspace                                       |
//+------------------------------------------------------------------+
void UpdateLabels(const PivotLevels &levels)
  {
   CreateLabel("PP", levels.PP, InpColorPP);
   CreateLabel("R1", levels.R1, InpColorRes);
   CreateLabel("R2", levels.R2, InpColorRes);
   CreateLabel("R3", levels.R3, InpColorRes);
   CreateLabel("S1", levels.S1, InpColorSup);
   CreateLabel("S2", levels.S2, InpColorSup);
   CreateLabel("S3", levels.S3, InpColorSup);

   if(InpShowMedians && levels.PP != EMPTY_VALUE)
     {
      if(levels.S1 != EMPTY_VALUE && levels.S2 != EMPTY_VALUE)
         CreateLabel("S1-S2", (levels.S1 + levels.S2) / 2.0, InpColorMed, true);
      if(levels.S1 != EMPTY_VALUE)
         CreateLabel("PP-S1", (levels.S1 + levels.PP) / 2.0, InpColorMed, true);
      if(levels.R1 != EMPTY_VALUE)
         CreateLabel("PP-R1", (levels.PP + levels.R1) / 2.0, InpColorMed, true);
      if(levels.R1 != EMPTY_VALUE && levels.R2 != EMPTY_VALUE)
         CreateLabel("R1-R2", (levels.R1 + levels.R2) / 2.0, InpColorMed, true);
      if(levels.R2 != EMPTY_VALUE && levels.R3 != EMPTY_VALUE)
         CreateLabel("R2-R3", (levels.R2 + levels.R3) / 2.0, InpColorMed, true);
      if(levels.S2 != EMPTY_VALUE && levels.S3 != EMPTY_VALUE)
         CreateLabel("S2-S3", (levels.S2 + levels.S3) / 2.0, InpColorMed, true);
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
void CreateLabel(const string name, const double price, const color col, const bool small = false)
  {
   string objName = g_prefix_lbl + name;

   if(price == EMPTY_VALUE || price <= 0.0)
     {
      ObjectDelete(0, objName);
      return;
     }

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
     }

// Anchor label into the workspace shift area
   datetime target_time = iTime(_Symbol, Period(), 0) + PeriodSeconds(Period()) * InpLabelShift;

   ObjectSetString(0, objName, OBJPROP_TEXT, "  " + name);
   ObjectSetDouble(0, objName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, objName, OBJPROP_TIME, target_time);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, small ? MathMax(6, InpFontSize - 2) : InpFontSize);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
