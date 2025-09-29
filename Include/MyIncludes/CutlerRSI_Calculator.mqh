//+------------------------------------------------------------------+
//|                                           CutlerRSI_Calculator.mqh|
//|   Calculation engine for Standard and Heikin Ashi Cutler's RSI.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CCutlerRSICalculator (Base Class)             |
//|                                                                  |
//+==================================================================+
class CCutlerRSICalculator
  {
protected:
   int               m_rsi_period;
   int               m_ma_period;
   ENUM_MA_METHOD    m_ma_method;

   //--- Internal buffer for the selected source price
   double            m_price[];

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CCutlerRSICalculator(void) {};
   virtual          ~CCutlerRSICalculator(void) {};

   //--- Public methods
   bool              Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| CCutlerRSICalculator: Initialization                             |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator::Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   return true;
  }

//+------------------------------------------------------------------+
//| CCutlerRSICalculator: Main Calculation Method (Shared Logic)     |
//+------------------------------------------------------------------+
void CCutlerRSICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_rsi_period)
      return;

//--- STEP 1: Prepare the source price array (delegated to virtual method)
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

//--- STEP 2: Calculate Cutler's RSI (SMA-based) using a sliding window sum
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      double pos_change = (diff > 0) ? diff : 0;
      double neg_change = (diff < 0) ? -diff : 0;

      sum_pos += pos_change;
      sum_neg += neg_change;

      if(i > m_rsi_period)
        {
         double old_diff = m_price[i - m_rsi_period] - m_price[i - m_rsi_period - 1];
         sum_pos -= (old_diff > 0) ? old_diff : 0;
         sum_neg -= (old_diff < 0) ? -old_diff : 0;
        }

      if(i >= m_rsi_period)
        {
         if(sum_pos + sum_neg > 0)
           {
            // The division by period cancels out, so we can use sums directly
            double rs = sum_pos / sum_neg;
            rsi_buffer[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            rsi_buffer[i] = 100.0;
           }
        }
     }

//--- STEP 3: Calculate the Signal Line (MA of Cutler's RSI)
   int ma_start_pos = m_rsi_period + m_ma_period - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_ma_period; j++)
                  sum+=rsi_buffer[i-j];
               signal_buffer[i] = sum/m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  signal_buffer[i] = rsi_buffer[i]*pr + signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i] = (signal_buffer[i-1]*(m_ma_period-1)+rsi_buffer[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_ma_period; j++) {int weight=m_ma_period-j; lwma_sum+=rsi_buffer[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) signal_buffer[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=rsi_buffer[i-j]; signal_buffer[i] = sum/m_ma_period;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CCutlerRSICalculator: Prepares the standard source price series. |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|         CLASS 2: CCutlerRSICalculator_HA (Heikin Ashi)           |
//|                                                                  |
//+==================================================================+
class CCutlerRSICalculator_HA : public CCutlerRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CCutlerRSICalculator_HA: Prepares the Heikin Ashi source price.  |
//+------------------------------------------------------------------+
bool CCutlerRSICalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- First, calculate the HA candles
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, populate the m_price array from the calculated HA candles
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
