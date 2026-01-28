//+------------------------------------------------------------------+
//|                                              PivotPoints_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.02" // Fixed: Strict visual masking for current period
#property description "Professional Pivot Points (Current Period Only)."

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   13

//--- Plot definitions
#property indicator_label1  "Pivot Point"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_color1  clrGold

#property indicator_label2  "R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_color2  clrDodgerBlue

#property indicator_label3  "S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_color3  clrFireBrick

#property indicator_label4  "R2"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
#property indicator_color4  clrDodgerBlue

#property indicator_label5  "S2"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1
#property indicator_color5  clrFireBrick

#property indicator_label6  "R3"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1
#property indicator_color6  clrDodgerBlue

#property indicator_label7  "S3"
#property indicator_type7   DRAW_LINE
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1
#property indicator_color7  clrFireBrick

// Median Levels
#property indicator_label8  "S1-S2"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_DOT
#property indicator_width8  1
#property indicator_color8  clrSilver

#property indicator_label9  "PP-S1"
#property indicator_type9   DRAW_LINE
#property indicator_style9  STYLE_DOT
#property indicator_width9  1
#property indicator_color9  clrSilver

#property indicator_label10 "PP-R1"
#property indicator_type10  DRAW_LINE
#property indicator_style10 STYLE_DOT
#property indicator_width10 1
#property indicator_color10 clrSilver

#property indicator_label11 "R1-R2"
#property indicator_type11  DRAW_LINE
#property indicator_style11 STYLE_DOT
#property indicator_width11 1
#property indicator_color11 clrSilver

#property indicator_label12 "R2-R3"
#property indicator_type12  DRAW_LINE
#property indicator_style12 STYLE_DOT
#property indicator_width12 1
#property indicator_color12 clrSilver

#property indicator_label13 "S2-S3"
#property indicator_type13  DRAW_LINE
#property indicator_style13 STYLE_DOT
#property indicator_width13 1
#property indicator_color13 clrSilver

#include <MyIncludes\PivotPoint_Calculator.mqh>

//--- Inputs
input group             "Timeframe Settings"
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_D1;      // Pivot Timeframe

input group             "Calculation Settings"
input ENUM_PIVOT_TYPE   InpPivotType      = PIVOT_CLASSIC;  // Pivot Formula
input ENUM_PIVOT_SOURCE InpSourceType     = PIVOT_SRC_STANDARD; // Price Source (Std/HA)

input group             "Visual Settings - Pivot Point"
input color             InpColorPP        = clrGold;        // PP Color
input ENUM_LINE_STYLE   InpStylePP        = STYLE_SOLID;    // PP Style
input int               InpWidthPP        = 2;              // PP Width

input group             "Visual Settings - Resistance"
input color             InpColorRes       = clrDodgerBlue;  // Resistance Color
input ENUM_LINE_STYLE   InpStyleRes       = STYLE_SOLID;    // Resistance Style
input int               InpWidthRes       = 1;              // Resistance Width

input group             "Visual Settings - Support"
input color             InpColorSup       = clrFireBrick;   // Support Color
input ENUM_LINE_STYLE   InpStyleSup       = STYLE_SOLID;    // Support Style
input int               InpWidthSup       = 1;              // Support Width

input group             "Visual Settings - Medians"
input bool              InpShowMedians    = true;           // Show Median Levels
input color             InpColorMed       = clrSilver;      // Median Color
input ENUM_LINE_STYLE   InpStyleMed       = STYLE_DOT;      // Median Style
input int               InpWidthMed       = 1;              // Median Width

input group             "Labels"
input bool              InpShowLabels     = true;           // Show Labels
input int               InpLabelShift     = 10;             // Label Shift (Bars)
input int               InpFontSize       = 8;              // Font Size

//--- Buffers
double BufferPP[];
double BufferR1[], BufferS1[];
double BufferR2[], BufferS2[];
double BufferR3[], BufferS3[];
double BufferM1[], BufferM2[], BufferM3[], BufferM4[], BufferM5[], BufferM6[];

//--- Global Objects
CPivotPointCalculator *g_calculator;

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

// Important: Initialize with EMPTY_VALUE to avoid connecting zero lines
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

// Set as Non-Series (Normal Chronological Order: 0 is Oldest)
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

