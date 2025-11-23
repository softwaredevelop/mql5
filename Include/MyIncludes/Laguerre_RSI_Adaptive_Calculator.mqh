//+------------------------------------------------------------------+
//|                         Laguerre_RSI_Adaptive_Calculator.mqh     |
//|    VERSION 1.10: Added signal line and fixed state management.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CLaguerreRSIAdaptiveCalculator
  {
protected:
   double            m_price[];
   int               m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;

   //--- State variables for the recursive filters ---
   double            m_Filt_prev, m_Filt_prev2;
   double            m_I1_prev, m_Q1_prev;
   double            m_I2_prev, m_Q2_prev;
   double            m_Period_prev, m_DC_Period_prev;
   double            m_L0_prev, m_L1_prev, m_L2_prev, m_L3_prev;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CLaguerreRSIAdaptiveCalculator(void) {};
   virtual          ~CLaguerreRSIAdaptiveCalculator(void) {};

   bool              Init(int signal_p, ENUM_MA_TYPE signal_ma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                         double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLaguerreRSIAdaptiveCalculator_HA : public CLaguerreRSIAdaptiveCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator::Init(int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;

   m_Filt_prev=0;
   m_Filt_prev2=0;
   m_I1_prev=0;
   m_Q1_prev=0;
   m_I2_prev=0;
   m_Q2_prev=0;
   m_Period_prev=0;
   m_DC_Period_prev=0;
   m_L0_prev=0;
   m_L1_prev=0;
   m_L2_prev=0;
   m_L3_prev=0;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLaguerreRSIAdaptiveCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 10)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double filt_buffer[];
   ArrayResize(filt_buffer, rates_total);
   double I1=0, Q1=0, I2=0, Q2=0, Re=0, Im=0, Period=0, DC_Period=0;
   double L0=0, L1=0, L2=0, L3=0;

   double alpha1 = (cos(0.707 * 2 * M_PI / 48.0) + sin(0.707 * 2 * M_PI / 48.0) - 1.0) / cos(0.707 * 2 * M_PI / 48.0);
   double beta1 = 1.0 - alpha1 / 2.0;
   beta1 *= beta1;

   for(int i = 0; i < rates_total; i++)
     {
      double Filt = (i > 1) ? beta1 * (m_price[i] - 2 * m_price[i-1] + m_price[i-2]) + (2 * (1 - alpha1 / 2.0)) * m_Filt_prev - ((1 - alpha1 / 2.0) * (1 - alpha1 / 2.0)) * m_Filt_prev2 : 0;
      filt_buffer[i] = Filt;

      if(i > 6)
        {
         Q1 = (0.0962 * filt_buffer[i] + 0.5769 * filt_buffer[i-2] - 0.5769 * filt_buffer[i-4] - 0.0962 * filt_buffer[i-6]) * (0.5 + 0.08 * (m_I1_prev + 50));
         I1 = filt_buffer[i-3];
        }
      if(i > 0)
        {
         I2 = I1 - m_Q1_prev;
         Q2 = Q1 + m_I1_prev;
         Re = I2 * m_I2_prev + Q2 * m_Q2_prev;
         Im = I2 * m_Q2_prev - Q2 * m_I2_prev;
        }
      if(Im != 0.0 && Re != 0.0)
         Period = 2 * M_PI / atan(Im / Re);
      else
         Period = 0.0;
      if(Period > 1.5 * m_Period_prev && i > 0)
         Period = 1.5 * m_Period_prev;
      if(Period < 0.67 * m_Period_prev)
         Period = 0.67 * m_Period_prev;
      if(Period < 6)
         Period = 6;
      if(Period > 50)
         Period = 50;

      DC_Period = 0.2 * Period + 0.8 * m_DC_Period_prev;
      double gamma = (DC_Period > 0) ? 4.0 / DC_Period : 0;

      if(i > 0)
        {
         L0 = (1.0 - gamma) * m_price[i] + gamma * m_L0_prev;
         L1 = -gamma * L0 + m_L0_prev + gamma * m_L1_prev;
         L2 = -gamma * L1 + m_L1_prev + gamma * m_L2_prev;
         L3 = -gamma * L2 + m_L2_prev + gamma * m_L3_prev;
        }
      else
        {
         L0=m_price[i];
         L1=m_price[i];
         L2=m_price[i];
         L3=m_price[i];
        }

      double cu = 0.0, cd = 0.0;
      if(L0 >= L1)
         cu = L0 - L1;
      else
         cd = L1 - L0;
      if(L1 >= L2)
         cu += L1 - L2;
      else
         cd += L2 - L1;
      if(L2 >= L3)
         cu += L2 - L3;
      else
         cd += L3 - L2;

      double lrsi_value;
      if(cu + cd > 0.0)
         lrsi_value = 100.0 * cu / (cu + cd);
      else
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0;
      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;
      lrsi_buffer[i] = lrsi_value;

      m_Filt_prev2 = m_Filt_prev;
      m_Filt_prev = Filt;
      m_I1_prev = I1;
      m_Q1_prev = Q1;
      m_I2_prev = I2;
      m_Q2_prev = Q2;
      m_Period_prev = Period;
      m_DC_Period_prev = DC_Period;
      m_L0_prev = L0;
      m_L1_prev = L1;
      m_L2_prev = L2;
      m_L3_prev = L3;
     }

   int signal_start = 10 + m_signal_period - 1;
   CalculateMA(lrsi_buffer, signal_buffer, m_signal_period, m_signal_ma_type, signal_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLaguerreRSIAdaptiveCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case EMA:
         case SMMA:
            if(i == start_pos)
              {
               double sum=0;
               int count=0;
               for(int j=0; j<period; j++)
                 {
                  if(source_array[i-j] != EMPTY_VALUE)
                    {
                     sum+=source_array[i-j];
                     count++;
                    }
                 }
               if(count > 0)
                  dest_array[i]=sum/count;
              }
            else
              {
               if(method==EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case LWMA:
           {
            double sum=0, w_sum=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] == EMPTY_VALUE)
                  continue;
               int w=period-j;
               sum+=source_array[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest_array[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            int count=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] != EMPTY_VALUE)
                 {
                  sum+=source_array[i-j];
                  count++;
                 }
              }
            if(count > 0)
               dest_array[i]=sum/count;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
