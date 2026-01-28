//+------------------------------------------------------------------+
//|                                              PivotPoints_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Current Period Only + Full Visual Customization
#property description "Professional Pivot Points (Current Period Only)."
#property description "Fully customizable colors, styles, and calculation modes."

#property indicator_chart_window
#property indicator_buffers 14
#property indicator_plots   13

//--- Default Plot definitions
// Main Levels (0-6)
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

// Median Levels (7-12)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group             "Visual Settings - Resistance (R1-R3)"
input color             InpColorRes       = clrDodgerBlue;  // Resistance Color
input ENUM_LINE_STYLE   InpStyleRes       = STYLE_SOLID;    // Resistance Style
input int               InpWidthRes       = 1;              // Resistance Width

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group             "Visual Settings - Support (S1-S3)"
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
// Medians: M1(S1-S2), M2(PP-S1), M3(PP-R1), M4(R1-R2), M5(R2-R3), M6(S2-S3)
double BufferM1[], BufferM2[], BufferM3[], BufferM4[], BufferM5[], BufferM6[];

//--- Global Objects
CPivotPointCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Indicator Buffers Mapping
   SetIndexBuffer(0, BufferPP, INDICATOR_DATA);
   SetIndexBuffer(1, BufferR1, INDICATOR_DATA);
   SetIndexBuffer(2, BufferS1, INDICATOR_DATA);
   SetIndexBuffer(3, BufferR2, INDICATOR_DATA);
   SetIndexBuffer(4, BufferS2, INDICATOR_DATA);
   SetIndexBuffer(5, BufferR3, INDICATOR_DATA);
   SetIndexBuffer(6, BufferS3, INDICATOR_DATA);

   SetIndexBuffer(7, BufferM1, INDICATOR_DATA); // S1-S2
   SetIndexBuffer(8, BufferM2, INDICATOR_DATA); // PP-S1
   SetIndexBuffer(9, BufferM3, INDICATOR_DATA); // PP-R1
   SetIndexBuffer(10, BufferM4, INDICATOR_DATA); // R1-R2
   SetIndexBuffer(11, BufferM5, INDICATOR_DATA); // R2-R3
   SetIndexBuffer(12, BufferM6, INDICATOR_DATA); // S2-S3

//--- Apply Visual Styles Dynamically
// PP
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorPP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStylePP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthPP);

// Resistance
   int res_indices[] = {1, 3, 5};
   for(int i=0; i<ArraySize(res_indices); i++)
     {
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_COLOR, InpColorRes);
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_STYLE, InpStyleRes);
      PlotIndexSetInteger(res_indices[i], PLOT_LINE_WIDTH, InpWidthRes);
     }

// Support
   int sup_indices[] = {2, 4, 6};
   for(int i=0; i<ArraySize(sup_indices); i++)
     {
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_COLOR, InpColorSup);
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_STYLE, InpStyleSup);
      PlotIndexSetInteger(sup_indices[i], PLOT_LINE_WIDTH, InpWidthSup);
     }

// Medians
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

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("PivotPro(%s, %s)", EnumToString(InpTimeframe), EnumToString(InpPivotType)));
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

//--- 1. Calculate Levels for the CURRENT moment
   PivotLevels levels;
   datetime current_time = time[rates_total - 1];

   if(!g_calculator.CalculateLevels(current_time, InpTimeframe, levels))
      return 0; // Data not ready

//--- 2. Determine the start time of the current HTF bar
   int shift = iBarShift(_Symbol, InpTimeframe, current_time);
   datetime htf_start_time = iTime(_Symbol, InpTimeframe, shift);

// Find the index in the current chart corresponding to htf_start_time
   int start_index = iBarShift(_Symbol, Period(), htf_start_time);
   if(start_index < 0)
      start_index = 0;

