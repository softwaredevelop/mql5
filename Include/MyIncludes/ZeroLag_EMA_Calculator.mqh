//+------------------------------------------------------------------+
//|                                     ZeroLag_EMA_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Zero-Lag EMA.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CZeroLagEMACalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CZeroLagEMACalculator
  {
protected:
   int               m_period;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CZeroLagEMACalculator(void) {};
   virtual          ~CZeroLagEMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[]);
  };

//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CZeroLagEMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &zlema_buffer[])
  {
   if(rates_total < m_period * 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double alpha = 2.0 / (m_period + 1.0);

// --- Intermediate buffers for the two EMA stages ---
   double ema1_buffer[], ema2_buffer[];
   ArrayResize(ema1_buffer, rates_total);
   ArrayResize(ema2_buffer, rates_total);

// --- State variables for recursive calculations ---
   double ema1_prev = 0;
   double ema2_prev = 0;

// --- Full recalculation loop for stability ---
   for(int i = 0; i < rates_total; i++)
     {
      // Initialize first value with a simple average
      if(i == m_period - 1)
        {
         double sum = 0;
         for(int j=0; j<m_period; j++)
            sum += m_price[i-j];
         ema1_prev = sum / m_period;
        }

      if(i >= m_period)
        {
         // Step 1: Calculate first EMA on price
         double ema1 = m_price[i] * alpha + (1.0 - alpha) * ema1_prev;
         ema1_buffer[i] = ema1;

         // Initialize second EMA
         if(i == m_period * 2 - 2)
           {
            double sum = 0;
            for(int j=0; j<m_period; j++)
               sum += ema1_buffer[i-j];
            ema2_prev = sum / m_period;
           }

         if(i >= m_period * 2 - 1)
           {
            // Step 2: Calculate second EMA on the first EMA
            double ema2 = ema1_buffer[i] * alpha + (1.0 - alpha) * ema2_prev;
            ema2_buffer[i] = ema2;

            // Step 3 & 4: Calculate the difference (error) and add it back to the first EMA
            double diff = ema1_buffer[i] - ema2_buffer[i];
            zlema_buffer[i] = ema1_buffer[i] + diff;

            ema2_prev = ema2;
           }

         ema1_prev = ema1;
        }
     }
  }

//+------------------------------------------------------------------+
bool CZeroLagEMACalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }

//+==================================================================+
class CZeroLagEMACalculator_HA : public CZeroLagEMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CZeroLagEMACalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
