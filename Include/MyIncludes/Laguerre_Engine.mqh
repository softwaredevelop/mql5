//+------------------------------------------------------------------+
//|                                             Laguerre_Engine.mqh  |
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
class CLaguerreEngine
  {
protected:
   double            m_gamma;
   ENUM_INPUT_SOURCE m_source_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_L0[], m_L1[], m_L2[], m_L3[]; // Internal state buffers

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreEngine(void) {};
   virtual          ~CLaguerreEngine(void) {};

   bool              Init(double gamma, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              CalculateFilter(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                     double &filt_buffer[]);

   void              GetPriceBuffer(double &dest_array[]);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreEngine::Init(double gamma, ENUM_INPUT_SOURCE source_type)
  {
   m_gamma = fmax(0.0, fmin(1.0, gamma));
   m_source_type = source_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Get Price Buffer (Helper for FIR filter)                         |
//+------------------------------------------------------------------+
void CLaguerreEngine::GetPriceBuffer(double &dest_array[])
  {
   int size = ArraySize(m_price);
   if(size > 0)
     {
      ArrayResize(dest_array, size);
      ArrayCopy(dest_array, m_price, 0, 0, size);
     }
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CLaguerreEngine::CalculateFilter(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &filt_buffer[])
  {
   if(rates_total < 2)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_L0, rates_total);
      ArrayResize(m_L1, rates_total);
      ArrayResize(m_L2, rates_total);
      ArrayResize(m_L3, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Laguerre Filter
// We need to handle the very first bar separately for initialization
   int i = start_index;

   if(i == 0)
     {
      m_L0[0] = m_price[0];
      m_L1[0] = m_price[0];
      m_L2[0] = m_price[0];
      m_L3[0] = m_price[0];
      filt_buffer[0] = (m_L0[0] + 2.0 * m_L1[0] + 2.0 * m_L2[0] + m_L3[0]) / 6.0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      // Recursive calculation uses [i-1] from persistent buffers
      // This is safe even if we recalculate the last bar multiple times
      double L0_prev = m_L0[i-1];
      double L1_prev = m_L1[i-1];
      double L2_prev = m_L2[i-1];
      double L3_prev = m_L3[i-1];

      m_L0[i] = (1.0 - m_gamma) * m_price[i] + m_gamma * L0_prev;
      m_L1[i] = -m_gamma * m_L0[i] + L0_prev + m_gamma * L1_prev;
      m_L2[i] = -m_gamma * m_L1[i] + L1_prev + m_gamma * L2_prev;
      m_L3[i] = -m_gamma * m_L2[i] + L2_prev + m_gamma * L3_prev;

      filt_buffer[i] = (m_L0[i] + 2.0 * m_L1[i] + 2.0 * m_L2[i] + m_L3[i]) / 6.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CLaguerreEngine::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
        {
         switch(price_type)
           {
            case PRICE_OPEN:
               m_price[i] = open[i];
               break;
            case PRICE_HIGH:
               m_price[i] = high[i];
               break;
            case PRICE_LOW:
               m_price[i] = low[i];
               break;
            case PRICE_MEDIAN:
               m_price[i] = (high[i]+low[i])/2.0;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (high[i]+low[i]+close[i])/3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
               break;
            default:
               m_price[i] = close[i];
               break;
           }
        }
      else // SOURCE_MOMENTUM
        {
         m_price[i] = close[i] - open[i];
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CLaguerreEngine_HA (Heikin Ashi)            |
//+==================================================================+
class CLaguerreEngine_HA : public CLaguerreEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CLaguerreEngine_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
        {
         switch(price_type)
           {
            case PRICE_OPEN:
               m_price[i] = m_ha_open[i];
               break;
            case PRICE_HIGH:
               m_price[i] = m_ha_high[i];
               break;
            case PRICE_LOW:
               m_price[i] = m_ha_low[i];
               break;
            case PRICE_MEDIAN:
               m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
               break;
            default:
               m_price[i] = m_ha_close[i];
               break;
           }
        }
      else // SOURCE_MOMENTUM
        {
         m_price[i] = m_ha_close[i] - m_ha_open[i];
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
