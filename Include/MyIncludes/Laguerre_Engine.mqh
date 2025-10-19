//+------------------------------------------------------------------+
//|                                             Laguerre_Engine.mqh  |
//|      Core calculation engine for the Laguerre filter series.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CLaguerreEngine (Base Class)                |
//|                                                                  |
//+==================================================================+
class CLaguerreEngine
  {
protected:
   double            m_gamma;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreEngine(void) {};
   virtual          ~CLaguerreEngine(void) {};

   bool              Init(double gamma);
   void              CalculateFilter(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                     double &L0_buffer[], double &L1_buffer[], double &L2_buffer[], double &L3_buffer[], double &filt_buffer[]);
   // --- NEW: Public getter to safely access the prepared price data ---
   void              GetPriceBuffer(double &dest_array[]);
  };

//+------------------------------------------------------------------+
//| CLaguerreEngine: Public getter for the internal price buffer.    |
//+------------------------------------------------------------------+
void CLaguerreEngine::GetPriceBuffer(double &dest_array[])
  {
   int size = ArraySize(m_price);
   ArrayResize(dest_array, size);
   ArrayCopy(dest_array, m_price, 0, 0, size);
  }

//+------------------------------------------------------------------+
//| CLaguerreEngine: Initialization                                  |
//+------------------------------------------------------------------+
bool CLaguerreEngine::Init(double gamma)
  {
   m_gamma = fmax(0.0, fmin(1.0, gamma)); // Ensure gamma is between 0 and 1
   return true;
  }

//+------------------------------------------------------------------+
//| CLaguerreEngine: Core Filter Calculation                         |
//+------------------------------------------------------------------+
void CLaguerreEngine::CalculateFilter(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &L0_buffer[], double &L1_buffer[], double &L2_buffer[], double &L3_buffer[], double &filt_buffer[])
  {
   if(rates_total < 2)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   ArrayResize(L0_buffer, rates_total);
   ArrayResize(L1_buffer, rates_total);
   ArrayResize(L2_buffer, rates_total);
   ArrayResize(L3_buffer, rates_total);
   ArrayResize(filt_buffer, rates_total);

// --- Initialize filter components for the first bar ---
   double L0_prev = m_price[0], L1_prev = m_price[0], L2_prev = m_price[0], L3_prev = m_price[0];
   L0_buffer[0] = m_price[0];
   L1_buffer[0] = m_price[0];
   L2_buffer[0] = m_price[0];
   L3_buffer[0] = m_price[0];
   filt_buffer[0] = m_price[0];

// --- Full recalculation loop for stability ---
   for(int i = 1; i < rates_total; i++)
     {
      // --- Recursive Laguerre Filter Calculation ---
      L0_buffer[i] = (1.0 - m_gamma) * m_price[i] + m_gamma * L0_prev;
      L1_buffer[i] = -m_gamma * L0_buffer[i] + L0_prev + m_gamma * L1_prev;
      L2_buffer[i] = -m_gamma * L1_buffer[i] + L1_prev + m_gamma * L2_prev;
      L3_buffer[i] = -m_gamma * L2_buffer[i] + L2_prev + m_gamma * L3_prev;

      // --- NEW: Calculate the final weighted filter output ---
      filt_buffer[i] = (L0_buffer[i] + 2.0 * L1_buffer[i] + 2.0 * L2_buffer[i] + L3_buffer[i]) / 6.0;

      // --- Update previous values for the next iteration ---
      L0_prev = L0_buffer[i];
      L1_prev = L1_buffer[i];
      L2_prev = L2_buffer[i];
      L3_prev = L3_buffer[i];
     }
  }

//+------------------------------------------------------------------+
//| CLaguerreEngine: Prepares the standard source price.             |
//+------------------------------------------------------------------+
bool CLaguerreEngine::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|           CLASS 2: CLaguerreEngine_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CLaguerreEngine_HA : public CLaguerreEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CLaguerreEngine_HA: Prepares the HA source price.                |
//+------------------------------------------------------------------+
bool CLaguerreEngine_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
