//+------------------------------------------------------------------+
//|                                     LinearRegressionChannel.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.00" // Final version using OBJ_REGRESSION with smart update
#property description "Draws a clean Linear Regression Channel, updated on new bars."
#property indicator_chart_window
#property indicator_buffers 0 // No buffers needed for plotting
#property indicator_plots   0 // No plots needed

//--- Input Parameters ---
input int    InpRegressionPeriod = 100;
input double InpDeviations       = 2.0;
// Note: OBJ_REGRESSION always uses PRICE_CLOSE, so InpAppliedPrice is not needed.

//--- Global Variables ---
int       g_ExtPeriod;
double    g_ExtDeviations;
string    g_channel_name;
datetime  g_last_update_time; // To track the time of the last update

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod      = (InpRegressionPeriod < 2) ? 2 : InpRegressionPeriod;
   g_ExtDeviations  = (InpDeviations <= 0) ? 2.0 : InpDeviations;

   g_channel_name = "LinRegChannel_" + IntegerToString(ChartID()) + "_" + IntegerToString(GetTickCount());
   g_last_update_time = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg(%d, %.1f)", g_ExtPeriod, g_ExtDeviations));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Clean up the chart object
   ObjectDelete(0, g_channel_name);
   ChartRedraw();
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

//--- Check if a new bar has appeared ---
   datetime last_bar_time = time[rates_total - 1];
   if(last_bar_time > g_last_update_time)
     {
      UpdateRegressionChannel(rates_total, time);
      g_last_update_time = last_bar_time;
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Updates the position and properties of the regression channel.   |
//+------------------------------------------------------------------+
void UpdateRegressionChannel(int rates_total, const datetime &time[])
  {
// Define the start and end time for the channel
   datetime time1 = time[rates_total - g_ExtPeriod];
   datetime time2 = time[rates_total - 1];

// Check if the object exists. If not, create it.
   if(ObjectFind(0, g_channel_name) < 0)
     {
      if(!ObjectCreate(0, g_channel_name, OBJ_REGRESSION, 0, time1, 0, time2, 0))
        {
         Print("Error creating regression channel object: ", GetLastError());
         return;
        }

      // Set visual properties only once on creation
      ObjectSetInteger(0, g_channel_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, g_channel_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetDouble(0, g_channel_name, OBJPROP_DEVIATION, g_ExtDeviations);
      ObjectSetInteger(0, g_channel_name, OBJPROP_FILL, false);
      ObjectSetInteger(0, g_channel_name, OBJPROP_RAY_RIGHT, false); // Do not extend to the right
      ObjectSetInteger(0, g_channel_name, OBJPROP_SELECTABLE, false);
     }
   else // If it exists, just move its time coordinates
     {
      ObjectSetInteger(0, g_channel_name, OBJPROP_TIME, 0, time1);
      ObjectSetInteger(0, g_channel_name, OBJPROP_TIME, 1, time2);
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
