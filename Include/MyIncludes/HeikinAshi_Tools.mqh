//+------------------------------------------------------------------+
//|                                           HeikinAshi_Tools.mqh   |
//|                A toolkit for various Heikin Ashi calculations    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//--- Unified Price Enum
enum ENUM_APPLIED_PRICE_HA_ALL
  {
   PRICE_HA_CLOSE    = -1,
   PRICE_HA_OPEN     = -2,
   PRICE_HA_HIGH     = -3,
   PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5,
   PRICE_HA_TYPICAL  = -6,
   PRICE_HA_WEIGHTED = -7,
   PRICE_CLOSE_STD   = PRICE_CLOSE,
   PRICE_OPEN_STD    = PRICE_OPEN,
   PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW,
   PRICE_MEDIAN_STD  = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//+------------------------------------------------------------------+
//| Class CHeikinAshi_Calculator                                     |
//| Purpose: Stateless calculation engine for Heikin Ashi candles.   |
//+------------------------------------------------------------------+
class CHeikinAshi_Calculator
  {
public:
   //--- STRICT INTERFACE: Always requires start_index for optimization.
   void              Calculate(const int rates_total,
                               const int start_index,
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
//| Implementation                                                   |
//+------------------------------------------------------------------+
void CHeikinAshi_Calculator::Calculate(const int rates_total,
                                       const int start_index,
                                       const double &open[],
                                       const double &high[],
                                       const double &low[],
                                       const double &close[],
                                       double &ha_open[],
                                       double &ha_high[],
                                       double &ha_low[],
                                       double &ha_close[])
  {
   if(rates_total < 2)
      return;

   int i = start_index;

//--- Initialization logic (only if starting from the very beginning)
   if(i == 0)
     {
      ha_open[0]  = (open[0] + close[0]) / 2.0;
      ha_close[0] = (open[0] + high[0] + low[0] + close[0]) / 4.0;
      ha_high[0]  = high[0];
      ha_low[0]   = low[0];
      i = 1;
     }

//--- Main Optimization Loop
//--- Calculates only from start_index to the end
   for(; i < rates_total; i++)
     {
      // HA Open relies on the PREVIOUS calculated HA candle (i-1)
      ha_open[i]  = (ha_open[i - 1] + ha_close[i - 1]) / 2.0;
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
     }
  }
//+------------------------------------------------------------------+
