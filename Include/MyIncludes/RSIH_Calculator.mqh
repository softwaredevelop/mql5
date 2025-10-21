//+------------------------------------------------------------------+
//|                                              RSIH_Calculator.mqh |
//|    Calculation engine for Ehlers' RSI with Hann Windowing (RSIH) |
//|    and Noise Elimination Technology (NET).                       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CRSIHCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CRSIHCalculator
  {
protected:
   int               m_period_rsi;
   int               m_period_net;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CRSIHCalculator(void) {};
   virtual          ~CRSIHCalculator(void) {};

   bool              Init(int rsi_period, int net_period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsih_buffer[], double &net_buffer[]);
  };

//+------------------------------------------------------------------+
bool CRSIHCalculator::Init(int rsi_period, int net_period)
  {
   m_period_rsi = (rsi_period < 2) ? 2 : rsi_period;
   m_period_net = (net_period < 2) ? 2 : net_period;
   return true;
  }

//+------------------------------------------------------------------+
void CRSIHCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                double &rsih_buffer[], double &net_buffer[])
  {
   if(rates_total < m_period_rsi + 1)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Step 1: Calculate the base RSIH indicator ---
   for(int i = m_period_rsi; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;
      for(int j = 1; j <= m_period_rsi; j++)
        {
         double diff = m_price[i - j + 1] - m_price[i - j];
         double weight = 1.0 - cos(2 * M_PI * j / (m_period_rsi + 1.0));
         if(diff > 0)
            cu += diff * weight;
         else
            cd += -diff * weight;
        }
      if(cu + cd > 0)
         rsih_buffer[i] = (cu - cd) / (cu + cd);
      else
         rsih_buffer[i] = (i > 0) ? rsih_buffer[i-1] : 0.0;
     }

// --- Step 2: Apply Noise Elimination Technology (NET) ---
   if(m_period_net > 0)
     {
      double denominator = 0.5 * m_period_net * (m_period_net - 1);
      if(denominator <= 0)
         return;

      for(int i = m_period_rsi + m_period_net; i < rates_total; i++)
        {
         double numerator = 0;
         // Double loop for Kendall correlation
         for(int j = 1; j < m_period_net; j++)
           {
            for(int k = 0; k < j; k++)
              {
               // Ehlers' simplified formula is Num = Num - Sign(X[count] - X[K])
               // This implies adding the sign of (X[fresher] - X[older])
               // In our arrays, i-k is fresher than i-j
               double diff = rsih_buffer[i-k] - rsih_buffer[i-j];
               // CORRECTED: Use addition instead of subtraction to match Ehlers' logic
               numerator += (diff > 0 ? 1 : (diff < 0 ? -1 : 0));
              }
           }
         net_buffer[i] = numerator / denominator;
        }
     }
  }

//+------------------------------------------------------------------+
bool CRSIHCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CRSIHCalculator_HA : public CRSIHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CRSIHCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