//--- 3. Handle New Period (Clear old lines)
   static int prev_start_index = -1;

   if(prev_calculated == 0)
     {
      // Full init
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
      prev_start_index = start_index;
     }
   else
      if(start_index != prev_start_index)
        {
         // New period started! Clear the previous period's lines to avoid clutter
         // We clear a safe range backwards
         int clear_from = MathMax(0, start_index - 500);
         for(int k = clear_from; k < start_index; k++)
           {
            BufferPP[k] = EMPTY_VALUE;
            BufferR1[k] = EMPTY_VALUE;
            BufferS1[k] = EMPTY_VALUE;
            BufferR2[k] = EMPTY_VALUE;
            BufferS2[k] = EMPTY_VALUE;
            BufferR3[k] = EMPTY_VALUE;
            BufferS3[k] = EMPTY_VALUE;
            BufferM1[k] = EMPTY_VALUE;
            BufferM2[k] = EMPTY_VALUE;
            BufferM3[k] = EMPTY_VALUE;
            BufferM4[k] = EMPTY_VALUE;
            BufferM5[k] = EMPTY_VALUE;
            BufferM6[k] = EMPTY_VALUE;
           }
         prev_start_index = start_index;
        }

//--- 4. Fill Current Period Buffers
   for(int i = start_index; i < rates_total; i++)
     {
      BufferPP[i] = levels.PP;
      BufferR1[i] = levels.R1;
      BufferS1[i] = levels.S1;
      BufferR2[i] = levels.R2;
      BufferS2[i] = levels.S2;
      BufferR3[i] = levels.R3;
      BufferS3[i] = levels.S3;

      if(InpShowMedians)
        {
         BufferM1[i] = (levels.S1 + levels.S2)/2; // S1-S2
         BufferM2[i] = (levels.S1 + levels.PP)/2; // PP-S1
         BufferM3[i] = (levels.PP + levels.R1)/2; // PP-R1
         BufferM4[i] = (levels.R1 + levels.R2)/2; // R1-R2
         BufferM5[i] = (levels.R2 + levels.R3)/2; // R2-R3
         BufferM6[i] = (levels.S2 + levels.S3)/2; // S2-S3
        }
     }

//--- 5. Update Labels
   if(InpShowLabels)
     {
      UpdateLabel("PP", levels.PP, InpColorPP);

      UpdateLabel("R1", levels.R1, InpColorRes);
      UpdateLabel("R2", levels.R2, InpColorRes);
      UpdateLabel("R3", levels.R3, InpColorRes);

      UpdateLabel("S1", levels.S1, InpColorSup);
      UpdateLabel("S2", levels.S2, InpColorSup);
      UpdateLabel("S3", levels.S3, InpColorSup);

      if(InpShowMedians)
        {
         UpdateLabel("S1-S2", (levels.S1 + levels.S2)/2, InpColorMed, true);
         UpdateLabel("PP-S1", (levels.S1 + levels.PP)/2, InpColorMed, true);
         UpdateLabel("PP-R1", (levels.PP + levels.R1)/2, InpColorMed, true);
         UpdateLabel("R1-R2", (levels.R1 + levels.R2)/2, InpColorMed, true);
         UpdateLabel("R2-R3", (levels.R2 + levels.R3)/2, InpColorMed, true);
         UpdateLabel("S2-S3", (levels.S2 + levels.S3)/2, InpColorMed, true);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper: Update Text Label                                        |
//+------------------------------------------------------------------+
void UpdateLabel(string name, double price, color col, bool small=false)
  {
   if(price == EMPTY_VALUE || price == 0)
      return;

   string objName = "PivotLabel_" + name;
   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
     }

   datetime time = iTime(_Symbol, Period(), 0) + PeriodSeconds() * InpLabelShift;

   ObjectSetString(0, objName, OBJPROP_TEXT, "  " + name);
   ObjectSetDouble(0, objName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, objName, OBJPROP_TIME, time);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, small ? InpFontSize-2 : InpFontSize);
  }
//+------------------------------------------------------------------+
