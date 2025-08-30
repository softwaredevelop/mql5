//+------------------------------------------------------------------+
//|                                 LinearRegression_Pro_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "A flexible, manually calculated Linear Regression Channel on Heikin Ashi data."
#property description "Updates only on new bars for efficiency."

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 3 // Upper, Lower, Middle
#property indicator_plots   3

//--- Plot 1: Upper Channel
#property indicator_label1  "HA_Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DOT

//--- Plot 2: Lower Channel
#property indicator_label2  "HA_Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT

//--- Plot 3: Regression Line (Middle)
#property indicator_label3  "HA_Regression"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID

//--- Enum for Channel Calculation Mode ---
enum ENUM_CHANNEL_MODE
  {
   DEVIATION_STANDARD, // Channel width based on Standard Deviation
   DEVIATION_MAXIMUM   // Channel width based on Maximum Deviation
  };

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW, HA_PRICE_TYPICAL, HA_PRICE_MEDIAN
  };

//--- Input Parameters ---
input int                   InpRegressionPeriod = 100;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice     = HA_PRICE_CLOSE;
input ENUM_CHANNEL_MODE     InpChannelMode      = DEVIATION_STANDARD;
input double                InpDeviations       = 2.0;

//--- Indicator Buffers ---
double    BufferUpper[];
double    BufferLower[];
double    BufferMiddle[];

//--- Global Objects and Variables ---
int                       g_ExtPeriod;
double                    g_ExtDeviations;
datetime                  g_last_update_time;
CHeikinAshi_Calculator   *g_ha_calculator;

//--- Forward declarations ---
void CalculateChannel(int rates_total, const double &ha_open[], const double &ha_high[], const double &ha_low[], const double &ha_close[]);
double GetHAPrice(int index, ENUM_HA_APPLIED_PRICE type, const double &ha_open[], const double &ha_high[], const double &ha_low[], const double &ha_close[]);

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
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA LinReg Pro(%d)", g_ExtPeriod));

   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Linear Regression Channel on Heikin Ashi calculation function.   |
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

   if(time[rates_total - 1] > g_last_update_time)
     {
      ArrayInitialize(BufferUpper, EMPTY_VALUE);
      ArrayInitialize(BufferLower, EMPTY_VALUE);
      ArrayInitialize(BufferMiddle, EMPTY_VALUE);

      //--- Intermediate Heikin Ashi Buffers
      double ha_open[], ha_high[], ha_low[], ha_close[];
      ArrayResize(ha_open, rates_total);
      ArrayResize(ha_high, rates_total);
      ArrayResize(ha_low, rates_total);
      ArrayResize(ha_close, rates_total);

      //--- Calculate Heikin Ashi bars
      g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      //--- Calculate the channel using HA data
      CalculateChannel(rates_total, ha_open, ha_high, ha_low, ha_close);

      g_last_update_time = time[rates_total - 1];
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Main calculation logic moved to a helper function                |
//+------------------------------------------------------------------+
void CalculateChannel(int rates_total, const double &ha_open[], const double &ha_high[], const double &ha_low[], const double &ha_close[])
  {
   int start_index = rates_total - g_ExtPeriod;

//--- STEP 1: Calculate sums for the regression formula
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
   for(int i = 0; i < g_ExtPeriod; i++)
     {
      double y = GetHAPrice(start_index + i, InpAppliedPrice, ha_open, ha_high, ha_low, ha_close);
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
         double price = GetHAPrice(start_index + i, InpAppliedPrice, ha_open, ha_high, ha_low, ha_close);
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
         double price = GetHAPrice(start_index + i, InpAppliedPrice, ha_open, ha_high, ha_low, ha_close);
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
//| Helper function to get the correct Heikin Ashi price type        |
//+------------------------------------------------------------------+
double GetHAPrice(int index, ENUM_HA_APPLIED_PRICE type, const double &ha_open[], const double &ha_high[], const double &ha_low[], const double &ha_close[])
  {
   switch(type)
     {
      case HA_PRICE_OPEN:
         return ha_open[index];
      case HA_PRICE_HIGH:
         return ha_high[index];
      case HA_PRICE_LOW:
         return ha_low[index];
      case HA_PRICE_MEDIAN:
         return (ha_high[index] + ha_low[index]) / 2.0;
      case HA_PRICE_TYPICAL:
         return (ha_high[index] + ha_low[index] + ha_close[index]) / 3.0;
      default:
         return ha_close[index];
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
