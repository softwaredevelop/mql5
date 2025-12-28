//+------------------------------------------------------------------+
//|                                           CutlerRSI_Calculator.mqh|
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CCutlerRSICalculator (Base Class)             |
//+==================================================================+
class CCutlerRSICalculator
  {
protected:
   int               m_rsi_period;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_rsi_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCutlerRSICalculator(void) {};
   virtual          ~CCutlerRSICalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &signal_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator::Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;

// Initialize Signal Engine
   if(!m_signal_engine.Init(ma_p, ma_m))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CCutlerRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                     double &rsi_out[], double &signal_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_buffer, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Cutler's RSI (Incremental)
// Cutler's RSI uses SMA of gains/losses.
// We can use a sliding window sum for O(1) calculation, but standard loop is safer for now.
// Optimization: Only calculate for new bars.

   int loop_start = MathMax(m_rsi_period, start_index);

// If full recalc, we need to handle the first value specially or just loop
   if(prev_calculated == 0)
     {
      // Initialize first few values to 0 or EMPTY
      for(int i=0; i<m_rsi_period; i++)
         m_rsi_buffer[i] = 0;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_pos = 0;
      double sum_neg = 0;

      // Sum over the lookback period
      for(int j = 0; j < m_rsi_period; j++)
        {
         // We need price changes: price[k] - price[k-1]
         // The window ends at i. So we look at changes from i down to i-period+1.
         // The change at index k is price[k] - price[k-1].

         int k = i - j;
         if(k < 1)
            continue; // Safety check

         double diff = m_price[k] - m_price[k-1];
         if(diff > 0)
            sum_pos += diff;
         else
            sum_neg += -diff;
        }

      if(sum_pos + sum_neg > 0)
        {
         // RS = AvgGain / AvgLoss = (SumPos/N) / (SumNeg/N) = SumPos / SumNeg
         // RSI = 100 - 100 / (1 + RS)
         double rs = sum_pos / sum_neg;
         m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + rs));
        }
      else
        {
         m_rsi_buffer[i] = 50.0; // Or 100/0 depending on definition, 50 is neutral
        }
     }

//--- 5. Calculate Signal Line (Using Engine)
// RSI is valid from index: m_rsi_period
   int rsi_offset = m_rsi_period;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, signal_out, rsi_offset);

//--- 6. Copy RSI to Output
   ArrayCopy(rsi_out, m_rsi_buffer, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CCutlerRSICalculator_HA (Heikin Ashi)       |
//+==================================================================+
class CCutlerRSICalculator_HA : public CCutlerRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
