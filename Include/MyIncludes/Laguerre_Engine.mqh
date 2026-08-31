//+------------------------------------------------------------------+
//|                                             Laguerre_Engine.mqh  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Upgraded with bounds safety, HA composition & state preservation

#ifndef LAGUERRE_ENGINE_MQH
#define LAGUERRE_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

#ifndef ENUM_INPUT_SOURCE_DEFINED
#define ENUM_INPUT_SOURCE_DEFINED
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };
#endif

//+==================================================================+
//|             CLASS 1: CLaguerreEngine (Base Class)                |
//+==================================================================+
class CLaguerreEngine
  {
protected:
   double                    m_gamma;
   ENUM_INPUT_SOURCE         m_source_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_L0[], m_L1[], m_L2[], m_L3[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   //--- Composition Engine
   CHeikinAshi_Calculator    m_ha_engine;

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CLaguerreEngine(void);
   virtual                  ~CLaguerreEngine(void) {};

   //--- Enhanced Pro Init (3 Parameters)
   bool                      Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (2 Parameters)
   bool                      Init(const double gamma, const ENUM_INPUT_SOURCE source_type)
     {
      return Init(gamma, source_type, PRICE_CLOSE_STD);
     }

   //--- Unified Calculate Method
   void                      CalculateFilter(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &filt_buffer[]);

   //--- Legacy Overload with price_type parameter
   void                      CalculateFilter(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &filt_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      CalculateFilter(rates_total, prev_calculated, open, high, low, close, filt_buffer);
     }

   void                      GetPriceBuffer(double &dest_array[]);
   double                    GetPrice(const int index) const { return (index >= 0 && index < ArraySize(m_price)) ? m_price[index] : 0.0; }
   void                      GetLBuffers(double &l0[], double &l1[], double &l2[], double &l3[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreEngine::CLaguerreEngine(void) : m_gamma(0.5),
   m_source_type(SOURCE_PRICE),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_L0,       false);
   ArraySetAsSeries(m_L1,       false);
   ArraySetAsSeries(m_L2,       false);
   ArraySetAsSeries(m_L3,       false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CLaguerreEngine::Init(const double gamma, const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_gamma        = fmax(0.0, fmin(1.0, gamma));
   m_source_type  = source_type;
   m_source_price = price_source;
   return true;
  }

//+------------------------------------------------------------------+
//| Get Price Buffer Helper                                          |
//+------------------------------------------------------------------+
void CLaguerreEngine::GetPriceBuffer(double &dest_array[])
  {
   int size = ArraySize(m_price);
   if(size > 0)
     {
      ArrayResize(dest_array, size);
      ArraySetAsSeries(dest_array, false);
      ArrayCopy(dest_array, m_price, 0, 0, size);
     }
  }

//+------------------------------------------------------------------+
//| Get L0..L3 State Buffers Helper                                  |
//+------------------------------------------------------------------+
void CLaguerreEngine::GetLBuffers(double &l0[], double &l1[], double &l2[], double &l3[])
  {
   int size = ArraySize(m_L0);
   if(size > 0)
     {
      ArrayResize(l0, size);
      ArraySetAsSeries(l0, false);
      ArrayCopy(l0, m_L0, 0, 0, size);
      ArrayResize(l1, size);
      ArraySetAsSeries(l1, false);
      ArrayCopy(l1, m_L1, 0, 0, size);
      ArrayResize(l2, size);
      ArraySetAsSeries(l2, false);
      ArrayCopy(l2, m_L2, 0, 0, size);
      ArrayResize(l3, size);
      ArraySetAsSeries(l3, false);
      ArrayCopy(l3, m_L3, 0, 0, size);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi / Momentum)         |
//+------------------------------------------------------------------+
bool CLaguerreEngine::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);

         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         if(m_source_type == SOURCE_PRICE)
           {
            switch(m_source_price)
              {
               case PRICE_HA_OPEN:
                  m_price[i] = m_ha_open[i];
                  break;
               case PRICE_HA_HIGH:
                  m_price[i] = m_ha_high[i];
                  break;
               case PRICE_HA_LOW:
                  m_price[i] = m_ha_low[i];
                  break;
               case PRICE_HA_MEDIAN:
                  m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
                  break;
               case PRICE_HA_TYPICAL:
                  m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
                  break;
               case PRICE_HA_WEIGHTED:
                  m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
                  break;
               case PRICE_HA_CLOSE:
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
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         if(m_source_type == SOURCE_PRICE)
           {
            switch(m_source_price)
              {
               case PRICE_OPEN_STD:
                  m_price[i] = open[i];
                  break;
               case PRICE_HIGH_STD:
                  m_price[i] = high[i];
                  break;
               case PRICE_LOW_STD:
                  m_price[i] = low[i];
                  break;
               case PRICE_MEDIAN_STD:
                  m_price[i] = (high[i] + low[i]) / 2.0;
                  break;
               case PRICE_TYPICAL_STD:
                  m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
                  break;
               case PRICE_WEIGHTED_STD:
                  m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
                  break;
               case PRICE_CLOSE_STD:
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
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Laguerre Filter Calculation                     |
//+------------------------------------------------------------------+
void CLaguerreEngine::CalculateFilter(const int rates_total, const int prev_calculated,
                                      const double &open[], const double &high[],
                                      const double &low[], const double &close[],
                                      double &filt_buffer[])
  {
   if(rates_total < 2)
      return;

// Safe allocation of internal state arrays
   if(ArraySize(m_L0) != rates_total)
     {
      ArrayResize(m_L0, rates_total);
      ArraySetAsSeries(m_L0, false);
      ArrayResize(m_L1, rates_total);
      ArraySetAsSeries(m_L1, false);
      ArrayResize(m_L2, rates_total);
      ArraySetAsSeries(m_L2, false);
      ArrayResize(m_L3, rates_total);
      ArraySetAsSeries(m_L3, false);
     }

// Safe allocation of destination array
   if(ArraySize(filt_buffer) != rates_total)
     {
      ArrayResize(filt_buffer, rates_total);
      ArraySetAsSeries(filt_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

   int i = start_index;

// Warmup seeding on fresh run
   if(i == 0)
     {
      m_L0[0] = m_price[0];
      m_L1[0] = m_price[0];
      m_L2[0] = m_price[0];
      m_L3[0] = m_price[0];
      filt_buffer[0] = m_price[0];
      i = 1;
     }

// Recursive 4-Element Laguerre Difference Equations
   for(; i < rates_total; i++)
     {
      double L0_prev = m_L0[i - 1];
      double L1_prev = m_L1[i - 1];
      double L2_prev = m_L2[i - 1];
      double L3_prev = m_L3[i - 1];

      m_L0[i] = (1.0 - m_gamma) * m_price[i] + m_gamma * L0_prev;
      m_L1[i] = -m_gamma * m_L0[i] + L0_prev + m_gamma * L1_prev;
      m_L2[i] = -m_gamma * m_L1[i] + L1_prev + m_gamma * L2_prev;
      m_L3[i] = -m_gamma * m_L2[i] + L2_prev + m_gamma * L3_prev;

      filt_buffer[i] = (m_L0[i] + 2.0 * m_L1[i] + 2.0 * m_L2[i] + m_L3[i]) / 6.0;
     }
  }

//+==================================================================+
//|             CLASS 2: CLaguerreEngine_HA (Legacy Wrapper)         |
//+==================================================================+
class CLaguerreEngine_HA : public CLaguerreEngine
  {
public:
                     CLaguerreEngine_HA(void)
     {
      m_source_price = PRICE_HA_CLOSE;
     }
  };

#endif // LAGUERRE_ENGINE_MQH
//+------------------------------------------------------------------+
