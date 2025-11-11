//+------------------------------------------------------------------+
//|                                           RSI_Pro_Calculator.mqh |
//|        VERSION 3.22: Fixed enum conflicts and variable scopes.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- NEW: Non-conflicting universal enum for all smoothing types ---
enum ENUM_SMOOTHING_METHOD
  {
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA,
   SMOOTH_SuperSmoother
  };

//+==================================================================+
class CRSIProCalculator
  {
protected:
   int               m_rsi_period, m_ma_period;
   double            m_deviation;
   ENUM_SMOOTHING_METHOD m_ma_method; // Use the new enum

   double            m_sig_f1, m_sig_f2;
   double            m_price[], m_rsi_buffer[], m_ma_buffer[], m_upper_band[], m_lower_band[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIProCalculator(void) : m_sig_f1(0), m_sig_f2(0) {};
   virtual          ~CRSIProCalculator(void) {};

   bool              Init(int rsi_p, int ma_p, ENUM_SMOOTHING_METHOD ma_m, double dev);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(int rsi_p, int ma_p, ENUM_SMOOTHING_METHOD ma_m, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   m_deviation  = dev;
   m_sig_f1 = 0;
   m_sig_f2 = 0;
   return true;
  }

//+------------------------------------------------------------------+
void CRSIProCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total <= m_rsi_period)
      return;
   ArrayResize(m_price, rates_total);
   ArrayResize(m_rsi_buffer, rates_total);
   ArrayResize(m_ma_buffer, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- Step 1: Calculate base RSI (Unchanged)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;
      if(i >= m_rsi_period)
        {
         if(sum_neg > 0)
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            m_rsi_buffer[i] = 100.0;
        }
     }

//--- Step 2: Calculate Signal Line on RSI
   int ma_start_pos = m_rsi_period + m_ma_period - 1;

   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case SMOOTH_SuperSmoother:
           {
            //--- Coefficients are now calculated locally inside the case block ---
            double a1 = exp(-M_SQRT2 * M_PI / m_ma_period);
            double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / m_ma_period);
            double c2 = b1, c3 = -a1 * a1, c1 = 1.0 - c2 - c3;

            if(i==ma_start_pos) // Robust initialization
              {
               double sum=0;
               for(int j=0; j<m_ma_period; j++)
                  sum+=m_rsi_buffer[i-j];
               m_ma_buffer[i] = sum/m_ma_period;
               m_sig_f1 = m_ma_buffer[i];
               m_sig_f2 = (i > 0) ? m_ma_buffer[i-1] : m_ma_buffer[i];
              }
            else
              {
               m_ma_buffer[i] = c1 * (m_rsi_buffer[i] + m_rsi_buffer[i-1]) / 2.0 + c2 * m_sig_f1 + c3 * m_sig_f2;
               m_sig_f2 = m_sig_f1;
               m_sig_f1 = m_ma_buffer[i];
              }
            break;
           }
         case SMOOTH_EMA:
         case SMOOTH_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_ma_period; j++)
                  sum+=m_rsi_buffer[i-j];
               m_ma_buffer[i]=sum/m_ma_period;
              }
            else
              {
               if(m_ma_method==SMOOTH_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  m_ma_buffer[i]=m_rsi_buffer[i]*pr+m_ma_buffer[i-1]*(1.0-pr);
                 }
               else
                  m_ma_buffer[i]=(m_ma_buffer[i-1]*(m_ma_period-1)+m_rsi_buffer[i])/m_ma_period;
              }
            break;
         case SMOOTH_LWMA:
           { double sum=0,w_sum=0; for(int j=0; j<m_ma_period; j++) {int w=m_ma_period-j; sum+=m_rsi_buffer[i-j]*w; w_sum+=w;} if(w_sum>0) m_ma_buffer[i]=sum/w_sum; }
         break;
         default: // SMOOTH_SMA
           { double sum=0; for(int j=0; j<m_ma_period; j++) sum+=m_rsi_buffer[i-j]; m_ma_buffer[i]=sum/m_ma_period; }
         break;
        }
     }

//--- Step 3: Calculate Bollinger Bands on the MA line (Unchanged)
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
         sum_sq += pow(m_rsi_buffer[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_ma_period);
      m_upper_band[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }

   ArrayCopy(rsi_out, m_rsi_buffer, 0, 0, rates_total);
   ArrayCopy(ma_out, m_ma_buffer, 0, 0, rates_total);
   ArrayCopy(upper_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_out, m_lower_band, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| CRSIProCalculator: Prepares the source price series.             |
//+------------------------------------------------------------------+
bool CRSIProCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
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
//|                                                                  |
//|             CLASS 2: CRSIProCalculator_HA (Heikin Ashi)          |
//|                                                                  |
//+==================================================================+
class CRSIProCalculator_HA : public CRSIProCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CRSIProCalculator_HA: Prepares the source price series.          |
//+------------------------------------------------------------------+
bool CRSIProCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Corrected: The HA version now uses the selected price type from the HA candles
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
