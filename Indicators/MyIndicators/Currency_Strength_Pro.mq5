//+------------------------------------------------------------------+
//|                                        Currency_Strength_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.30" // Fixed smoothing overflow bug
#property description "Displays the relative strength of 8 major currencies."

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot Settings
#property indicator_label1  "USD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_width1  2

#property indicator_label2  "EUR"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

#property indicator_label3  "GBP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_width3  2

#property indicator_label4  "JPY"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGold
#property indicator_width4  2

#property indicator_label5  "AUD"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_width5  1

#property indicator_label6  "CAD"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_width6  1

#property indicator_label7  "CHF"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrSlateGray
#property indicator_width7  1

#property indicator_label8  "NZD"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrTurquoise
#property indicator_width8  1

#include <MyIncludes\Currency_Strength_Calculator.mqh>

//--- Input Parameters
input int             InpPeriod    = 14;           // ROC Period
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Calculation Timeframe
input bool            InpSmooth    = true;         // Smooth Results?
input int             InpSmoothPer = 5;            // Smoothing Period
input bool            InpShowPanel = true;         // Show Dashboard Panel?

input group           "Visibility Settings"
input bool            InpShowUSD   = true;         // Show USD
input bool            InpShowEUR   = true;         // Show EUR
input bool            InpShowGBP   = true;         // Show GBP
input bool            InpShowJPY   = true;         // Show JPY
input bool            InpShowAUD   = true;         // Show AUD
input bool            InpShowCAD   = true;         // Show CAD
input bool            InpShowCHF   = true;         // Show CHF
input bool            InpShowNZD   = true;         // Show NZD

//--- Buffers
double BufUSD[], BufEUR[], BufGBP[], BufJPY[], BufAUD[], BufCAD[], BufCHF[], BufNZD[];

//--- Global Objects
CCurrencyStrengthCalculator *g_calculator;
string g_prefix;
int    g_window_idx;
bool   g_show_flags[8];

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufUSD, INDICATOR_DATA);
   SetIndexBuffer(1, BufEUR, INDICATOR_DATA);
   SetIndexBuffer(2, BufGBP, INDICATOR_DATA);
   SetIndexBuffer(3, BufJPY, INDICATOR_DATA);
   SetIndexBuffer(4, BufAUD, INDICATOR_DATA);
   SetIndexBuffer(5, BufCAD, INDICATOR_DATA);
   SetIndexBuffer(6, BufCHF, INDICATOR_DATA);
   SetIndexBuffer(7, BufNZD, INDICATOR_DATA);

