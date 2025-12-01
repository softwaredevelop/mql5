//+------------------------------------------------------------------+
//|                                               MACD_Calculator.mqh|
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CMACDCalculator (Base Class)                |
//+==================================================================+
class CMACDCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_MA_METHOD    m_source_ma_type, m_signal_ma_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_fast_ma[];
   double            m_slow_ma[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CMACDCalculator(void) {};
   virtual          ~CMACDCalculator(void) {};

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma)
  {
   m_fast_period = (fast_p < 1) ? 1 : fast_p;
   m_slow_period = (slow_p < 1) ? 1 : slow_p;
   if(m_fast_period > m_slow_period)
     {
      int temp=m_fast_period;
      m_fast_period=m_slow_period;
      m_slow_period=temp;
     }
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_source_ma_type = src_ma;
   m_signal_ma_type = sig_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
   int start_pos = m_slow_period + m_signal_period - 2;
   if(rates_total <= start_pos)
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
      ArrayResize(m_fast_ma, rates_total);
      ArrayResize(m_slow_ma, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close, price_type))
      return;

//--- 4. Calculate Fast MA (Incremental)
   int loop_start_fast = MathMax(m_fast_period - 1, start_index);

   for(int i = loop_start_fast; i < rates_total; i++)
     {
      switch(m_source_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_fast_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_fast_period; j++)
                  sum+=m_price[i-j];
               m_fast_ma[i]=sum/m_fast_period;
              }
            else
              {
               if(m_source_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_fast_period+1.0);
                  m_fast_ma[i]=m_price[i]*pr+m_fast_ma[i-1]*(1.0-pr);
                 }
               else
                  m_fast_ma[i]=(m_fast_ma[i-1]*(m_fast_period-1)+m_price[i])/m_fast_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_fast_period; j++) {int w=m_fast_period-j; sum+=m_price[i-j]*w; w_sum+=w;} if(w_sum>0) m_fast_ma[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_fast_period; j++) sum+=m_price[i-j]; m_fast_ma[i]=sum/m_fast_period;}
         break;
        }
     }

//--- 5. Calculate Slow MA (Incremental)
   int loop_start_slow = MathMax(m_slow_period - 1, start_index);

   for(int i = loop_start_slow; i < rates_total; i++)
     {
      switch(m_source_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_slow_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_slow_period; j++)
                  sum+=m_price[i-j];
               m_slow_ma[i]=sum/m_slow_period;
              }
            else
              {
               if(m_source_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_slow_period+1.0);
                  m_slow_ma[i]=m_price[i]*pr+m_slow_ma[i-1]*(1.0-pr);
                 }
               else
                  m_slow_ma[i]=(m_slow_ma[i-1]*(m_slow_period-1)+m_price[i])/m_slow_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_slow_period; j++) {int w=m_slow_period-j; sum+=m_price[i-j]*w; w_sum+=w;} if(w_sum>0) m_slow_ma[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_slow_period; j++) sum+=m_price[i-j]; m_slow_ma[i]=sum/m_slow_period;}
         break;
        }
     }

//--- 6. Calculate MACD Line
   int loop_start_macd = MathMax(loop_start_slow, loop_start_fast); // Should be slow

   for(int i = loop_start_macd; i < rates_total; i++)
     {
      macd_line[i] = m_fast_ma[i] - m_slow_ma[i];
     }

//--- 7. Calculate Signal Line (Incremental)
   int signal_start_pos = m_slow_period + m_signal_period - 2;
   int loop_start_signal = MathMax(signal_start_pos, start_index);

   for(int i = loop_start_signal; i < rates_total; i++)
     {
      switch(m_signal_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == signal_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_signal_period; j++)
                  sum+=macd_line[i-j];
               signal_line[i]=sum/m_signal_period;
              }
            else
              {
               if(m_signal_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_signal_period+1.0);
                  signal_line[i]=macd_line[i]*pr+signal_line[i-1]*(1.0-pr);
                 }
               else
                  signal_line[i]=(signal_line[i-1]*(m_signal_period-1)+macd_line[i])/m_signal_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_signal_period; j++) {int w=m_signal_period-j; sum+=macd_line[i-j]*w; w_sum+=w;} if(w_sum>0) signal_line[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_signal_period; j++) sum+=macd_line[i-j]; signal_line[i]=sum/m_signal_period;}
         break;
        }
     }

//--- 8. Calculate Histogram
   for(int i = loop_start_signal; i < rates_total; i++)
     {
      histogram[i] = macd_line[i] - signal_line[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
//|             CLASS 2: CMACDCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CMACDCalculator_HA : public CMACDCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMACDCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
