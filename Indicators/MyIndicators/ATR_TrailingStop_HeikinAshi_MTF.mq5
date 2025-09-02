//+------------------------------------------------------------------+
//|                               ATR_TrailingStop_HeikinAshi_MTF.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Multi-Timeframe ATR Trailing Stop on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2 // Main line and color buffer
#property indicator_plots   1

//--- Plot 1: ATR Trailing Stop line
#property indicator_label1  "HA ATR Trailing Stop"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDodgerBlue, clrTomato
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input ENUM_TIMEFRAMES InpUpperTimeframe = PERIOD_H1; // Timeframe for calculation
input int             InpAtrPeriod      = 22;      // ATR Period
input double          InpMultiplier     = 3.0;     // ATR Multiplier

//--- Indicator Buffers ---
double    BufferStopLine[];
double    BufferColor[];

//+------------------------------------------------------------------+
//| CLASS: CATR_TrailingStop_HA_Calculator                           |
//| Encapsulates the entire MTF HA ATR Trailing Stop calculation.    |
//+------------------------------------------------------------------+
class CATR_TrailingStop_HA_Calculator
  {
private:
   string                 m_symbol;
   ENUM_TIMEFRAMES        m_timeframe;
   int                    m_atr_period;
   double                 m_multiplier;
   CHeikinAshi_Calculator m_ha_calculator; // HA calculator instance

   //--- Helper functions for finding highest/lowest values
   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CATR_TrailingStop_HA_Calculator(string symbol, ENUM_TIMEFRAMES timeframe, int period, double multiplier);
                    ~CATR_TrailingStop_HA_Calculator(void) {};

   //--- The main calculation method
   bool              Calculate(double &stop_line_out[], double &color_out[]);
  };

//+------------------------------------------------------------------+
//| CATR_TrailingStop_HA_Calculator: Constructor                     |
//+------------------------------------------------------------------+
CATR_TrailingStop_HA_Calculator::CATR_TrailingStop_HA_Calculator(string symbol, ENUM_TIMEFRAMES timeframe, int period, double multiplier) :
   m_symbol(symbol), m_timeframe(timeframe), m_atr_period(period), m_multiplier(multiplier)
  {
  }

//+------------------------------------------------------------------+
//| CATR_TrailingStop_HA_Calculator: Main Calculation Logic          |
//+------------------------------------------------------------------+
bool CATR_TrailingStop_HA_Calculator::Calculate(double &stop_line_out[], double &color_out[])
  {
//--- Step 1: Fetch all required standard OHLC data from the higher timeframe
   int htf_rates_total = Bars(m_symbol, m_timeframe);
   if(htf_rates_total <= m_atr_period)
     {
      Print("Not enough bars on ", EnumToString(m_timeframe));
      return false;
     }

   double htf_open[], htf_high[], htf_low[], htf_close[];
   if(CopyOpen(m_symbol, m_timeframe, 0, htf_rates_total, htf_open)   <= 0 ||
      CopyHigh(m_symbol, m_timeframe, 0, htf_rates_total, htf_high)  <= 0 ||
      CopyLow(m_symbol, m_timeframe, 0, htf_rates_total, htf_low)   <= 0 ||
      CopyClose(m_symbol, m_timeframe, 0, htf_rates_total, htf_close) <= 0)
     {
      Print("Error copying history data for ", EnumToString(m_timeframe));
      return false;
     }

   ArraySetAsSeries(htf_open, false);
   ArraySetAsSeries(htf_high, false);
   ArraySetAsSeries(htf_low, false);
   ArraySetAsSeries(htf_close, false);

//--- Step 2: Calculate Heikin Ashi candles from the fetched HTF data
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, htf_rates_total);
   ArrayResize(ha_high, htf_rates_total);
   ArrayResize(ha_low, htf_rates_total);
   ArrayResize(ha_close, htf_rates_total);

   m_ha_calculator.Calculate(htf_rates_total, htf_open, htf_high, htf_low, htf_close, ha_open, ha_high, ha_low, ha_close);

//--- Intermediate buffers for calculation
   double buffer_atr[], buffer_long_stop[], buffer_short_stop[], buffer_trend[];
   ArrayResize(buffer_atr, htf_rates_total);
   ArrayResize(buffer_long_stop, htf_rates_total);
   ArrayResize(buffer_short_stop, htf_rates_total);
   ArrayResize(buffer_trend, htf_rates_total);

   ArrayResize(stop_line_out, htf_rates_total);
   ArrayResize(color_out, htf_rates_total);

//--- STEP 3: Calculate True Range on HTF Heikin Ashi data
   double ha_tr[];
   ArrayResize(ha_tr, htf_rates_total);
   for(int i = 1; i < htf_rates_total; i++)
     {
      ha_tr[i] = MathMax(ha_high[i], ha_close[i-1]) - MathMin(ha_low[i], ha_close[i-1]);
     }

