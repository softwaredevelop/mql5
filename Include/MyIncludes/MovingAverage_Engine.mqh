//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|      VERSION 2.50: Enhanced Chronological Safeguards & VWMA      |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.50" // 100% Backward Compatible Universal Moving Average Engine

#ifndef MOVING_AVERAGE_ENGINE_MQH
#define MOVING_AVERAGE_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum to select the MA type for calculation
#ifndef ENUM_MA_TYPE_DEFINED
#define ENUM_MA_TYPE_DEFINED
enum ENUM_MA_TYPE
  {
   SMA,
   EMA,
   SMMA,
   LWMA,
   TMA,
   DEMA,
   TEMA,
   VWMA
  };
#endif

//+==================================================================+
//|             CLASS: CMovingAverageCalculator                      |
//+==================================================================+
class CMovingAverageCalculator
  {
protected:
   int               m_period;
   ENUM_MA_TYPE      m_ma_type;

   //--- Persistent State Buffers
   double            m_price[];
   double            m_volume[];
   double            m_temp_buffer1[];
   double            m_temp_buffer2[];
   double            m_temp_buffer3[];

   virtual bool      PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateEMA(const int rates_total, const int start_index, const int period, const double &source[], double &dest[]);
   void              RunCalculation(const int rates_total, const int start_index, double &output_buffer[], const int data_offset = 0);

public:
                     CMovingAverageCalculator(void);
   virtual          ~CMovingAverageCalculator(void) {};

   bool              Init(const int period, const ENUM_MA_TYPE ma_type);

   //--- Standard Calculation (OHLC input - No Volume, legacy compatible)
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_buffer[]);

   //--- Overloaded Calculation with Volume (Specifically for VWMA support)
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &ma_buffer[]);

   //--- Overloaded Calculation with Double Volume Array (For MTF VWMA)
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const double &volume[],
                               double &ma_buffer[]);

   //--- Calculation on Custom Array (No Volume)
   void              CalculateOnArray(const int rates_total, const int prev_calculated, const double &src_buffer[],
                                      double &output_buffer[], const int src_start_index = 0);

   //--- Overloaded Calculation on Custom Array with Volume (For VWMA Signals)
   void              CalculateOnArray(const int rates_total, const int prev_calculated, const double &src_buffer[],
                                      const double &volume_buffer[], double &output_buffer[], const int src_start_index = 0);

   int               GetPeriod(void) const { return m_period; }
   ENUM_MA_TYPE      GetMAType(void) const { return m_ma_type; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMovingAverageCalculator::CMovingAverageCalculator(void) : m_period(20), m_ma_type(SMA)
  {
   ArraySetAsSeries(m_price,        false);
   ArraySetAsSeries(m_volume,       false);
   ArraySetAsSeries(m_temp_buffer1, false);
   ArraySetAsSeries(m_temp_buffer2, false);
   ArraySetAsSeries(m_temp_buffer3, false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::Init(const int period, const ENUM_MA_TYPE ma_type)
  {
   m_period  = (period < 1) ? 1 : period;
   m_ma_type = ma_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard OHLC - No Volume)                           |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer1, rates_total);
         ArraySetAsSeries(m_temp_buffer1, false);
        }
      if(m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer2, rates_total);
         ArraySetAsSeries(m_temp_buffer2, false);
        }
      if(m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer3, rates_total);
         ArraySetAsSeries(m_temp_buffer3, false);
        }
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   RunCalculation(rates_total, start_index, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded OHLC - With Long Volume)                   |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer1, rates_total);
         ArraySetAsSeries(m_temp_buffer1, false);
        }
      if(m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer2, rates_total);
         ArraySetAsSeries(m_temp_buffer2, false);
        }
      if(m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer3, rates_total);
         ArraySetAsSeries(m_temp_buffer3, false);
        }
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
      ArraySetAsSeries(m_volume, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (volume[i] < 1) ? 1.0 : (double)volume[i];

   RunCalculation(rates_total, start_index, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded OHLC - With Double Volume)                 |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const double &volume[],
      double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer1, rates_total);
         ArraySetAsSeries(m_temp_buffer1, false);
        }
      if(m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer2, rates_total);
         ArraySetAsSeries(m_temp_buffer2, false);
        }
      if(m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer3, rates_total);
         ArraySetAsSeries(m_temp_buffer3, false);
        }
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
      ArraySetAsSeries(m_volume, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (volume[i] < 1.0) ? 1.0 : volume[i];

   RunCalculation(rates_total, start_index, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Custom Input - No Volume)                      |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(const int rates_total, const int prev_calculated, const double &src_buffer[],
      double &output_buffer[], const int src_start_index)
  {
   if(rates_total < src_start_index + m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer1, rates_total);
         ArraySetAsSeries(m_temp_buffer1, false);
        }
      if(m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer2, rates_total);
         ArraySetAsSeries(m_temp_buffer2, false);
        }
      if(m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer3, rates_total);
         ArraySetAsSeries(m_temp_buffer3, false);
        }
     }

   int copy_start = MathMax(start_index, src_start_index);

   for(int i = copy_start; i < rates_total; i++)
      m_price[i] = src_buffer[i];

   RunCalculation(rates_total, start_index, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Overloaded Custom Input - With Volume)         |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(const int rates_total, const int prev_calculated, const double &src_buffer[],
      const double &volume_buffer[], double &output_buffer[], const int src_start_index)
  {
   if(rates_total < src_start_index + m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer1, rates_total);
         ArraySetAsSeries(m_temp_buffer1, false);
        }
      if(m_ma_type == DEMA || m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer2, rates_total);
         ArraySetAsSeries(m_temp_buffer2, false);
        }
      if(m_ma_type == TEMA)
        {
         ArrayResize(m_temp_buffer3, rates_total);
         ArraySetAsSeries(m_temp_buffer3, false);
        }
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
      ArraySetAsSeries(m_volume, false);
     }

   int copy_start = MathMax(start_index, src_start_index);

   for(int i = copy_start; i < rates_total; i++)
     {
      m_price[i]  = src_buffer[i];
      m_volume[i] = (volume_buffer[i] < 1.0) ? 1.0 : volume_buffer[i];
     }

   RunCalculation(rates_total, start_index, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| RunCalculation (Core Mathematical Execution Engine)              |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::RunCalculation(const int rates_total, const int start_index, double &output_buffer[], const int data_offset)
  {
   int start_pos  = data_offset + m_period - 1;
   int loop_start = MathMax(start_pos, start_index);

   switch(m_ma_type)
     {
      case EMA:
         CalculateEMA(rates_total, loop_start, m_period, m_price, output_buffer);
         break;

      case SMMA:
         for(int i = loop_start; i < rates_total; i++)
           {
            if(i == start_pos)
              {
               double sum = 0.0;
               for(int j = 0; j < m_period; j++)
                  sum += m_price[i - j];
               output_buffer[i] = sum / (double)m_period;
              }
            else
              {
               output_buffer[i] = (output_buffer[i - 1] * (double)(m_period - 1) + m_price[i]) / (double)m_period;
              }
           }
         break;

      case LWMA:
         for(int i = loop_start; i < rates_total; i++)
           {
            double sum = 0.0, w_sum = 0.0;
            for(int j = 0; j < m_period; j++)
              {
               double w = (double)(m_period - j);
               sum += m_price[i - j] * w;
               w_sum += w;
              }
            output_buffer[i] = (w_sum > 0.0) ? (sum / w_sum) : m_price[i];
           }
         break;

      case TMA:
        {
         int period1 = (int)ceil((m_period + 1.0) / 2.0);
         int start_pos1 = data_offset + period1 - 1;
         int loop_start_tma = MathMax(start_pos1, start_index);

         for(int i = loop_start_tma; i < rates_total; i++)
           {
            double sum = 0.0;
            for(int j = 0; j < period1; j++)
               sum += m_price[i - j];
            m_temp_buffer1[i] = sum / (double)period1;
           }

         int period2 = m_period - period1 + 1;
         int start_pos2 = start_pos1 + period2 - 1;
         int loop_start_final = MathMax(start_pos2, start_index);

         for(int i = loop_start_final; i < rates_total; i++)
           {
            double sum = 0.0;
            for(int j = 0; j < period2; j++)
               sum += m_temp_buffer1[i - j];
            output_buffer[i] = sum / (double)period2;
           }
         break;
        }

      case DEMA:
         CalculateEMA(rates_total, loop_start, m_period, m_price, m_temp_buffer1);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer1, m_temp_buffer2);

         for(int i = loop_start; i < rates_total; i++)
           {
            if(m_temp_buffer1[i] != EMPTY_VALUE && m_temp_buffer2[i] != EMPTY_VALUE)
               output_buffer[i] = 2.0 * m_temp_buffer1[i] - m_temp_buffer2[i];
            else
               output_buffer[i] = EMPTY_VALUE;
           }
         break;

      case TEMA:
         CalculateEMA(rates_total, loop_start, m_period, m_price, m_temp_buffer1);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer1, m_temp_buffer2);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer2, m_temp_buffer3);

         for(int i = loop_start; i < rates_total; i++)
           {
            if(m_temp_buffer1[i] != EMPTY_VALUE && m_temp_buffer2[i] != EMPTY_VALUE && m_temp_buffer3[i] != EMPTY_VALUE)
               output_buffer[i] = 3.0 * m_temp_buffer1[i] - 3.0 * m_temp_buffer2[i] + m_temp_buffer3[i];
            else
               output_buffer[i] = EMPTY_VALUE;
           }
         break;

      case VWMA:
        {
         if(ArraySize(m_volume) != rates_total)
           {
            for(int i = loop_start; i < rates_total; i++)
               output_buffer[i] = EMPTY_VALUE;
           }
         else
           {
            for(int i = loop_start; i < rates_total; i++)
              {
               double sum_pv = 0.0;
               double sum_v  = 0.0;
               for(int j = 0; j < m_period; j++)
                 {
                  double v = m_volume[i - j];
                  sum_pv += m_price[i - j] * v;
                  sum_v  += v;
                 }
               output_buffer[i] = (sum_v > 0.0) ? (sum_pv / sum_v) : m_price[i];
              }
           }
         break;
        }

      default: // SMA
         for(int i = loop_start; i < rates_total; i++)
           {
            double sum = 0.0;
            for(int j = 0; j < m_period; j++)
               sum += m_price[i - j];
            output_buffer[i] = sum / (double)m_period;
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//| Calculate EMA (Optimized)                                        |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateEMA(const int rates_total, const int start_index, const int period, const double &source[], double &dest[])
  {
   if(rates_total < period)
      return;

   double pr = 2.0 / (double)(period + 1.0);
   bool force_init = (start_index == 0);

   for(int i = start_index; i < rates_total; i++)
     {
      bool has_prev = (!force_init && i > 0 && dest[i - 1] != 0.0 && dest[i - 1] != EMPTY_VALUE);

      if(has_prev)
        {
         if(source[i] != EMPTY_VALUE)
            dest[i] = source[i] * pr + dest[i - 1] * (1.0 - pr);
         else
            dest[i] = dest[i - 1];
        }
      else
        {
         if(i < period - 1)
           {
            dest[i] = EMPTY_VALUE;
            continue;
           }

         double sum = 0.0;
         int count = 0;
         for(int j = 0; j < period; j++)
           {
            if(source[i - j] != EMPTY_VALUE)
              {
               sum += source[i - j];
               count++;
              }
           }
         dest[i] = (count > 0) ? (sum / (double)count) : source[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CMovingAverageCalculator_HA                 |
//+==================================================================+
class CMovingAverageCalculator_HA : public CMovingAverageCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArraySetAsSeries(m_ha_open,  false);
      ArrayResize(m_ha_high,  rates_total);
      ArraySetAsSeries(m_ha_high,  false);
      ArrayResize(m_ha_low,   rates_total);
      ArraySetAsSeries(m_ha_low,   false);
      ArrayResize(m_ha_close, rates_total);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // MOVING_AVERAGE_ENGINE_MQH
//+------------------------------------------------------------------+
