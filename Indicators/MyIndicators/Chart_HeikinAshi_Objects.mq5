//+------------------------------------------------------------------+
//|                                 Chart_HeikinAshi_Objects.mq5     |
//|                      Copyright 2025, xxxxxxxx                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Added Width inputs
#property description "Draws Heikin Ashi candles using Objects for perfect sharpness."

#include <MyIncludes\HeikinAshi_Tools.mqh>

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   0

input int InpMaxHistory = 500; // Limit bars to draw
input int InpBodyWidth  = 3;   // Width of the candle body
input int InpWickWidth  = 1;   // Width of the candle wick

double BufHA_Open[], BufHA_High[], BufHA_Low[], BufHA_Close[];
CHeikinAshi_Calculator *g_ha_calculator;
string g_prefix;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufHA_Open, INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, BufHA_High, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufHA_Low, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufHA_Close, INDICATOR_CALCULATIONS);

   g_ha_calculator = new CHeikinAshi_Calculator();
   g_prefix = "HA_Obj_" + IntegerToString(ChartID()) + "_";
   ObjectsDeleteAll(0, g_prefix);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
      delete g_ha_calculator;
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < 2)
      return(0);

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

   g_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             BufHA_Open, BufHA_High, BufHA_Low, BufHA_Close);

// Draw Objects
   int draw_start = MathMax(start_index, rates_total - InpMaxHistory);

   for(int i = draw_start; i < rates_total; i++)
     {
      string name_body = g_prefix + "B_" + IntegerToString(i);
      string name_wick = g_prefix + "W_" + IntegerToString(i);

      double o = BufHA_Open[i];
      double c = BufHA_Close[i];
      double h = BufHA_High[i];
      double l = BufHA_Low[i];

      color col = (c > o) ? clrCornflowerBlue : clrChocolate;

      // Body
      if(ObjectFind(0, name_body) < 0)
        {
         ObjectCreate(0, name_body, OBJ_RECTANGLE, 0, time[i], o, time[i], c);
        }

      if(ObjectFind(0, name_body) < 0)
        {
         ObjectCreate(0, name_body, OBJ_TREND, 0, time[i], o, time[i], c);
         ObjectSetInteger(0, name_body, OBJPROP_RAY, false);
        }
      ObjectSetInteger(0, name_body, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name_body, OBJPROP_WIDTH, InpBodyWidth); // Body Width
      ObjectMove(0, name_body, 0, time[i], o);
      ObjectMove(0, name_body, 1, time[i], c);

      // Wick
      if(ObjectFind(0, name_wick) < 0)
        {
         ObjectCreate(0, name_wick, OBJ_TREND, 0, time[i], h, time[i], l);
         ObjectSetInteger(0, name_wick, OBJPROP_RAY, false);
        }
      ObjectSetInteger(0, name_wick, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name_wick, OBJPROP_WIDTH, InpWickWidth); // Wick Width
      ObjectMove(0, name_wick, 0, time[i], h);
      ObjectMove(0, name_wick, 1, time[i], l);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
