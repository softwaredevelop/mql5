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
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
