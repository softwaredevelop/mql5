//+------------------------------------------------------------------+
//|                                               MFI_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi MFI.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CMFICalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CMFICalculator
  {
protected:
   int               m_mfi_period, m_ma_period;
   ENUM_MA_METHOD    m_ma_method;
   ENUM_APPLIED_VOLUME m_volume_type;
   double            m_typical_price[];

   //--- CORRECTED: Added 'open' to signature
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMFICalculator(void) {};
   virtual          ~CMFICalculator(void) {};

   bool              Init(int mfi_p, int ma_p, ENUM_MA_METHOD ma_m, ENUM_APPLIED_VOLUME vol_t);
   //--- CORRECTED: Added 'open' to signature
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[],
                               double &mfi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| CMFICalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CMFICalculator::Init(int mfi_p, int ma_p, ENUM_MA_METHOD ma_m, ENUM_APPLIED_VOLUME vol_t)
  {
   m_mfi_period  = (mfi_p < 1) ? 1 : mfi_p;
   m_ma_period   = (ma_p < 1) ? 1 : ma_p;
   m_ma_method   = ma_m;
   m_volume_type = vol_t;
   return true;
  }

//+------------------------------------------------------------------+
//| CMFICalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CMFICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[],
                               double &mfi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_mfi_period + m_ma_period)
      return;
//--- CORRECTED: Pass 'open' to PreparePriceSeries
   if(!PreparePriceSeries(rates_total, open, high, low, close))
      return;

   double pos_mf[], neg_mf[];
   ArrayResize(pos_mf, rates_total);
   ArrayResize(neg_mf, rates_total);

   for(int i=1; i<rates_total; i++)
     {
      double raw_mf = m_typical_price[i] * ((m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i]);
      if(m_typical_price[i] > m_typical_price[i-1])
         pos_mf[i] = raw_mf;
      else
         if(m_typical_price[i] < m_typical_price[i-1])
            neg_mf[i] = raw_mf;
     }

   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      sum_pos += pos_mf[i];
      sum_neg += neg_mf[i];
      if(i > m_mfi_period)
        {
         sum_pos -= pos_mf[i - m_mfi_period];
         sum_neg -= neg_mf[i - m_mfi_period];
        }
      if(i >= m_mfi_period)
        {
         if(sum_neg > 0)
           {
            double ratio = sum_pos / sum_neg;
            mfi_buffer[i] = 100.0 - (100.0 / (1.0 + ratio));
           }
         else
            mfi_buffer[i] = 100.0;
        }
     }

   int ma_start_pos = m_mfi_period + m_ma_period - 1;
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
                  sum+=mfi_buffer[i-j];
               signal_buffer[i] = sum/m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_ma_period+1.0);
                  signal_buffer[i] = mfi_buffer[i]*pr + signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i] = (signal_buffer[i-1]*(m_ma_period-1)+mfi_buffer[i])/m_ma_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_ma_period; j++) {int weight=m_ma_period-j; lwma_sum+=mfi_buffer[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) signal_buffer[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=mfi_buffer[i-j]; signal_buffer[i] = sum/m_ma_period;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CMFICalculator: Prepares the standard source price series.       |
//+------------------------------------------------------------------+
bool CMFICalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CMFICalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CMFICalculator_HA : public CMFICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   //--- CORRECTED: Added 'open' to signature
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CMFICalculator_HA: Prepares the Heikin Ashi source price.        |
//+------------------------------------------------------------------+
bool CMFICalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
//--- CORRECTED: Pass 'open' to the HA calculator
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
