//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|      VERSION 2.45: Added VWMA support with empty-value fallback. |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.45"

#ifndef MOVING_AVERAGE_ENGINE_MQH
#define MOVING_AVERAGE_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum to select the MA type for calculation
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

//+==================================================================+
//|             CLASS: CMovingAverageCalculator                      |
//+==================================================================+
class CMovingAverageCalculator
  {
protected:
   int               m_period;
   ENUM_MA_TYPE      m_ma_type;

   //--- Persistent Buffers
   double            m_price[];
   double            m_volume[]; // Kept for VWMA support
   double            m_temp_buffer1[];
   double            m_temp_buffer2[];
   double            m_temp_buffer3[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateEMA(int rates_total, int start_index, int period, const double &source[], double &dest[]);

   //--- Internal Core Calculation that works on m_price and m_volume
   //--- data_offset: The index where valid data starts in m_price
   void              RunCalculation(int rates_total, int start_index, double &output_buffer[], int data_offset = 0);

public:
                     CMovingAverageCalculator(void) {};
   virtual          ~CMovingAverageCalculator(void) {};

   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Standard Calculation (OHLC input - No Volume, legacy/fallback compatible)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[]);

   //--- Overloaded Calculation with Volume (Specifically for VWMA support)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], double &ma_buffer[]);

   //--- Calculation on Custom Array (No Volume)
   //--- src_start_index: The index where valid data starts in src_buffer (default 0)
   void              CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &output_buffer[], int src_start_index = 0);

   //--- Overloaded Calculation on Custom Array with Volume
   void              CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], const double &volume_buffer[], double &output_buffer[], int src_start_index = 0);

   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = (period < 1) ? 1 : period;
   m_ma_type = ma_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard OHLC - No Volume)                           |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      // Resize temp buffers if needed
      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer1, rates_total);
      if(m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer2, rates_total);
      if(m_ma_type == TEMA)
         ArrayResize(m_temp_buffer3, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Standard OHLC data is valid from index 0
   RunCalculation(rates_total, start_index, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded OHLC - With Volume)                       |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], double &ma_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer1, rates_total);
      if(m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer2, rates_total);
      if(m_ma_type == TEMA)
         ArrayResize(m_temp_buffer3, rates_total);
     }

// Dynamic allocation check for volume buffer (Crucial for parameter switches)
   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Copy volumes locally with casting
   for(int i = start_index; i < rates_total; i++)
     {
      m_volume[i] = (double)volume[i];
     }

   RunCalculation(rates_total, start_index, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Custom Input - No Volume)                      |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &output_buffer[], int src_start_index)
  {
   if(rates_total < src_start_index + m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer1, rates_total);
      if(m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer2, rates_total);
      if(m_ma_type == TEMA)
         ArrayResize(m_temp_buffer3, rates_total);
     }

// Copy source array to internal m_price buffer
   int copy_start = MathMax(start_index, src_start_index);

   for(int i = copy_start; i < rates_total; i++)
      m_price[i] = src_buffer[i];

   RunCalculation(rates_total, start_index, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Overloaded Custom Input - With Volume)         |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], const double &volume_buffer[], double &output_buffer[], int src_start_index)
  {
   if(rates_total < src_start_index + m_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer1, rates_total);
      if(m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer2, rates_total);
      if(m_ma_type == TEMA)
         ArrayResize(m_temp_buffer3, rates_total);
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
     }

