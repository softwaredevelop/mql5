//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|      VERSION 1.40: Optimized for incremental calculation.        |
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
class CMovingAverageCalculator
  {
protected:
   int               m_period;
   ENUM_MA_TYPE      m_ma_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];

   //--- Buffers for complex MAs (TMA, DEMA, TEMA)
   double            m_temp_buffer1[]; // Used for TMA(sma1), DEMA(ema1), TEMA(ema1)
   double            m_temp_buffer2[]; // Used for DEMA(ema2), TEMA(ema2)
   double            m_temp_buffer3[]; // Used for TEMA(ema3)

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Updated: Accepts start_index
   void              CalculateEMA(int rates_total, int start_index, int period, const double &source[], double &dest[]);

public:
                     CMovingAverageCalculator(void) {};
   virtual          ~CMovingAverageCalculator(void) {};

   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[]);

   int               GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMovingAverageCalculator_HA : public CMovingAverageCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers (Persistent)
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

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
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &ma_buffer[])
  {
   if(rates_total < m_period)
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
      // Resize temp buffers only if needed by type
      if(m_ma_type == TMA || m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer1, rates_total);
      if(m_ma_type == DEMA || m_ma_type == TEMA)
         ArrayResize(m_temp_buffer2, rates_total);
      if(m_ma_type == TEMA)
         ArrayResize(m_temp_buffer3, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int start_pos = m_period - 1;
   int loop_start = MathMax(start_pos, start_index);

//--- 4. Calculate MA based on type
   switch(m_ma_type)
     {
      case EMA:
         CalculateEMA(rates_total, start_index, m_period, m_price, ma_buffer);
         break;

      case SMMA:
         for(int i = loop_start; i < rates_total; i++)
           {
            if(i == start_pos)
              {
               double sum=0;
               for(int j=0; j<m_period; j++)
                  sum+=m_price[i-j];
               ma_buffer[i]=sum/m_period;
              }
            else
               // Recursive SMMA works incrementally because ma_buffer[i-1] is preserved
               ma_buffer[i]=(ma_buffer[i-1]*(m_period-1)+m_price[i])/m_period;
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
               ma_buffer[i]=sum/w_sum;
           }
         break;

      case TMA:
        {
         int period1 = (int)ceil((m_period + 1.0) / 2.0);
         int loop_start_tma = MathMax(period1 - 1, start_index);

         // Step 1: Simple MA into temp buffer
         for(int i = loop_start_tma; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period1; j++)
               sum += m_price[i-j];
            m_temp_buffer1[i] = sum / period1;
           }

         // Step 2: Simple MA of the first MA
         int period2 = m_period - period1 + 1;
         int loop_start_final = MathMax(period1 + period2 - 2, start_index);

         for(int i = loop_start_final; i < rates_total; i++)
           {
            double sum = 0;
            for(int j = 0; j < period2; j++)
               sum += m_temp_buffer1[i-j];
            ma_buffer[i] = sum / period2;
           }
        }
      break;

      case DEMA:
        {
         // EMA1 of Price
         CalculateEMA(rates_total, start_index, m_period, m_price, m_temp_buffer1);
         // EMA2 of EMA1
         CalculateEMA(rates_total, start_index, m_period, m_temp_buffer1, m_temp_buffer2);

         int loop_start_dema = MathMax((m_period - 1) * 2, start_index);
         for(int i = loop_start_dema; i < rates_total; i++)
            ma_buffer[i] = 2 * m_temp_buffer1[i] - m_temp_buffer2[i];
         break;
        }

      case TEMA:
        {
         // EMA1 of Price
         CalculateEMA(rates_total, start_index, m_period, m_price, m_temp_buffer1);
         // EMA2 of EMA1
         CalculateEMA(rates_total, start_index, m_period, m_temp_buffer1, m_temp_buffer2);
         // EMA3 of EMA2
         CalculateEMA(rates_total, start_index, m_period, m_temp_buffer2, m_temp_buffer3);

         int loop_start_tema = MathMax((m_period - 1) * 3, start_index);
         for(int i = loop_start_tema; i < rates_total; i++)
            ma_buffer[i] = 3 * m_temp_buffer1[i] - 3 * m_temp_buffer2[i] + m_temp_buffer3[i];
         break;
        }

      default: // SMA
         for(int i = loop_start; i < rates_total; i++)
           {
            double sum=0;
            for(int j=0; j<m_period; j++)
               sum+=m_price[i-j];
            ma_buffer[i]=sum/m_period;
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

   int start_pos = period - 1;
   double pr = 2.0 / (double)(period + 1.0);

// Determine where to start loop
   int i = MathMax(start_pos, start_index);

// If starting from the very beginning (or before valid data), initialize first value
   if(i == start_pos)
     {
      double sum=0;
      for(int j=0; j<period; j++)
         if(source[start_pos-j] != EMPTY_VALUE)
            sum += source[start_pos-j];
      dest[start_pos] = sum / period;
      i++; // Move to next
     }

   for(; i < rates_total; i++)
     {
      if(source[i] != EMPTY_VALUE)
         // Recursive calculation uses dest[i-1] which is safe due to persistence
         dest[i] = source[i] * pr + dest[i-1] * (1.0 - pr);
      else
         dest[i] = dest[i-1];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
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
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i]+m_ha_close[i])/4.0;
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
