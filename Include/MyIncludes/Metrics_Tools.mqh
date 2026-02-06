//+------------------------------------------------------------------+
//|                                            Metrics_Tools.mqh     |
//|      Utility for Slope, Distance, and Cost calculations.         |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMetricsTools
  {
public:
   //--- Calculate Normalized Slope (Change per bar in ATR units)
   // lookback: How many bars back to compare (e.g., 3 or 5)
   static double     CalculateSlope(double current_val, double prev_val, double atr, int lookback_bars)
     {
      if(atr == 0 || lookback_bars == 0)
         return 0.0;
      double change = current_val - prev_val;
      // Slope = Change / (Bars * ATR) -> Normalized speed
      return change / (atr * lookback_bars); // Result approx -1.0 to +1.0 usually
     }

   //--- Calculate Spread Cost (Spread in ATR units)
   static double     CalculateSpreadCost(string symbol, double atr)
     {
      if(atr == 0)
         return 0.0;

      long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double spread_value = spread_points * point;

      return spread_value / atr;
     }

   //--- Calculate Distance from Level (in ATR units)
   static double     CalculateDistance(double price, double level, double atr)
     {
      if(atr == 0)
         return 0.0;
      return (price - level) / atr;
     }
  };
//+------------------------------------------------------------------+