// Styling Logic
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorPP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStylePP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPP);

   int res_indices[] = {1, 3, 5};
   for(int i=0; i<ArraySize(res_indices); i++)
     {
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_COLOR, InpColorRes);
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_STYLE, InpStyleRes);
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_WIDTH, InpWidthRes);
     }

   int sup_indices[] = {2, 4, 6};
   for(int i=0; i<ArraySize(sup_indices); i++)
     {
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_COLOR, InpColorSup);
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_STYLE, InpStyleSup);
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_WIDTH, InpWidthSup);
     }

   for(int i=7; i<=12; i++)
     {
      if(InpShowMedians)
        {
         PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_LINE);
         PlotIndexSetInteger(i, PLOT_LINE_COLOR, InpColorMed);
         PlotIndexSetInteger(i, PLOT_LINE_STYLE, InpStyleMed);
         PlotIndexSetInteger(i, PLOT_LINE_WIDTH, InpWidthMed);
        }
      else
        {
         PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
        }
     }

   g_calculator = new CPivotPointCalculator();
   if(!g_calculator.Init(InpPivotType, InpSourceType))
      return INIT_FAILED;

   if(InpTimeframe < Period())
     {
      Print("Error: Pivot Timeframe must be >= Current Timeframe");
      return INIT_PARAMETERS_INCORRECT;
     }

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
      delete g_calculator;
   ObjectsDeleteAll(0, "PivotLabel_");
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

// 1. Identify the start time of the CURRENT HTF Period
   datetime current_time = time[rates_total - 1]; // Use the latest time on chart

// This gives us the opening time of the HTF bar that 'current_time' belongs to (e.g., today 00:00)
   datetime pivot_period_start = iTime(_Symbol, InpTimeframe, 0);

   if(pivot_period_start == 0)
      return 0;

// 2. Calculate Levels for this period
   PivotLevels levels;
   if(!g_calculator.CalculateLevels(current_time, InpTimeframe, levels))
      return 0;

// 3. STRICT VISUAL MASKING LOOP
// We iterate through a relevant portion of the chart (e.g. from prev_calculated).
// Logic: If the bar's time is >= pivot_period_start, draw line.
//        If the bar's time is < pivot_period_start, FORCE EMPTY_VALUE.
   int limit;
   if(prev_calculated == 0)
      limit = 0;
   else
      limit = prev_calculated - 1;

// Iterate strictly chronologically (index 0 is oldest)
   for(int i = limit; i < rates_total; i++)
     {
      // CONDITIONAL DRAWING
      if(time[i] >= pivot_period_start)
        {
         // Inside the current period -> DRAW
         BufferPP[i] = levels.PP;
         BufferR1[i] = levels.R1;
         BufferS1[i] = levels.S1;
         BufferR2[i] = levels.R2;
         BufferS2[i] = levels.S2;
         BufferR3[i] = levels.R3;
         BufferS3[i] = levels.S3;

         if(InpShowMedians)
           {
            BufferM1[i] = (levels.S1 + levels.S2)/2;
            BufferM2[i] = (levels.S1 + levels.PP)/2;
            BufferM3[i] = (levels.PP + levels.R1)/2;
            BufferM4[i] = (levels.R1 + levels.R2)/2;
            BufferM5[i] = (levels.R2 + levels.R3)/2;
            BufferM6[i] = (levels.S2 + levels.S3)/2;
           }
        }
      else
        {
         // Before the current period -> CLEANUP
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

// 4. Update Labels
   if(InpShowLabels)
      UpdateLabels(levels);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper: Update Labels                                            |
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

   if(InpShowMedians)
     {
      CreateLabel("S1-S2", (levels.S1 + levels.S2)/2, InpColorMed, true);
      CreateLabel("PP-S1", (levels.S1 + levels.PP)/2, InpColorMed, true);
      CreateLabel("PP-R1", (levels.PP + levels.R1)/2, InpColorMed, true);
      CreateLabel("R1-R2", (levels.R1 + levels.R2)/2, InpColorMed, true);
      CreateLabel("R2-R3", (levels.R2 + levels.R3)/2, InpColorMed, true);
      CreateLabel("S2-S3", (levels.S2 + levels.S3)/2, InpColorMed, true);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, double price, color col, bool small=false)
  {
   if(price == EMPTY_VALUE || price == 0)
      return;
   string objName = "PivotLabel_" + name;

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
     }

// Position relative to current bar
   datetime time = iTime(_Symbol, Period(), 0) + PeriodSeconds() * InpLabelShift;

   ObjectSetString(0, objName, OBJPROP_TEXT, "  " + name);
   ObjectSetDouble(0, objName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, objName, OBJPROP_TIME, time);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, small ? InpFontSize-2 : InpFontSize);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
