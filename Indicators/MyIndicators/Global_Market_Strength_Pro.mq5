//+------------------------------------------------------------------+
//|                                   Global_Market_Strength_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Added 3 decimal precision and robust error handling
#property description "Displays the relative strength of user-defined symbols (Indices, Commodities, etc.)."

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot Settings (Generic)
#property indicator_type1   DRAW_LINE
#property indicator_width1  2
#property indicator_type2   DRAW_LINE
#property indicator_width2  2
#property indicator_type3   DRAW_LINE
#property indicator_width3  2
#property indicator_type4   DRAW_LINE
#property indicator_width4  2
#property indicator_type5   DRAW_LINE
#property indicator_width5  2
#property indicator_type6   DRAW_LINE
#property indicator_width6  2
#property indicator_type7   DRAW_LINE
#property indicator_width7  2
#property indicator_type8   DRAW_LINE
#property indicator_width8  2

#include <MyIncludes\Symbol_Strength_Calculator.mqh>

//--- Input Parameters
input int             InpPeriod    = 14;           // ROC Period
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Calculation Timeframe
input bool            InpSmooth    = true;         // Smooth Results?
input int             InpSmoothPer = 5;            // Smoothing Period
input bool            InpShowPanel = true;         // Show Dashboard Panel?

input group           "Symbols & Colors"
input string          InpSymbol1   = "US500";      // Symbol 1
input color           InpColor1    = clrGreen;     // Color 1
input string          InpSymbol2   = "USTEC";      // Symbol 2
input color           InpColor2    = clrRed;       // Color 2
input string          InpSymbol3   = "US30";       // Symbol 3
input color           InpColor3    = clrDodgerBlue;// Color 3
input string          InpSymbol4   = "DE40";       // Symbol 4
input color           InpColor4    = clrGold;      // Color 4
input string          InpSymbol5   = "UK100";      // Symbol 5
input color           InpColor5    = clrMagenta;   // Color 5
input string          InpSymbol6   = "JP225";      // Symbol 6
input color           InpColor6    = clrOrange;    // Color 6
input string          InpSymbol7   = "XAUUSD";       // Symbol 7
input color           InpColor7    = clrSlateGray;     // Color 7
input string          InpSymbol8   = "XTIUSD";        // Symbol 8
input color           InpColor8    = clrTurquoise; // Color 8

//--- Buffers
double Buf1[], Buf2[], Buf3[], Buf4[], Buf5[], Buf6[], Buf7[], Buf8[];

//--- Global Objects
CSymbolStrengthCalculator *g_calculator;
string g_prefix;
int    g_window_idx;
string g_symbols[8];
color  g_colors[8];

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, Buf1, INDICATOR_DATA);
   SetIndexBuffer(1, Buf2, INDICATOR_DATA);
   SetIndexBuffer(2, Buf3, INDICATOR_DATA);
   SetIndexBuffer(3, Buf4, INDICATOR_DATA);
   SetIndexBuffer(4, Buf5, INDICATOR_DATA);
   SetIndexBuffer(5, Buf6, INDICATOR_DATA);
   SetIndexBuffer(6, Buf7, INDICATOR_DATA);
   SetIndexBuffer(7, Buf8, INDICATOR_DATA);

