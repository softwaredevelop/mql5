//+------------------------------------------------------------------+
//|                                     LinearRegressionChannel.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Added color selection
#property description "Draws a Linear Regression Channel where width is based on max deviation."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input Parameters ---
input int   InpRegressionPeriod = 100;   // Period for the regression calculation
input color InpChannelColor     = clrRed;  // Channel color
input group "Channel Extensions"
input bool  InpRayRight         = false; // Extend channel to the right
input bool  InpRayLeft          = false; // Extend channel to the left

//--- Global Variables ---
int       g_ExtPeriod;
string    g_channel_name;
datetime  g_last_update_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod      = (InpRegressionPeriod < 2) ? 2 : InpRegressionPeriod;

   g_channel_name = "LinRegChannel_" + IntegerToString(ChartID()) + "_" + IntegerToString(GetTickCount());
   g_last_update_time = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg(%d)", g_ExtPeriod));

   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectDelete(0, g_channel_name);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Timer event handler.                                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateChannel();
  }

//+------------------------------------------------------------------+
//| Main calculation function.                                       |
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
   if(rates_total < g_ExtPeriod)
      return(0);

   datetime last_bar_time = time[rates_total - 1];
   if(last_bar_time > g_last_update_time)
     {
      UpdateChannel();
      g_last_update_time = last_bar_time;
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Updates the position and properties of the regression channel.   |
//+------------------------------------------------------------------+
void UpdateChannel()
  {
   if(Bars(_Symbol, _Period) < g_ExtPeriod)
      return;

   datetime time1 = iTime(_Symbol, _Period, g_ExtPeriod - 1);
   datetime time2 = iTime(_Symbol, _Period, 0);

   if(ObjectFind(0, g_channel_name) < 0)
     {
      if(!ObjectCreate(0, g_channel_name, OBJ_REGRESSION, 0, time1, 0, time2, 0))
        {
         Print("Error creating regression channel object: ", GetLastError());
         return;
        }

      // Set visual properties only once on creation
      ObjectSetInteger(0, g_channel_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_channel_name, OBJPROP_FILL, false);
      ObjectSetInteger(0, g_channel_name, OBJPROP_SELECTABLE, false);
     }

// Update properties on every call to allow for dynamic changes
   ObjectSetInteger(0, g_channel_name, OBJPROP_TIME, 0, time1);
   ObjectSetInteger(0, g_channel_name, OBJPROP_TIME, 1, time2);
   ObjectSetInteger(0, g_channel_name, OBJPROP_RAY_RIGHT, InpRayRight);
   ObjectSetInteger(0, g_channel_name, OBJPROP_RAY_LEFT, InpRayLeft);
// --- FIX: Set color based on input ---
   ObjectSetInteger(0, g_channel_name, OBJPROP_COLOR, InpChannelColor);

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
