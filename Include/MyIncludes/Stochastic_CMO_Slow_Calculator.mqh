//+------------------------------------------------------------------+
//|                                 Stochastic_CMO_Slow_Calculator.mqh |
//|      VERSION 3.00: Integrated with CMO Engine.                   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CMO_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochasticCMOSlowCalculator                    |
//+==================================================================+
class CStochasticCMOSlowCalculator
  {
protected:
   int               m_cmo_period, m_k_period;

   //--- Engines
   CCMOEngine        *m_cmo_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_cmo_buffer[];
   double            m_raw_k[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Factory Method for CMO Engine
   virtual void      CreateCMOEngine(void);

public:
                     CStochasticCMOSlowCalculator(void);
   virtual          ~CStochasticCMOSlowCalculator(void);

   //--- Init now takes ENUM_MA_TYPE for both smoothings
   bool              Init(int cmo_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::CStochasticCMOSlowCalculator(void)
  {
   m_cmo_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticCMOSlowCalculator::~CStochasticCMOSlowCalculator(void)
  {
   if(CheckPointer(m_cmo_engine) != POINTER_INVALID)
      delete m_cmo_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator::CreateCMOEngine(void)
  {
   m_cmo_engine = new CCMOEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator::Init(int cmo_p, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_cmo_period = (cmo_p < 1) ? 1 : cmo_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;

   CreateCMOEngine();
   if(CheckPointer(m_cmo_engine) == POINTER_INVALID || !m_cmo_engine.Init(m_cmo_period))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check
   int min_bars = m_cmo_period + m_k_period + m_slowing_engine.GetPeriod() + m_signal_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(ArraySize(m_cmo_buffer) != rates_total)
      ArrayResize(m_cmo_buffer, rates_total);
   if(ArraySize(m_raw_k) != rates_total)
      ArrayResize(m_raw_k, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate CMO (Delegated to Engine)
   m_cmo_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_cmo_buffer);

//--- 2. Calculate Raw %K (Fast %K) on CMO
// CMO valid from: m_cmo_period
// Raw %K valid from: m_cmo_period + m_k_period - 1
   int raw_k_start = m_cmo_period + m_k_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_cmo = Highest(m_cmo_buffer, m_k_period, i);
      double lowest_cmo  = Lowest(m_cmo_buffer, m_k_period, i);
      double range = highest_cmo - lowest_cmo;

      if(range > 0.00001)
         m_raw_k[i] = (m_cmo_buffer[i] - lowest_cmo) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Calculate Slow %K (Main Line) using Slowing Engine
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);

//--- 4. Calculate %D (Signal Line) using Signal Engine
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochasticCMOSlowCalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochasticCMOSlowCalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CStochasticCMOSlowCalculator_HA             |
//+==================================================================+
class CStochasticCMOSlowCalculator_HA : public CStochasticCMOSlowCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
   virtual void      CreateCMOEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Method for HA CMO Engine                                 |
//+------------------------------------------------------------------+
void CStochasticCMOSlowCalculator_HA::CreateCMOEngine(void)
  {
   m_cmo_engine = new CCMOEngine_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CStochasticCMOSlowCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