// Initialize with EMPTY_VALUE to detect uncalculated areas
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// Store flags
   g_show_flags[0] = InpShowUSD;
   g_show_flags[1] = InpShowEUR;
   g_show_flags[2] = InpShowGBP;
   g_show_flags[3] = InpShowJPY;
   g_show_flags[4] = InpShowAUD;
   g_show_flags[5] = InpShowCAD;
   g_show_flags[6] = InpShowCHF;
   g_show_flags[7] = InpShowNZD;

   for(int i=0; i<8; i++)
     {
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod + (InpSmooth ? InpSmoothPer : 0));

      if(!g_show_flags[i])
         PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   g_calculator = new CCurrencyStrengthCalculator();
   ENUM_TIMEFRAMES tf = (InpTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpTimeframe;
   g_calculator.Init(InpPeriod, tf);

   g_prefix = "CS_Pro_" + IntegerToString(ChartID()) + "_";
   g_window_idx = ChartWindowFind();
   ObjectsDeleteAll(0, g_prefix);

   IndicatorSetString(INDICATOR_SHORTNAME, "Currency Strength");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   g_window_idx = ChartWindowFind();

   if(!g_calculator.IsDataReady())
      return 0;

   int start_index;
   if(prev_calculated == 0)
     {
      start_index = 0;
      // Explicitly clear buffers on full recalc
      ArrayInitialize(BufUSD, EMPTY_VALUE);
      ArrayInitialize(BufEUR, EMPTY_VALUE);
      ArrayInitialize(BufGBP, EMPTY_VALUE);
      ArrayInitialize(BufJPY, EMPTY_VALUE);
      ArrayInitialize(BufAUD, EMPTY_VALUE);
      ArrayInitialize(BufCAD, EMPTY_VALUE);
      ArrayInitialize(BufCHF, EMPTY_VALUE);
      ArrayInitialize(BufNZD, EMPTY_VALUE);
     }
   else
      start_index = prev_calculated - 1;

   if(start_index == 0 && rates_total > 500)
      start_index = rates_total - 500;

// --- 1. Calculate Raw Strength ---
   for(int i = start_index; i < rates_total; i++)
     {
      int shift = rates_total - 1 - i;
      double strengths[8];
      g_calculator.CalculateStep(shift, strengths);

      BufUSD[i] = strengths[0];
      BufEUR[i] = strengths[1];
      BufGBP[i] = strengths[2];
      BufJPY[i] = strengths[3];
      BufAUD[i] = strengths[4];
      BufCAD[i] = strengths[5];
      BufCHF[i] = strengths[6];
      BufNZD[i] = strengths[7];
     }

// --- 2. Apply Smoothing ---
   if(InpSmooth && InpSmoothPer > 1)
     {
      double alpha = 2.0 / (InpSmoothPer + 1.0);

      // Determine start of smoothing loop
      int i = start_index;

      // If this is the very first bar of the calculation (e.g. index 0 or index 1000 after limit),
      // we cannot smooth it with the previous bar because the previous bar is EMPTY or non-existent.
      // So we skip the first bar of the batch (leaving it raw) and start smoothing from the next.

      if(i == 0)
         i = 1;
      else
         if(BufUSD[i-1] == EMPTY_VALUE)
            i++;

      for(; i < rates_total; i++)
        {
         // Safety check: if prev value is empty, we can't smooth.
         if(BufUSD[i-1] == EMPTY_VALUE)
            continue;

         BufUSD[i] = BufUSD[i] * alpha + BufUSD[i-1] * (1.0 - alpha);
         BufEUR[i] = BufEUR[i] * alpha + BufEUR[i-1] * (1.0 - alpha);
         BufGBP[i] = BufGBP[i] * alpha + BufGBP[i-1] * (1.0 - alpha);
         BufJPY[i] = BufJPY[i] * alpha + BufJPY[i-1] * (1.0 - alpha);
         BufAUD[i] = BufAUD[i] * alpha + BufAUD[i-1] * (1.0 - alpha);
         BufCAD[i] = BufCAD[i] * alpha + BufCAD[i-1] * (1.0 - alpha);
         BufCHF[i] = BufCHF[i] * alpha + BufCHF[i-1] * (1.0 - alpha);
         BufNZD[i] = BufNZD[i] * alpha + BufNZD[i-1] * (1.0 - alpha);
        }
     }

// --- 3. Update Dashboard ---
   if(InpShowPanel)
      DrawDashboard(rates_total - 1);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw Dashboard Panel                                             |
//+------------------------------------------------------------------+
void DrawDashboard(int last_idx)
  {
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"};
   color colors[]      = {clrGreen, clrDodgerBlue, clrRed, clrGold, clrOrange, clrMagenta, clrSlateGray, clrTurquoise};
   double values[8];

   values[0] = BufUSD[last_idx];
   values[1] = BufEUR[last_idx];
   values[2] = BufGBP[last_idx];
   values[3] = BufJPY[last_idx];
   values[4] = BufAUD[last_idx];
   values[5] = BufCAD[last_idx];
   values[6] = BufCHF[last_idx];
   values[7] = BufNZD[last_idx];

// Handle NaN/Empty
   for(int i=0; i<8; i++)
      if(!MathIsValidNumber(values[i]) || values[i] == EMPTY_VALUE)
         values[i] = 0.0;

// Sort
   int indices[] = {0, 1, 2, 3, 4, 5, 6, 7};
   for(int i=0; i<8; i++)
      for(int j=0; j<7-i; j++)
         if(values[indices[j]] < values[indices[j+1]])
           {
            int temp = indices[j];
            indices[j] = indices[j+1];
            indices[j+1] = temp;
           }

   int x_base = 10;
   int x_step = 95;
   int y_pos = 20;
   int drawn_count = 0;

   for(int i=0; i<8; i++)
     {
      int idx = indices[i];

      if(!g_show_flags[idx])
         continue;

      string name = g_prefix + "Label_" + IntegerToString(i);

      string val_str;
      if(values[idx] == 0.0 && (BufUSD[last_idx] == EMPTY_VALUE || BufUSD[last_idx] == 0.0))
         val_str = "N/A";
      else
         val_str = StringFormat("%.3f", values[idx]);

      string text = StringFormat("%s: %s", currencies[idx], val_str);

      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, g_window_idx, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_pos);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        }

      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_base + drawn_count * x_step);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, colors[idx]);

      drawn_count++;
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
