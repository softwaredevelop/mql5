//+------------------------------------------------------------------+
//|                                       HeikinAshiCalculator.mqh   |
//|                  A toolkit for Heikin Ashi calculations          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

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
//| This method performs a full recalculation for maximum stability. |
//| INPUT:  rates_total - The total number of bars available.        |
//|         open[], high[], low[], close[] - Standard price arrays.  |
//| OUTPUT: ha_open[], ha_high[], ha_low[], ha_close[] - Result arrays.|
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
//--- Not enough data for calculation
   if(rates_total < 1)
      return;

//--- Calculate the very first Heikin Ashi bar (index 0)
   ha_open[0]  = (open[0] + close[0]) / 2.0;
   ha_close[0] = (open[0] + high[0] + low[0] + close[0]) / 4.0;
// For the first bar, HA High/Low are the same as the regular High/Low
   ha_high[0]  = high[0];
   ha_low[0]   = low[0];

//--- Main loop to calculate all subsequent Heikin Ashi bars
   for(int i = 1; i < rates_total; i++)
     {
      // HA Open is the midpoint of the previous HA bar's body
      ha_open[i]  = (ha_open[i - 1] + ha_close[i - 1]) / 2.0;
      // HA Close is the average price of the current regular bar
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      // HA High is the maximum of the current regular High, HA Open, and HA Close
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      // HA Low is the minimum of the current regular Low, HA Open, and HA Close
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
