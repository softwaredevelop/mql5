//+------------------------------------------------------------------+
//|                                   Roofing_Filter_Calculator.mqh  |
//|      Calculation engine for the John Ehlers' Roofing Filter.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CRoofingFilterCalculator (Base Class)         |
//|                                                                  |
//+==================================================================+
class CRoofingFilterCalculator
  {
protected:
   int               m_hp_period; // High-Pass Period
   int               m_ss_period; // SuperSmoother Period
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRoofingFilterCalculator(void) {};
   virtual          ~CRoofingFilterCalculator(void) {};

   bool              Init(int hp_period, int ss_period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &roofing_buffer[]);
  };

//+------------------------------------------------------------------+
bool CRoofingFilterCalculator::Init(int hp_period, int ss_period)
  {
   m_hp_period = (hp_period < 10) ? 10 : hp_period;
   m_ss_period = (ss_period < 2) ? 2 : ss_period;
   return true;
  }

//+------------------------------------------------------------------+
void CRoofingFilterCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &roofing_buffer[])
  {
   if(rates_total < 10)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Intermediate buffer for the High-Pass filter output ---
   double hp_buffer[];
   ArrayResize(hp_buffer, rates_total);

// --- High-Pass Filter Coefficients ---
   double arg_hp = 0.707 * 2 * M_PI / m_hp_period;
   double alpha1_hp = (cos(arg_hp) + sin(arg_hp) - 1.0) / cos(arg_hp);

// --- SuperSmoother Filter Coefficients ---
   double arg_ss = 1.414 * M_PI / m_ss_period;
   double a1_ss = exp(-arg_ss);
   double b1_ss = 2.0 * a1_ss * cos(arg_ss);
   double c2_ss = b1_ss;
   double c3_ss = -a1_ss * a1_ss;
   double c1_ss = 1.0 - c2_ss - c3_ss;

// --- State variables for recursive calculations ---
   double hp1=0, hp2=0;     // High-Pass previous values
   double filt1=0, filt2=0; // SuperSmoother (Filt) previous values

// --- Full recalculation loop ---
   for(int i = 0; i < rates_total; i++)
     {
      // Initialization period
      if(i < 3)
        {
         hp_buffer[i] = 0;
         roofing_buffer[i] = 0;
         continue;
        }

      // --- Step 1: Calculate High-Pass filter value ---
      double term1_hp = pow(1.0 - alpha1_hp / 2.0, 2) * (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]);
      double term2_hp = 2.0 * (1.0 - alpha1_hp) * hp1;
      double term3_hp = pow(1.0 - alpha1_hp, 2) * hp2;
      double current_hp = term1_hp + term2_hp - term3_hp;
      hp_buffer[i] = current_hp;

      // --- Step 2: Calculate SuperSmoother on the High-Pass output ---
      double current_filt = c1_ss * (hp_buffer[i] + hp_buffer[i-1]) / 2.0 + c2_ss * filt1 + c3_ss * filt2;
      roofing_buffer[i] = current_filt;

      // --- Update state variables for next iteration ---
      hp2 = hp1;
      hp1 = current_hp;
      filt2 = filt1;
      filt1 = current_filt;
     }
  }

//+------------------------------------------------------------------+
bool CRoofingFilterCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CRoofingFilterCalculator_HA : public CRoofingFilterCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CRoofingFilterCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