// Collect inputs
   g_symbols[0] = InpSymbol1;
   g_colors[0] = InpColor1;
   g_symbols[1] = InpSymbol2;
   g_colors[1] = InpColor2;
   g_symbols[2] = InpSymbol3;
   g_colors[2] = InpColor3;
   g_symbols[3] = InpSymbol4;
   g_colors[3] = InpColor4;
   g_symbols[4] = InpSymbol5;
   g_colors[4] = InpColor5;
   g_symbols[5] = InpSymbol6;
   g_colors[5] = InpColor6;
   g_symbols[6] = InpSymbol7;
   g_colors[6] = InpColor7;
   g_symbols[7] = InpSymbol8;
   g_colors[7] = InpColor8;

   for(int i=0; i<8; i++)
     {
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod + (InpSmooth ? InpSmoothPer : 0));
      PlotIndexSetInteger(i, PLOT_LINE_COLOR, g_colors[i]);
      PlotIndexSetString(i, PLOT_LABEL, g_symbols[i]);

      // Hide unused plots
      if(g_symbols[i] == "")
         PlotIndexSetInteger(i, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   g_calculator = new CSymbolStrengthCalculator();
   ENUM_TIMEFRAMES tf = (InpTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpTimeframe;
   g_calculator.Init(InpPeriod, tf, g_symbols);

   g_prefix = "GMS_Pro_" + IntegerToString(ChartID()) + "_";
   g_window_idx = ChartWindowFind();
   ObjectsDeleteAll(0, g_prefix);

   IndicatorSetString(INDICATOR_SHORTNAME, "Global Market Strength");
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

//--- Check Data Readiness
   if(!g_calculator.IsDataReady())
      return 0;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   if(start_index == 0 && rates_total > 500)
      start_index = rates_total - 500;

// --- 1. Calculate Raw Strength ---
   for(int i = start_index; i < rates_total; i++)
     {
      int shift = rates_total - 1 - i;
      double strengths[];
      g_calculator.CalculateStep(shift, strengths);

      // Handle EMPTY_VALUE
      Buf1[i] = (strengths[0] != EMPTY_VALUE) ? strengths[0] : (i>0 ? Buf1[i-1] : 0);
      Buf2[i] = (strengths[1] != EMPTY_VALUE) ? strengths[1] : (i>0 ? Buf2[i-1] : 0);
      Buf3[i] = (strengths[2] != EMPTY_VALUE) ? strengths[2] : (i>0 ? Buf3[i-1] : 0);
      Buf4[i] = (strengths[3] != EMPTY_VALUE) ? strengths[3] : (i>0 ? Buf4[i-1] : 0);
      Buf5[i] = (strengths[4] != EMPTY_VALUE) ? strengths[4] : (i>0 ? Buf5[i-1] : 0);
      Buf6[i] = (strengths[5] != EMPTY_VALUE) ? strengths[5] : (i>0 ? Buf6[i-1] : 0);
      Buf7[i] = (strengths[6] != EMPTY_VALUE) ? strengths[6] : (i>0 ? Buf7[i-1] : 0);
      Buf8[i] = (strengths[7] != EMPTY_VALUE) ? strengths[7] : (i>0 ? Buf8[i-1] : 0);
     }

// --- 2. Apply Smoothing ---
   if(InpSmooth && InpSmoothPer > 1)
     {
      double alpha = 2.0 / (InpSmoothPer + 1.0);
      int smooth_start = (start_index == 0) ? 1 : start_index;

      for(int i = smooth_start; i < rates_total; i++)
        {
         if(g_symbols[0] != "")
            Buf1[i] = Buf1[i] * alpha + Buf1[i-1] * (1.0 - alpha);
         if(g_symbols[1] != "")
            Buf2[i] = Buf2[i] * alpha + Buf2[i-1] * (1.0 - alpha);
         if(g_symbols[2] != "")
            Buf3[i] = Buf3[i] * alpha + Buf3[i-1] * (1.0 - alpha);
         if(g_symbols[3] != "")
            Buf4[i] = Buf4[i] * alpha + Buf4[i-1] * (1.0 - alpha);
         if(g_symbols[4] != "")
            Buf5[i] = Buf5[i] * alpha + Buf5[i-1] * (1.0 - alpha);
         if(g_symbols[5] != "")
            Buf6[i] = Buf6[i] * alpha + Buf6[i-1] * (1.0 - alpha);
         if(g_symbols[6] != "")
            Buf7[i] = Buf7[i] * alpha + Buf7[i-1] * (1.0 - alpha);
         if(g_symbols[7] != "")
            Buf8[i] = Buf8[i] * alpha + Buf8[i-1] * (1.0 - alpha);
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
   double values[8];
// Handle NaN/Empty
   for(int i=0; i<8; i++)
     {
      double val = 0;
      switch(i)
        {
         case 0:
            val = Buf1[last_idx];
            break;
         case 1:
            val = Buf2[last_idx];
            break;
         case 2:
            val = Buf3[last_idx];
            break;
         case 3:
            val = Buf4[last_idx];
            break;
         case 4:
            val = Buf5[last_idx];
            break;
         case 5:
            val = Buf6[last_idx];
            break;
         case 6:
            val = Buf7[last_idx];
            break;
         case 7:
            val = Buf8[last_idx];
            break;
        }

      if(!MathIsValidNumber(val) || val == EMPTY_VALUE)
         values[i] = 0.0;
      else
         values[i] = val;
     }

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
   int x_step = 105;
   int y_pos = 20;
   int drawn_count = 0;

   for(int i=0; i<8; i++)
     {
      int idx = indices[i];
      if(g_symbols[idx] == "")
         continue; // Skip empty slots

      string name = g_prefix + "Label_" + IntegerToString(i);

      string val_str;
      if(values[idx] == 0.0 && (Buf1[last_idx] == EMPTY_VALUE)) // Check if it was truly empty
         val_str = "N/A";
      else
         val_str = StringFormat("%.3f%%", values[idx]); // 3 decimals

      string text = StringFormat("%s: %s", g_symbols[idx], val_str);

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
      ObjectSetInteger(0, name, OBJPROP_COLOR, g_colors[idx]);

      drawn_count++;
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