//--- STEP 4: Calculate ATR (Wilder's Smoothing) on HTF HA data
   for(int i = m_atr_period; i < htf_rates_total; i++)
     {
      if(i == m_atr_period) // Initialization
        {
         double atr_sum = 0;
         for(int j = 1; j <= m_atr_period; j++)
            atr_sum += ha_tr[j];
         buffer_atr[i] = atr_sum / m_atr_period;
        }
      else // Recursive calculation
        {
         buffer_atr[i] = (buffer_atr[i-1] * (m_atr_period - 1) + ha_tr[i]) / m_atr_period;
        }
     }

//--- STEP 5: Calculate Raw Stop Levels on HTF HA data
   for(int i = m_atr_period - 1; i < htf_rates_total; i++)
     {
      buffer_long_stop[i]  = Highest(ha_high, m_atr_period, i) - m_multiplier * buffer_atr[i];
      buffer_short_stop[i] = Lowest(ha_low, m_atr_period, i) + m_multiplier * buffer_atr[i];
     }

//--- STEP 6: Determine Trend and Final Stop Line on HTF HA data
   for(int i = m_atr_period; i < htf_rates_total; i++)
     {
      if(i == m_atr_period) // Initialization
        {
         buffer_trend[i] = (ha_close[i] > ha_close[i-1]) ? 1 : -1;
        }
      else
        {
         if(ha_close[i] > buffer_short_stop[i-1])
            buffer_trend[i] = 1;
         else
            if(ha_close[i] < buffer_long_stop[i-1])
               buffer_trend[i] = -1;
            else
               buffer_trend[i] = buffer_trend[i-1];
        }

      if(buffer_trend[i] == 1)
        {
         if(buffer_long_stop[i] > stop_line_out[i-1] || buffer_trend[i-1] == -1)
            stop_line_out[i] = buffer_long_stop[i];
         else
            stop_line_out[i] = stop_line_out[i-1];
         color_out[i] = 0;
        }
      else // Trend is -1
        {
         if(buffer_short_stop[i] < stop_line_out[i-1] || stop_line_out[i-1] == 0 || buffer_trend[i-1] == 1)
            stop_line_out[i] = buffer_short_stop[i];
         else
            stop_line_out[i] = stop_line_out[i-1];
         color_out[i] = 1;
        }

      if(buffer_trend[i] != buffer_trend[i-1])
        {
         if(buffer_trend[i] == 1)
            stop_line_out[i-1] = buffer_long_stop[i];
         else
            stop_line_out[i-1] = buffer_short_stop[i];
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Finds the highest value in a given period of an array.           |
//+------------------------------------------------------------------+
double CATR_TrailingStop_HA_Calculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res < array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Finds the lowest value in a given period of an array.            |
//+------------------------------------------------------------------+
double CATR_TrailingStop_HA_Calculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return(res);
  }

//--- Global calculator object ---
CATR_TrailingStop_HA_Calculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferStopLine, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor,    INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferStopLine, false);
   ArraySetAsSeries(BufferColor,    false);

   ENUM_TIMEFRAMES calc_tf = (InpUpperTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpUpperTimeframe;
   int atr_period = (InpAtrPeriod < 1) ? 1 : InpAtrPeriod;
   double multiplier = (InpMultiplier <= 0) ? 3.0 : InpMultiplier;

   g_calculator = new CATR_TrailingStop_HA_Calculator(_Symbol, calc_tf, atr_period, multiplier);
   if(CheckPointer(g_calculator) == POINTER_INVALID)
     {
      Print("Error creating calculator object");
      return(INIT_FAILED);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, atr_period);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA ATR Stop MTF(%s, %d, %.1f)", EnumToString(calc_tf), atr_period, multiplier));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| ATR Trailing Stop MTF on HA data calculation function.           |
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
   ENUM_TIMEFRAMES calc_tf = (InpUpperTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpUpperTimeframe;

   static datetime last_htf_bar_time = 0;
   datetime htf_time[];
   bool new_htf_bar = false;

   if(CopyTime(_Symbol, calc_tf, 0, 1, htf_time) > 0)
     {
      if(htf_time[0] > last_htf_bar_time)
        {
         last_htf_bar_time = htf_time[0];
         new_htf_bar = true;
        }
     }

   if(new_htf_bar || prev_calculated == 0)
     {
      if(CheckPointer(g_calculator) == POINTER_INVALID)
         return 0;

      double htf_stop_line[], htf_color[];
      if(!g_calculator.Calculate(htf_stop_line, htf_color))
         return 0;

      datetime htf_timeline[];
      int htf_rates_total = ArraySize(htf_stop_line);
      if(CopyTime(_Symbol, calc_tf, 0, htf_rates_total, htf_timeline) <= 0)
         return 0;

      ArraySetAsSeries(htf_timeline, false);

      int htf_idx = 0;
      for(int i = 0; i < rates_total; i++)
        {
         while(htf_idx < htf_rates_total - 1 && htf_timeline[htf_idx + 1] <= time[i])
           {
            htf_idx++;
           }

         if(htf_stop_line[htf_idx] != 0)
           {
            BufferStopLine[i] = htf_stop_line[htf_idx];
            BufferColor[i] = htf_color[htf_idx];
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
