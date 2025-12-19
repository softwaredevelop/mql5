//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|      VERSION 2.10: Fixed CalculateOnArray offset logic.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

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
   TEMA
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
   double            m_temp_buffer1[];
   double            m_temp_buffer2[];
   double            m_temp_buffer3[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateEMA(int rates_total, int start_index, int period, const double &source[], double &dest[]);

   //--- Internal Core Calculation that works on m_price
   //--- data_offset: The index where valid data starts in m_price
   void              RunCalculation(int rates_total, int start_index, double &output_buffer[], int data_offset = 0);

public:
                     CMovingAverageCalculator(void) {};
   virtual          ~CMovingAverageCalculator(void) {};

   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Standard Calculation (OHLC input)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[]);

   //--- Calculation on Custom Array (e.g. for smoothing other indicators)
   //--- src_start_index: The index where valid data starts in src_buffer (default 0)
   void              CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &output_buffer[], int src_start_index = 0);

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
//| Calculate (Standard OHLC)                                        |
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
//| CalculateOnArray (Custom Input)                                  |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &output_buffer[], int src_start_index = 0)
  {
// We need at least (offset + period) bars to calculate one value
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
// Optimization: We can start copying from src_start_index, but to be safe with incremental updates,
// we copy from start_index (or src_start_index if we are at the beginning).
   int copy_start = MathMax(start_index, src_start_index);

   for(int i = copy_start; i < rates_total; i++)
      m_price[i] = src_buffer[i];

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
         // DEMA/TEMA use EMA internally. We trust CalculateEMA to handle start_index correctly.
         // However, DEMA needs 2x lag, TEMA 3x lag.
         // CalculateEMA handles initialization if passed correct start index.
         CalculateEMA(rates_total, loop_start, m_period, m_price, m_temp_buffer1);
         CalculateEMA(rates_total, loop_start, m_period, m_temp_buffer1, m_temp_buffer2);

         // Final loop
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
// Note: start_index passed here is already adjusted for offset in RunCalculation
   if(rates_total < period)
      return;

   double pr = 2.0 / (double)(period + 1.0);

// Robust initialization check:
// If the previous value is empty or 0 (and we are not at index 0), we might need to re-initialize.
// But for strict incremental logic, we trust start_index.
// The only edge case is the very first calculation.

   for(int i = start_index; i < rates_total; i++)
     {
      // Check if we have a valid previous value to recurse on
      bool has_prev = (i > 0 && dest[i-1] != 0.0 && dest[i-1] != EMPTY_VALUE);

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
         // We need 'period' valid bars ending at i.
         // source[i], source[i-1] ... source[i-period+1]
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
            dest[i] = 0; // Should not happen if start_index is correct
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
//+------------------------------------------------------------------+
