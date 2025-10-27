//+------------------------------------------------------------------+
//|                                    HighPass_2P_Calculator.mqh    |
//|      Calculation engine for Ehlers' 2-Pole High-Pass Filter.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CHighPass2P_Calculator
  {
protected:
   double            m_price[];

   // Filter coefficients
   double            c0, a1, a2;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CHighPass2P_Calculator(void) {};
   virtual          ~CHighPass2P_Calculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &hp_buffer[]);
  };

//+------------------------------------------------------------------+
bool CHighPass2P_Calculator::Init(int period)
  {
   if(period < 2)
      period = 2;

// Pre-calculate filter coefficients
   double beta = 2.451 * (1.0 - cos(2.0 * M_PI / period));
   double alpha = -beta + sqrt(beta * beta + 2.0 * beta);

   c0 = pow(1.0 - alpha / 2.0, 2);
   a1 = 2.0 * (1.0 - alpha);
   a2 = -pow(1.0 - alpha, 2);

   return true;
  }

//+------------------------------------------------------------------+
void CHighPass2P_Calculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &hp_buffer[])
  {
   if(rates_total < 3)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double hp1=0, hp2=0; // State variables for HP[1], HP[2]

// Initialization
   hp_buffer[0] = 0;
   hp_buffer[1] = 0;

   for(int i = 2; i < rates_total; i++)
     {
      // HP = c0*(Price - 2*Price[1] + Price[2]) + a1*HP[1] + a2*HP[2]
      double input_term = c0 * (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]);
      double feedback_term = a1 * hp1 + a2 * hp2;

      double current_hp = input_term + feedback_term;
      hp_buffer[i] = current_hp;

      hp2 = hp1;
      hp1 = current_hp;
     }
  }

//+------------------------------------------------------------------+
bool CHighPass2P_Calculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CHighPass2P_Calculator_HA : public CHighPass2P_Calculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CHighPass2P_Calculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
