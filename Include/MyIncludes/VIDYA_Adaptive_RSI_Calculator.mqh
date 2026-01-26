//+------------------------------------------------------------------+
//|                                VIDYA_Adaptive_RSI_Calculator.mqh |
//|      VIDYA calculation using Adaptive RSI as volatility index.   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\RSI_Adaptive_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CVIDYAAdaptiveRSICalculator (Base)            |
//+==================================================================+
class CVIDYAAdaptiveRSICalculator
  {
protected:
   int               m_ema_period;

   //--- Composition
   CAdaptiveRSICalculator *m_arsi_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_arsi_buffer[]; // Stores Adaptive RSI

   virtual void      CreateEngine(void);
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVIDYAAdaptiveRSICalculator(void);
   virtual          ~CVIDYAAdaptiveRSICalculator(void);

   bool              Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src, int ema_p);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVIDYAAdaptiveRSICalculator::CVIDYAAdaptiveRSICalculator(void)
  {
   m_arsi_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVIDYAAdaptiveRSICalculator::~CVIDYAAdaptiveRSICalculator(void)
  {
   if(CheckPointer(m_arsi_engine) != POINTER_INVALID)
      delete m_arsi_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CVIDYAAdaptiveRSICalculator::CreateEngine(void)
  {
   m_arsi_engine = new CAdaptiveRSICalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVIDYAAdaptiveRSICalculator::Init(int pivotal_p, int vola_s, int vola_l, ENUM_ADAPTIVE_SOURCE_RSI adapt_src, int ema_p)
  {
   m_ema_period = (ema_p < 1) ? 1 : ema_p;

   CreateEngine();
   if(CheckPointer(m_arsi_engine) == POINTER_INVALID || !m_arsi_engine.Init(pivotal_p, vola_s, vola_l, adapt_src))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CVIDYAAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &vidya_buffer[])
  {
// Minimum bars check (approximate)
   if(rates_total <= m_ema_period + 20)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_arsi_buffer, rates_total);
     }

// 1. Prepare Price (for VIDYA calculation)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Calculate Adaptive RSI (Delegated)
// The engine handles its own price preparation for RSI calculation
   m_arsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_arsi_buffer);

// 3. Calculate VIDYA (Incremental Loop)
   double alpha = 2.0 / (m_ema_period + 1.0);

// Start where we have valid ARSI data (approximate, ARSI engine handles safety inside)
// We need to start loop early enough to catch up, but respect array bounds
   int loop_start = MathMax(1, start_index);

// Initialization for the very first bar
   if(loop_start == 1)
     {
      vidya_buffer[0] = m_price[0];
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // Volatility factor: distance from 50 (0..50), normalized to 0..1
      // ARSI is 0..100
      double rsi_volatility = MathAbs(m_arsi_buffer[i] - 50.0) / 50.0;

      // Recursive calculation
      // VIDYA = Alpha * Vola * Price + (1 - Alpha * Vola) * VIDYA[i-1]
      double k = alpha * rsi_volatility;
      vidya_buffer[i] = k * m_price[i] + (1.0 - k) * vidya_buffer[i-1];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CVIDYAAdaptiveRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CVIDYAAdaptiveRSICalculator_HA                |
//+==================================================================+
class CVIDYAAdaptiveRSICalculator_HA : public CVIDYAAdaptiveRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      CreateEngine(void) override;
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CVIDYAAdaptiveRSICalculator_HA::CreateEngine(void)
  {
   m_arsi_engine = new CAdaptiveRSICalculator_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CVIDYAAdaptiveRSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
