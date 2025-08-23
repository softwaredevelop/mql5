//+------------------------------------------------------------------+
//|                                           HeikinAshi_Tools.mqh   |
//|                A toolkit for various Heikin Ashi calculations    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CHeikinAshi_Calculator                      |
//|                                                                  |
//+==================================================================+

//+------------------------------------------------------------------+
//| Class CHeikinAshi_Calculator.                                    |
//| Purpose: Encapsulates the logic for calculating Heikin Ashi      |
//|          candle values from standard OHLC data. This class is    |
//|          stateless and operates on external buffers.             |
//+------------------------------------------------------------------+
class CHeikinAshi_Calculator
  {
public:
   //--- Public Interface
   void              Calculate(const int rates_total,
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  double &ha_open[],
                  double &ha_high[],
                  double &ha_low[],
                  double &ha_close[]);
  };

//+------------------------------------------------------------------+
//| Calculates Heikin Ashi values for the entire history.            |
//+------------------------------------------------------------------+
void CHeikinAshi_Calculator::Calculate(const int rates_total,
                                       const double &open[],
                                       const double &high[],
                                       const double &low[],
                                       const double &close[],
                                       double &ha_open[],
                                       double &ha_high[],
                                       double &ha_low[],
                                       double &ha_close[])
  {
   if(rates_total < 1)
      return;

   ha_open[0]  = (open[0] + close[0]) / 2.0;
   ha_close[0] = (open[0] + high[0] + low[0] + close[0]) / 4.0;
   ha_high[0]  = high[0];
   ha_low[0]   = low[0];

   for(int i = 1; i < rates_total; i++)
     {
      ha_open[i]  = (ha_open[i - 1] + ha_close[i - 1]) / 2.0;
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
     }
  }


//+==================================================================+
//|                                                                  |
//|             CLASS 2: CHeikinAshi_RSI_Calculator                  |
//|                                                                  |
//+==================================================================+

//+------------------------------------------------------------------+
//| Class CHeikinAshi_RSI_Calculator                                 |
//| Purpose: Calculates RSI based on Heikin Ashi data.               |
//+------------------------------------------------------------------+
class CHeikinAshi_RSI_Calculator
  {
protected:
   CHeikinAshi_Calculator m_ha_calculator; // Internal HA calculator

public:
   bool              Calculate(const int rates_total,
                  const int rsi_period,
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  double &rsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Calculates Heikin Ashi based RSI                                 |
//+------------------------------------------------------------------+
bool CHeikinAshi_RSI_Calculator::Calculate(const int rates_total,
      const int rsi_period,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      double &rsi_buffer[])
  {
   if(rates_total <= rsi_period)
      return false;

//--- Intermediate buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Step 1: Calculate Heikin Ashi
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Step 2: Calculate RSI on HA Close
   double pos_buffer[], neg_buffer[];
   ArrayResize(pos_buffer, rates_total);
   ArrayResize(neg_buffer, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      double diff = ha_close[i] - ha_close[i-1];
      double positive_change = (diff > 0) ? diff : 0;
      double negative_change = (diff < 0) ? -diff : 0;

      if(i == rsi_period)
        {
         double sum_pos=0, sum_neg=0;
         for(int j=1; j<=rsi_period; j++)
           {
            double p_diff = ha_close[j] - ha_close[j-1];
            sum_pos += (p_diff > 0) ? p_diff : 0;
            sum_neg += (p_diff < 0) ? -p_diff : 0;
           }
         pos_buffer[i] = sum_pos / rsi_period;
         neg_buffer[i] = sum_neg / rsi_period;
        }
      else
         if(i > rsi_period)
           {
            pos_buffer[i] = (pos_buffer[i-1] * (rsi_period - 1) + positive_change) / rsi_period;
            neg_buffer[i] = (neg_buffer[i-1] * (rsi_period - 1) + negative_change) / rsi_period;
           }

      if(i >= rsi_period)
        {
         if(neg_buffer[i] > 0)
           {
            double rs = pos_buffer[i] / neg_buffer[i];
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            rsi_buffer[i] = 100.0;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
