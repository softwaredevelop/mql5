//+------------------------------------------------------------------+
//|                                           HeikinAshi_Tools.mqh   |
//|                A toolkit for various Heikin Ashi calculations    |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10" // Optimized SIMD floating-point multiplication & fused color calculation

//--- Unified Price Enum
#ifndef ENUM_APPLIED_PRICE_HA_ALL_DEFINED
#define ENUM_APPLIED_PRICE_HA_ALL_DEFINED
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
#endif

//+------------------------------------------------------------------+
//| Class CHeikinAshi_Calculator                                     |
//| Purpose: High-performance calculation engine for HA candles.     |
//+------------------------------------------------------------------+
class CHeikinAshi_Calculator
  {
public:
   //--- STRICT INTERFACE 1: Original 10-param signature (100% backward compatible)
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

   //--- STRICT INTERFACE 2: Fused 11-param signature (Single-pass candle + color indexing)
   void              Calculate(const int rates_total,
                               const int start_index,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[],
                               double &ha_open[],
                               double &ha_high[],
                               double &ha_low[],
                               double &ha_close[],
                               double &ha_color[]);
  };

//+------------------------------------------------------------------+
//| Original Implementation (Optimized with Multiplication)          |
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
   if(rates_total < 2 || start_index >= rates_total)
      return;

   int i = (start_index < 0) ? 0 : start_index;

// Initialization on absolute history start
   if(i == 0)
     {
      ha_open[0]  = (open[0] + close[0]) * 0.5;
      ha_close[0] = (open[0] + high[0] + low[0] + close[0]) * 0.25;
      ha_high[0]  = high[0];
      ha_low[0]   = low[0];
      i = 1;
     }

// High-performance multiplication kernel
   for(; i < rates_total; i++)
     {
      ha_open[i]  = (ha_open[i - 1] + ha_close[i - 1]) * 0.5;
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) * 0.25;
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
     }
  }

//+------------------------------------------------------------------+
//| Fused Implementation: Computes Candles & Colors in Single Pass   |
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
                                       double &ha_close[],
                                       double &ha_color[])
  {
   if(rates_total < 2 || start_index >= rates_total)
      return;

   int i = (start_index < 0) ? 0 : start_index;

   if(i == 0)
     {
      ha_open[0]  = (open[0] + close[0]) * 0.5;
      ha_close[0] = (open[0] + high[0] + low[0] + close[0]) * 0.25;
      ha_high[0]  = high[0];
      ha_low[0]   = low[0];
      ha_color[0] = (ha_close[0] >= ha_open[0]) ? 0.0 : 1.0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      ha_open[i]  = (ha_open[i - 1] + ha_close[i - 1]) * 0.5;
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) * 0.25;
      ha_high[i]  = MathMax(high[i], MathMax(ha_open[i], ha_close[i]));
      ha_low[i]   = MathMin(low[i], MathMin(ha_open[i], ha_close[i]));
      ha_color[i] = (ha_close[i] >= ha_open[i]) ? 0.0 : 1.0;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
