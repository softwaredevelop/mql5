//+------------------------------------------------------------------+
//|                                       Murrey_Math_Line_X_Pro.mq5 |
//|                                         Copyright 2025, xxxxxxxx |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.00" // REFACTORED: Refactored Murrey Math Lines with modular architecture
#property description "A clean, object-oriented Murrey Math Lines indicator with MTF support."

#property indicator_chart_window
#property indicator_plots 0

//--- Includes
#include <MyIncludes\MurreyMath_Calculator.mqh>
#include <MyIncludes\MurreyMath_Drawer.mqh>

//--- Input Parameters
input int             InpPeriod         = 64;          // Calculation Period
input ENUM_TIMEFRAMES InpUpperTimeframe = PERIOD_H4;   // Calculation Timeframe
input int             InpStepBack       = 0;           // Step Back (Shift)

//--- Restored Enum exactly as requested
enum enum_side { Left, Right };
input enum_side       InpLabelSide      = Left;        // Label Position

input group "Visual Settings"
input string          InpFontFace       = "Verdana";   // Font Face
input int             InpFontSize       = 10;          // Font Size
input string          InpObjectPrefix   = "MML_Pro-";  // Object Prefix

input group "Line Colors"
input color InpClr_m2_8 = clrDimGray;
input color InpClr_m1_8 = clrDimGray;
input color InpClr_0_8  = clrDarkOrange;
input color InpClr_1_8  = clrGoldenrod;
input color InpClr_2_8  = clrFireBrick;
input color InpClr_3_8  = clrSeaGreen;
input color InpClr_4_8  = clrRoyalBlue;
input color InpClr_5_8  = clrSeaGreen;
input color InpClr_6_8  = clrFireBrick;
input color InpClr_7_8  = clrGoldenrod;
input color InpClr_8_8  = clrDarkOrange;
input color InpClr_p1_8 = clrDimGray;
input color InpClr_p2_8 = clrDimGray;

input group "Line Widths"
input int InpWdth_m2_8 = 1;
input int InpWdth_m1_8 = 1;
input int InpWdth_0_8  = 1;
input int InpWdth_1_8  = 1;
input int InpWdth_2_8  = 1;
input int InpWdth_3_8  = 1;
input int InpWdth_4_8  = 1;
input int InpWdth_5_8  = 1;
input int InpWdth_6_8  = 1;
input int InpWdth_7_8  = 1;
input int InpWdth_8_8  = 1;
input int InpWdth_p1_8 = 1;
input int InpWdth_p2_8 = 1;

//--- Global Objects
CMurreyMathCalculator *g_calculator;
CMurreyMathDrawer     *g_drawer;
double                 g_levels[13];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_calculator = new CMurreyMathCalculator();
   g_drawer     = new CMurreyMathDrawer();

   ENUM_TIMEFRAMES calc_tf = (InpUpperTimeframe == PERIOD_CURRENT) ? Period() : InpUpperTimeframe;

//--- Init Calculator
   if(!g_calculator.Init(_Symbol, calc_tf, InpPeriod, InpStepBack))
      return(INIT_FAILED);

//--- Init Drawer
//--- We convert the enum to bool here for the drawer, keeping the drawer simple
   bool is_right = (InpLabelSide == Right);
   string final_prefix = InpObjectPrefix + IntegerToString(ChartID()) + "_";

   g_drawer.Init(final_prefix, InpFontFace, InpFontSize, is_right);

//--- Set Styles
   color colors[13] = {InpClr_m2_8, InpClr_m1_8, InpClr_0_8, InpClr_1_8, InpClr_2_8, InpClr_3_8,
                       InpClr_4_8, InpClr_5_8, InpClr_6_8, InpClr_7_8, InpClr_8_8, InpClr_p1_8, InpClr_p2_8
                      };
   int widths[13]   = {InpWdth_m2_8, InpWdth_m1_8, InpWdth_0_8, InpWdth_1_8, InpWdth_2_8, InpWdth_3_8,
                       InpWdth_4_8, InpWdth_5_8, InpWdth_6_8, InpWdth_7_8, InpWdth_8_8, InpWdth_p1_8, InpWdth_p2_8
                      };

   g_drawer.SetLineStyles(colors, widths);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) == POINTER_DYNAMIC)
      delete g_calculator;
   if(CheckPointer(g_drawer) == POINTER_DYNAMIC)
      delete g_drawer;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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

//--- Ensure time array is series for drawing logic
   ArraySetAsSeries(time, true);

//--- 1. Try to Calculate
//--- If this returns false (not enough data), we do NOT draw.
   bool success = g_calculator.Calculate(g_levels);

   if(success)
     {
      //--- 2. Draw only on success
      g_drawer.Draw(time, g_levels);
     }
   else
     {
      // Optional: Logic for when data is loading (e.g. Comment)
      // But per request, we just don't draw the levels yet.
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