// Copy source array and volume to internal buffers
   int copy_start = MathMax(start_index, src_start_index);

   for(int i = copy_start; i < rates_total; i++)
     {
      m_price[i] = src_buffer[i];
      m_volume[i] = volume_buffer[i];
     }

   RunCalculation(rates_total, start_index, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| RunCalculation (Core Logic)                                      |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::RunCalculation(int rates_total, int start_index, double &output_buffer[], int data_offset)
  {
// The first valid MA value can be calculated at (offset + period - 1)
   int start_pos = data_offset + m_period - 1;

// Ensure loop starts at valid position
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
               double sum=0;
               for(int j=0; j<m_period; j++)
                  sum+=m_price[i-j];
               output_buffer[i]=sum/m_period;
              }
            else
               // Recursive SMMA relies on valid previous value [i-1]
               output_buffer[i]=(output_buffer[i-1]*(m_period-1)+m_price[i])/m_period;
           }
         break;

      case LWMA:
         for(int i = loop_start; i < rates_total; i++)
           {
            double sum=0, w_sum=0;
            for(int j=0; j<m_period; j++)
              {
               int w=m_period-j;
               sum+=m_price[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               output_buffer[i]=sum/w_sum;
           }
         break;

      case TMA:
        {
         int period1 = (int)ceil((m_period + 1.0) / 2.0);
         // TMA logic is complex with offsets.
         // First MA starts at: data_offset + period1 - 1
         int start_pos1 = data_offset + period1 - 1;
         int loop_start_tma = MathMax(start_pos1, start_index);

         for(int i = loop_start_tma; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period1; j++)
               sum += m_price[i-j];
            m_temp_buffer1[i] = sum / period1;
           }

         // Second MA starts at: start_pos1 + period2 - 1
         int period2 = m_period - period1 + 1;
         int start_pos2 = start_pos1 + period2 - 1;
         int loop_start_final = MathMax(start_pos2, start_index);

         for(int i = loop_start_final; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period2; j++)
               sum += m_temp_buffer1[i-j];
            output_buffer[i] = sum / period2;
           }
        }
      break;

      case DEMA:
         CalculateEMA(rates_total, loop_start, m_period, m_price, m_temp_buffer1);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer1, m_temp_buffer2);

         for(int i = loop_start; i < rates_total; i++)
            output_buffer[i] = 2 * m_temp_buffer1[i] - m_temp_buffer2[i];
         break;

      case TEMA:
         CalculateEMA(rates_total, loop_start, m_period, m_price, m_temp_buffer1);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer1, m_temp_buffer2);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer2, m_temp_buffer3);

         for(int i = loop_start; i < rates_total; i++)
            output_buffer[i] = 3 * m_temp_buffer1[i] - 3 * m_temp_buffer2[i] + m_temp_buffer3[i];
         break;

      case VWMA:
        {
         // Robust empty-value fallback pattern
         if(ArraySize(m_volume) != rates_total)
           {
            if(start_index == 0)
               Print("Warning: VWMA selected but no volume data provided. Line will not be drawn.");

            for(int i = loop_start; i < rates_total; i++)
              {
               output_buffer[i] = EMPTY_VALUE;
              }
           }
         else
           {
            for(int i = loop_start; i < rates_total; i++)
              {
               double sum_pv = 0;
               double sum_v = 0;
               for(int j = 0; j < m_period; j++)
                 {
                  double v = m_volume[i-j];
                  sum_pv += m_price[i-j] * v;
                  sum_v  += v;
                 }
               output_buffer[i] = (sum_v > 0) ? (sum_pv / sum_v) : m_price[i];
              }
           }
        }
      break;

      default: // SMA
         for(int i = loop_start; i < rates_total; i++)
           {
            double sum=0;
            for(int j=0; j<m_period; j++)
               sum+=m_price[i-j];
            output_buffer[i]=sum/m_period;
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//| Calculate EMA (Optimized)                                        |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateEMA(int rates_total, int start_index, int period, const double &source[], double &dest[])
  {
   if(rates_total < period)
      return;

   double pr = 2.0 / (double)(period + 1.0);

// FIX: If starting from 0, force initialization logic regardless of array content
   bool force_init = (start_index == 0);

   for(int i = start_index; i < rates_total; i++)
     {
      // Check if we have a valid previous value to recurse on
      // We only check dest[i-1] if we are NOT forcing initialization
      bool has_prev = (!force_init && i > 0 && dest[i-1] != 0.0 && dest[i-1] != EMPTY_VALUE);

      if(has_prev)
        {
         if(source[i] != EMPTY_VALUE)
            dest[i] = source[i]*pr + dest[i-1]*(1.0-pr);
         else
            dest[i] = dest[i-1];
        }
      else
        {
         // Initialization (SMA)
         // Safety check: can we look back 'period' bars?
         if(i < period - 1)
           {
            dest[i] = EMPTY_VALUE; // Not enough data yet
            continue;
           }

         double sum=0;
         int count=0;
         for(int j=0; j<period; j++)
           {
            if(source[i-j]!=EMPTY_VALUE)
              {
               sum+=source[i-j];
               count++;
              }
           }
         if(count > 0)
            dest[i] = sum/count;
         else
            dest[i] = source[i]; // Fallback
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CMovingAverageCalculator_HA                 |
//+==================================================================+
class CMovingAverageCalculator_HA : public CMovingAverageCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
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

#endif // MOVING_AVERAGE_ENGINE_MQH
//+------------------------------------------------------------------+
