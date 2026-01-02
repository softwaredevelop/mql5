//+------------------------------------------------------------------+
//|                                             VIDYA_Calculator.mqh |
//|      VERSION 4.00: Integrated with CMO Engine.                   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\CMO_Engine.mqh> // Include CMO Engine

//+==================================================================+
//|             CLASS 1: CVIDYACalculator (Base Class)               |
//+==================================================================+
class CVIDYACalculator
  {
protected:
   int               m_cmo_period, m_ema_period;

   //--- Composition: Use dedicated CMO engine
   CCMOEngine        *m_cmo_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_cmo_buffer[]; // Internal buffer for CMO values

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Factory Method for CMO Engine
   virtual void      CreateCMOEngine(void);

public:
                     CVIDYACalculator(void);
   virtual          ~CVIDYACalculator(void);

   bool              Init(int cmo_p, int ema_p);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_buffer[]);

   int               GetPeriod(void) const { return m_cmo_period + m_ema_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVIDYACalculator::CVIDYACalculator(void)
  {
   m_cmo_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVIDYACalculator::~CVIDYACalculator(void)
  {
   if(CheckPointer(m_cmo_engine) != POINTER_INVALID)
      delete m_cmo_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CVIDYACalculator::CreateCMOEngine(void)
  {
   m_cmo_engine = new CCMOEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVIDYACalculator::Init(int cmo_p, int ema_p)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   m_ema_period = (ema_p < 1) ? 1 : ema_p;

   CreateCMOEngine();
   if(CheckPointer(m_cmo_engine) == POINTER_INVALID || !m_cmo_engine.Init(m_cmo_period))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CVIDYACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                 double &vidya_buffer[])
  {
   int start_pos = m_cmo_period + m_ema_period;
   if(rates_total <= start_pos)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(ArraySize(m_cmo_buffer) != rates_total)
      ArrayResize(m_cmo_buffer, rates_total);

// 1. Prepare Price (for VIDYA calculation)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Calculate CMO (Delegated to Engine)
// Note: CMO engine handles its own price preparation internally!
// We pass the raw OHLC arrays and price_type.
   m_cmo_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_cmo_buffer);

// 3. Calculate VIDYA (Incremental Loop)
   double alpha = 2.0 / (m_ema_period + 1.0);
   int loop_start = MathMax(start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == start_pos) // Initialization
        {
         double sum=0;
         for(int j=0; j<m_ema_period; j++)
            sum+=m_price[i-j];
         vidya_buffer[i]=sum/m_ema_period;
         continue;
        }

      // Use pre-calculated CMO from buffer
      double cmo_abs = MathAbs(m_cmo_buffer[i] / 100.0); // CMO is 0-100, we need 0-1 ratio

      // Recursive calculation uses vidya_buffer[i-1] which is persistent
      vidya_buffer[i] = m_price[i] * alpha * cmo_abs + vidya_buffer[i-1] * (1 - alpha * cmo_abs);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CVIDYACalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
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
   return true;
  }

//+==================================================================+
//|             CLASS 2: CVIDYACalculator_HA (Heikin Ashi)           |
//+==================================================================+
class CVIDYACalculator_HA : public CVIDYACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
   virtual void      CreateCMOEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Method for HA CMO Engine                                 |
//+------------------------------------------------------------------+
void CVIDYACalculator_HA::CreateCMOEngine(void)
  {
   m_cmo_engine = new CCMOEngine_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CVIDYACalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
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
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
