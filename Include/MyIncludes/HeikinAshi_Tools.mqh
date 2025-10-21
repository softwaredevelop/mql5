//+------------------------------------------------------------------+
//|                                           HeikinAshi_Tools.mqh   |
//|                A toolkit for various Heikin Ashi calculations    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

//+==================================================================+
//|                                                                  |
//|             GLOBAL ENUM for Standard & Heikin Ashi Prices        |
//|                                                                  |
//+==================================================================+

// This enum provides a unified list for input parameters, allowing users
// to select from both standard and Heikin Ashi price sources.
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1,
   PRICE_HA_OPEN     = -2,
   PRICE_HA_HIGH     = -3,
   PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5,
   PRICE_HA_TYPICAL  = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE,
   PRICE_OPEN_STD    = PRICE_OPEN,
   PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW,
   PRICE_MEDIAN_STD  = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };


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
