//+------------------------------------------------------------------+
//|                               Stochastic_Roofing_Calculator.mqh  |
//|      Calculation engine for a Stochastic (Fast or Slow) on an    |
//|      Ehlers' Roofing Filter.                                     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_STOCH_TYPE { STOCH_FAST, STOCH_SLOW };

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CStochasticRoofingCalculator (Base)             |
//|                                                                  |
//+==================================================================+
class CStochasticRoofingCalculator
  {
protected:
   int               m_hp_period, m_ss_period; // Roofing
   int               m_k_period, m_d_period, m_slowing; // Stochastic
   ENUM_STOCH_TYPE   m_stoch_type;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticRoofingCalculator(void) {};
   virtual          ~CStochasticRoofingCalculator(void) {};

   bool              Init(int hp_p, int ss_p, int k_p, int d_p, int slowing, ENUM_STOCH_TYPE stoch_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
bool CStochasticRoofingCalculator::Init(int hp_p, int ss_p, int k_p, int d_p, int slowing, ENUM_STOCH_TYPE stoch_type)
  {
   m_hp_period = (hp_p < 10) ? 10 : hp_p;
   m_ss_period = (ss_p < 2) ? 2 : ss_p;
   m_k_period = (k_p < 1) ? 1 : k_p;
   m_d_period = (d_p < 1) ? 1 : d_p;
   m_slowing = (slowing < 1) ? 1 : slowing;
   m_stoch_type = stoch_type;
   return true;
  }

//+------------------------------------------------------------------+
void CStochasticRoofingCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = m_hp_period + m_k_period + m_slowing + m_d_period;
   if(rates_total < warmup)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Step 1: Calculate Roofing Filter ---
   double roofing_buffer[];
   ArrayResize(roofing_buffer, rates_total);
   double hp_buffer[];
   ArrayResize(hp_buffer, rates_total);
   double arg_hp = 0.707 * 2 * M_PI / m_hp_period;
   double alpha1_hp = (cos(arg_hp) + sin(arg_hp) - 1.0) / cos(arg_hp);
   double hp1=0, hp2=0;
   for(int i=2; i<rates_total; i++)
     {
      hp_buffer[i] = pow(1.0 - alpha1_hp / 2.0, 2) * (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]) + 2.0 * (1.0 - alpha1_hp) * hp1 - pow(1.0 - alpha1_hp, 2) * hp2;
      hp2 = hp1;
      hp1 = hp_buffer[i];
     }
   double arg_ss = 1.414 * M_PI / m_ss_period;
   double a1_ss = exp(-arg_ss), b1_ss = 2.0 * a1_ss * cos(arg_ss);
   double c2_ss = b1_ss, c3_ss = -a1_ss*a1_ss, c1_ss = 1.0 - c2_ss - c3_ss;
   double filt1=0, filt2=0;
   for(int i=1; i<rates_total; i++)
     {
      roofing_buffer[i] = c1_ss * (hp_buffer[i] + hp_buffer[i-1]) / 2.0 + c2_ss * filt1 + c3_ss * filt2;
      filt2 = filt1;
      filt1 = roofing_buffer[i];
     }

// --- Step 2: Calculate Raw %K on the Roofing Filter output ---
   double raw_k_buffer[];
   ArrayResize(raw_k_buffer, rates_total);
   for(int i = m_k_period - 1; i < rates_total; i++)
     {
      int low_idx = ArrayMinimum(roofing_buffer, i - m_k_period + 1, m_k_period);
      int high_idx = ArrayMaximum(roofing_buffer, i - m_k_period + 1, m_k_period);
      double lowest_low = roofing_buffer[low_idx];
      double highest_high = roofing_buffer[high_idx];
      if(highest_high - lowest_low != 0)
         raw_k_buffer[i] = 100.0 * (roofing_buffer[i] - lowest_low) / (highest_high - lowest_low);
     }

// --- Step 3: Smooth Raw %K based on Stochastic Type ---
   if(m_stoch_type == STOCH_FAST)
     {
      // For Fast Stoch, %K is the raw value, %D is the first smoothing
      ArrayCopy(k_buffer, raw_k_buffer, 0, 0, rates_total);
      for(int i = m_k_period - 1 + m_d_period - 1; i < rates_total; i++)
        {
         double sum = 0;
         for(int j = 0; j < m_d_period; j++)
            sum += k_buffer[i-j];
         d_buffer[i] = sum / m_d_period;
        }
     }
   else // STOCH_SLOW
     {
      // For Slow Stoch, %K is the first smoothing, %D is the second smoothing
      for(int i = m_k_period - 1 + m_slowing - 1; i < rates_total; i++)
        {
         double sum = 0;
         for(int j = 0; j < m_slowing; j++)
            sum += raw_k_buffer[i-j];
         k_buffer[i] = sum / m_slowing;
        }
      for(int i = m_k_period - 1 + m_slowing - 1 + m_d_period - 1; i < rates_total; i++)
        {
         double sum = 0;
         for(int j = 0; j < m_d_period; j++)
            sum += k_buffer[i-j];
         d_buffer[i] = sum / m_d_period;
        }
     }
  }

//+------------------------------------------------------------------+
bool CStochasticRoofingCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CStochasticRoofingCalculator_HA : public CStochasticRoofingCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticRoofingCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
