//+------------------------------------------------------------------+
//|                                         LinearRegression_Pro.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Corrected price sourcing, removed non-existent function
#property description "A flexible, manually calculated Linear Regression Channel."
#property description "Updates only on new bars for efficiency."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Channel
#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Channel
#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Regression Line (Middle)
#property indicator_label3  "Regression"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID

//--- Enum for Channel Calculation Mode ---
enum ENUM_CHANNEL_MODE
  {
   DEVIATION_STANDARD, // Channel width based on Standard Deviation
   DEVIATION_MAXIMUM   // Channel width based on Maximum Deviation
  };

//--- Input Parameters ---
input int                InpRegressionPeriod = 100;
input ENUM_APPLIED_PRICE InpAppliedPrice     = PRICE_CLOSE;
input ENUM_CHANNEL_MODE  InpChannelMode      = DEVIATION_STANDARD;
input double             InpDeviations       = 2.0;     // Deviations (for Standard Deviation mode)

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Variables ---
int       g_ExtPeriod;
double    g_ExtDeviations;
datetime  g_last_update_time;

//--- Forward declarations ---
double GetPrice(int index, ENUM_APPLIED_PRICE type, const double &open[], const double &high[], const double &low[], const double &close[]);
void CalculateChannel(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtPeriod      = (InpRegressionPeriod < 2) ? 2 : InpRegressionPeriod;
   g_ExtDeviations  = (InpDeviations <= 0) ? 2.0 : InpDeviations;
   g_last_update_time = 0;

   SetIndexBuffer(0, BufferUpper,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferLower,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferMiddle, INDICATOR_DATA);

   ArraySetAsSeries(BufferUpper,  false);
   ArraySetAsSeries(BufferLower,  false);
   ArraySetAsSeries(BufferMiddle, false);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LinReg Pro(%d)", g_ExtPeriod));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Linear Regression Channel calculation function.                  |
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

//--- Update only on new bar ---
   if(time[rates_total - 1] > g_last_update_time)
     {
      ArrayInitialize(BufferUpper, EMPTY_VALUE);
      ArrayInitialize(BufferLower, EMPTY_VALUE);
      ArrayInitialize(BufferMiddle, EMPTY_VALUE);

      CalculateChannel(rates_total, open, high, low, close);

      g_last_update_time = time[rates_total - 1];
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Main calculation logic moved to a helper function                |
//+------------------------------------------------------------------+
void CalculateChannel(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   int start_index = rates_total - g_ExtPeriod;

//--- STEP 1: Calculate sums for the regression formula
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
   for(int i = 0; i < g_ExtPeriod; i++)
     {
      double y = GetPrice(start_index + i, InpAppliedPrice, open, high, low, close);
      double x = i;
      sum_x  += x;
      sum_y  += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

//--- STEP 2: Calculate slope (b) and intercept (a)
   double b = (g_ExtPeriod * sum_xy - sum_x * sum_y) / (g_ExtPeriod * sum_x2 - sum_x * sum_x);
   double a = (sum_y - b * sum_x) / g_ExtPeriod;

//--- STEP 3: Calculate regression values and deviation
   double deviation_offset = 0;
   double regression_values[];
   ArrayResize(regression_values, g_ExtPeriod);

   if(InpChannelMode == DEVIATION_STANDARD)
     {
      double deviation_sum_sq = 0;
      for(int i = 0; i < g_ExtPeriod; i++)
        {
         regression_values[i] = a + b * i;
         double price = GetPrice(start_index + i, InpAppliedPrice, open, high, low, close);
         double diff = price - regression_values[i];
         deviation_sum_sq += diff * diff;
        }
      double std_dev = MathSqrt(deviation_sum_sq / g_ExtPeriod);
      deviation_offset = g_ExtDeviations * std_dev;
     }
   else // DEVIATION_MAXIMUM
     {
      double max_dev = 0;
      for(int i = 0; i < g_ExtPeriod; i++)
        {
         regression_values[i] = a + b * i;
         double price = GetPrice(start_index + i, InpAppliedPrice, open, high, low, close);
         double dev = MathAbs(price - regression_values[i]);
         if(dev > max_dev)
            max_dev = dev;
        }
      deviation_offset = max_dev;
     }

//--- STEP 4: Fill the indicator buffers for the last N bars
   for(int i = 0; i < g_ExtPeriod; i++)
     {
      int buffer_index = start_index + i;
      BufferMiddle[buffer_index] = regression_values[i];
      BufferUpper[buffer_index]  = regression_values[i] + deviation_offset;
      BufferLower[buffer_index]  = regression_values[i] - deviation_offset;
     }

//--- Dynamically set the draw begin to only show the last channel
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, start_index);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, start_index);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, start_index);
  }

//+------------------------------------------------------------------+
//| Helper function to get the correct price type                    |
//+------------------------------------------------------------------+
double GetPrice(int index, ENUM_APPLIED_PRICE type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   switch(type)
     {
      case PRICE_OPEN:
         return open[index];
      case PRICE_HIGH:
         return high[index];
      case PRICE_LOW:
         return low[index];
      case PRICE_MEDIAN:
         return (high[index] + low[index]) / 2.0;
      case PRICE_TYPICAL:
         return (high[index] + low[index] + close[index]) / 3.0;
      case PRICE_WEIGHTED:
         return (high[index] + low[index] + 2*close[index]) / 4.0;
      default:
         return close[index];
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
