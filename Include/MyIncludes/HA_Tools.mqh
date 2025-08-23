//+------------------------------------------------------------------+
//|                                                    HA_Tools.mqh  |
//|                       A toolkit for Heiken Ashi calculations     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

#include <Object.mqh>

//+------------------------------------------------------------------+
//| Class CHA_Calculator.                                            |
//| Purpose: Encapsulates the logic for calculating Heiken Ashi      |
//|          candle values from standard OHLC data. This class       |
//|          manages its own data buffers.                           |
//+------------------------------------------------------------------+
class CHA_Calculator : public CObject
  {
public:
   //--- Public Data Members ---
   // These buffers store the calculated Heiken Ashi values and are
   // publicly accessible for indicators to use in their calculations.
   double            ha_open[];
   double            ha_high[];
   double            ha_low[];
   double            ha_close[];

public:
   //--- Constructor and Destructor
                     CHA_Calculator(void);
                    ~CHA_Calculator(void);

   //--- Public Interface
   bool              Calculate(const int rates_total,
                               const int prev_calculated,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CHA_Calculator::CHA_Calculator(void)
  {
//--- No specific initialization required in the constructor
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CHA_Calculator::~CHA_Calculator(void)
  {
//--- No specific deinitialization required in the destructor
  }

//+------------------------------------------------------------------+
//| Calculates Heiken Ashi values for the entire history.            |
//| INPUT:  rates_total     - The total number of bars available.    |
//|         prev_calculated - The number of bars calculated previously.|
//|         open[], high[], low[], close[] - Standard price arrays.  |
//| RETURN: true if calculation was successful, false otherwise.     |
//+------------------------------------------------------------------+
bool CHA_Calculator::Calculate(const int rates_total,
                               const int prev_calculated,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[])
  {
//--- Ensure internal buffers are sized correctly
   if(ArrayResize(ha_open, rates_total) < 0 ||
      ArrayResize(ha_high, rates_total) < 0 ||
      ArrayResize(ha_low, rates_total) < 0 ||
      ArrayResize(ha_close, rates_total) < 0)
     {
      Print("CHA_Calculator: Error resizing Heiken Ashi buffers!");
      return false;
     }

//--- Determine the starting bar for calculation to optimize performance
   int start_pos = 0;
   if(prev_calculated > 1)
     {
      // On subsequent calls, only calculate new bars
      start_pos = prev_calculated - 1;
     }

//--- Calculate the very first HA bar (index 0) on the first run
   if(start_pos == 0)
     {
      ha_open[0]  = (open[0] + close[0]) / 2.0;
      ha_close[0] = (open[0] + high[0] + low[0] + close[0]) / 4.0;
      // For the first bar, HA High/Low are the same as the regular High/Low
      ha_high[0]  = high[0];
      ha_low[0]   = low[0];
      start_pos = 1; // Set the starting position for the main loop to the next bar
     }

//--- Main loop to calculate all subsequent HA bars
   for(int i = start_pos; i < rates_total; i++)
     {
      // HA Open is the midpoint of the previous HA bar's body
      ha_open[i]  = (ha_open[i-1] + ha_close[i-1]) / 2.0;
      // HA Close is the average price of the current regular bar
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      // HA High is the maximum of the current regular High, HA Open, and HA Close
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      // HA Low is the minimum of the current regular Low, HA Open, and HA Close
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
     }

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
