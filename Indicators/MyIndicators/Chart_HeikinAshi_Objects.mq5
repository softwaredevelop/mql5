//+------------------------------------------------------------------+
//|                                 Chart_HeikinAshi_Objects.mq5     |
//|                                     Copyright 2025, xxxxxxxx     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Updated for Colors and Background
#property description "Draws Heikin Ashi candles using Objects for perfect sharpness."

//--- Include the Tools (Assuming user's path)
#include <MyIncludes\HeikinAshi_Tools.mqh>

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   0 // No drawing buffers, only objects

//--- Inputs
input group "Visual Settings"
input int   InpMaxHistory = 500;             // Limit bars to draw
input int   InpBodyWidth  = 3;               // Width of the candle body
input int   InpWickWidth  = 1;               // Width of the candle wick
input color InpColorBull  = clrCornflowerBlue; // Bullish Color
input color InpColorBear  = clrChocolate;      // Bearish Color
input bool  InpBack       = true;            // Draw in Background

//--- Buffers (for calculation only)
double BufHA_Open[], BufHA_High[], BufHA_Low[], BufHA_Close[];

//--- Global Objects
CHeikinAshi_Calculator *g_ha_calculator;
string g_prefix;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Setup Buffers
   SetIndexBuffer(0, BufHA_Open, INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, BufHA_High, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufHA_Low, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufHA_Close, INDICATOR_CALCULATIONS);

//--- Initialize Calculator
   g_ha_calculator = new CHeikinAshi_Calculator();

//--- Create Unique Prefix for Objects
   g_prefix = "HA_Obj_" + IntegerToString(ChartID()) + "_";

//--- Cleanup stale objects from previous runs
   ObjectsDeleteAll(0, g_prefix);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
      delete g_ha_calculator;

//--- Clean up objects created by this indicator
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw();
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
      return(0);

//--- 1. Calculate Heikin Ashi Values (Incremental)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   g_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             BufHA_Open, BufHA_High, BufHA_Low, BufHA_Close);

//--- 2. Draw/Update Objects
   int draw_start = MathMax(start_index, rates_total - InpMaxHistory);

   for(int i = draw_start; i < rates_total; i++)
     {
      string name_body = g_prefix + "B_" + IntegerToString(i);
      string name_wick = g_prefix + "W_" + IntegerToString(i);

      double ha_open  = BufHA_Open[i];
      double ha_close = BufHA_Close[i];
      double ha_high  = BufHA_High[i];
      double ha_low   = BufHA_Low[i];
      datetime t      = time[i];

      // Determine Color
      bool is_bull = (ha_close >= ha_open);
      color candle_color = is_bull ? InpColorBull : InpColorBear;

      //--- Draw Wick (Low to High)
      UpdateObject(name_wick, t, ha_high, ha_low, InpWickWidth, candle_color);

      //--- Draw Body (Open to Close)
      UpdateObject(name_body, t, ha_open, ha_close, InpBodyWidth, candle_color);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper: Create or Update Trend Object                            |
//+------------------------------------------------------------------+
void UpdateObject(string name, datetime time, double price1, double price2, int width, color col)
  {
// If object doesn't exist, create it
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, time, price1, time, price2);
      // Essential properties for "Candle-like" appearance
      ObjectSetInteger(0, name, OBJPROP_RAY, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); // Prevent accidental selection
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);      // Hide from Object List (optional)
     }
   else
     {
      ObjectMove(0, name, 0, time, price1);
      ObjectMove(0, name, 1, time, price2);
     }

// Update visual properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, InpBack); // Set Background property
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
