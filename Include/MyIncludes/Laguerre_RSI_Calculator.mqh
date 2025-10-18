//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|    Calculation engine for Standard and Heikin Ashi Laguerre RSI. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CLaguerreRSICalculator (Base Class)           |
//|                                                                  |
//+==================================================================+
class CLaguerreRSICalculator
  {
protected:
   double            m_gamma;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreRSICalculator(void) {};
   virtual          ~CLaguerreRSICalculator(void) {};

   bool              Init(double gamma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[]);
  };

//+------------------------------------------------------------------+
//| CLaguerreRSICalculator: Initialization                           |
//+------------------------------------------------------------------+
bool CLaguerreRSICalculator::Init(double gamma)
  {
   m_gamma = fmax(0.0, fmin(1.0, gamma)); // Ensure gamma is between 0 and 1
   return true;
  }

//+------------------------------------------------------------------+
//| CLaguerreRSICalculator: Main Calculation Method (Shared Logic)   |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &lrsi_buffer[])
  {
   if(rates_total < 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Initialize filter components for the first bar ---
   double L0 = m_price[0], L1 = m_price[0], L2 = m_price[0], L3 = m_price[0];
   double L0_prev = m_price[0], L1_prev = m_price[0], L2_prev = m_price[0], L3_prev = m_price[0];

// --- Full recalculation loop for stability ---
   for(int i = 1; i < rates_total; i++)
     {
      // --- Recursive Laguerre Filter Calculation ---
      L0 = (1.0 - m_gamma) * m_price[i] + m_gamma * L0_prev;
      L1 = -m_gamma * L0 + L0_prev + m_gamma * L1_prev;
      L2 = -m_gamma * L1 + L1_prev + m_gamma * L2_prev;
      L3 = -m_gamma * L2 + L2_prev + m_gamma * L3_prev;

      // --- RSI-like calculation based on filter components ---
      double cu = 0.0; // Count Up
      double cd = 0.0; // Count Down

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
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0; // Fallback to previous value or 50

      // --- NEW: Clamp the value to the [0, 100] range ---
      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;

      lrsi_buffer[i] = lrsi_value;

      // --- Update previous values for the next iteration ---
      L0_prev = L0;
      L1_prev = L1;
      L2_prev = L2;
      L3_prev = L3;
     }
  }

//+------------------------------------------------------------------+
//| CLaguerreRSICalculator: Prepares the standard source price.      |
//+------------------------------------------------------------------+
bool CLaguerreRSICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|                                                                  |
//|           CLASS 2: CLaguerreRSICalculator_HA (Heikin Ashi)       |
//|                                                                  |
//+==================================================================+
class CLaguerreRSICalculator_HA : public CLaguerreRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CLaguerreRSICalculator_HA: Prepares the HA source price.         |
//+------------------------------------------------------------------+
bool CLaguerreRSICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
