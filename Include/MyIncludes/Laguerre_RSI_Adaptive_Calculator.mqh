//+------------------------------------------------------------------+
//|                         Laguerre_RSI_Adaptive_Calculator.mqh     |
//|    Calculation engine for the Adaptive Laguerre RSI.             |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|       CLASS 1: CLaguerreRSIAdaptiveCalculator (Base)             |
//|                                                                  |
//+==================================================================+
class CLaguerreRSIAdaptiveCalculator
  {
protected:
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreRSIAdaptiveCalculator(void) {};
   virtual          ~CLaguerreRSIAdaptiveCalculator(void) {};

   bool              Init(void);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| CLaguerreRSIAdaptiveCalculator: Initialization                   |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator::Init(void)
  {
   return true;
  }

//+------------------------------------------------------------------+
//| CLaguerreRSIAdaptiveCalculator: Main Calculation Method          |
//+------------------------------------------------------------------+
void CLaguerreRSIAdaptiveCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[])
  {
   if(rates_total < 10)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double filt_buffer[];
   ArrayResize(filt_buffer, rates_total);
   ArrayInitialize(filt_buffer, 0.0);
   double Filt=0, Filt_prev=0, Filt_prev2=0;
   double I1=0, Q1=0, I1_prev=0, Q1_prev=0;
   double I2=0, Q2=0, I2_prev=0, Q2_prev=0;
   double Re=0, Im=0;
   double Period=0, Period_prev=0;
   double DC_Period=0, DC_Period_prev=0;
   double L0=0, L1=0, L2=0, L3=0;
   double L0_prev=0, L1_prev=0, L2_prev=0, L3_prev=0;
   double alpha1 = (cos(0.707 * 2 * M_PI / 48.0) + sin(0.707 * 2 * M_PI / 48.0) - 1.0) / cos(0.707 * 2 * M_PI / 48.0);
   double beta1 = 1.0 - alpha1 / 2.0;
   beta1 *= beta1;

   for(int i = 0; i < rates_total; i++)
     {
      // Steps 1-5: Cycle Measurement and Adaptive Gamma Calculation (Identical to Adaptive Filter)
      if(i > 1)
         Filt = beta1 * (m_price[i] - 2 * m_price[i-1] + m_price[i-2]) + (2 * (1 - alpha1 / 2.0)) * Filt_prev - ((1 - alpha1 / 2.0) * (1 - alpha1 / 2.0)) * Filt_prev2;
      else
         Filt = 0;
      filt_buffer[i] = Filt;
      if(i > 6)
        {
         Q1 = (0.0962 * filt_buffer[i] + 0.5769 * filt_buffer[i-2] - 0.5769 * filt_buffer[i-4] - 0.0962 * filt_buffer[i-6]) * (0.5 + 0.08 * (I1_prev + 50));
         I1 = filt_buffer[i-3];
        }
      if(i > 0)
        {
         I2 = I1 - Q1_prev;
         Q2 = Q1 + I1_prev;
         Re = I2 * I2_prev + Q2 * Q2_prev;
         Im = I2 * Q2_prev - Q2 * I2_prev;
        }
      if(Im != 0.0 && Re != 0.0)
         Period = 2 * M_PI / atan(Im / Re);
      else
         Period = 0.0;
      if(Period > 1.5 * Period_prev)
         Period = 1.5 * Period_prev;
      if(Period < 0.67 * Period_prev)
         Period = 0.67 * Period_prev;
      if(Period < 6)
         Period = 6;
      if(Period > 50)
         Period = 50;
      DC_Period = 0.2 * Period + 0.8 * DC_Period_prev;
      double gamma = 0.0;
      if(DC_Period > 0)
         gamma = 4.0 / DC_Period;

      // Step 6: Apply the Laguerre Filter with the dynamic gamma
      if(i > 0)
        {
         L0 = (1.0 - gamma) * m_price[i] + gamma * L0_prev;
         L1 = -gamma * L0 + L0_prev + gamma * L1_prev;
         L2 = -gamma * L1 + L1_prev + gamma * L2_prev;
         L3 = -gamma * L2 + L2_prev + gamma * L3_prev;
        }
      else
        {
         L0 = m_price[i];
         L1 = m_price[i];
         L2 = m_price[i];
         L3 = m_price[i];
        }

      // --- NEW Step 7: Calculate RSI from the adaptive filter components ---
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

      // --- Update previous values for the next iteration ---
      Filt_prev2 = Filt_prev;
      Filt_prev = Filt;
      I1_prev = I1;
      Q1_prev = Q1;
      I2_prev = I2;
      Q2_prev = Q2;
      Period_prev = Period;
      DC_Period_prev = DC_Period;
      L0_prev = L0;
      L1_prev = L1;
      L2_prev = L2;
      L3_prev = L3;
     }
  }

//+------------------------------------------------------------------+
//| CLaguerreRSIAdaptiveCalculator: Prepares the standard source price. |
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
class CLaguerreRSIAdaptiveCalculator_HA : public CLaguerreRSIAdaptiveCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
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
