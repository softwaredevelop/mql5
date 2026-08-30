//+------------------------------------------------------------------+
//|                               Stochastic_Adaptive_Calculator.mqh |
//|      Engine for Frank Key's Variable-Length Adaptive Stochastic  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified HA composition, bounds safety & VWMA support

#ifndef STOCHASTIC_ADAPTIVE_CALCULATOR_MQH
#define STOCHASTIC_ADAPTIVE_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CStochasticAdaptiveCalculator               |
//+==================================================================+
class CStochasticAdaptiveCalculator
  {
protected:
   int                       m_er_period;
   int                       m_min_period;
   int                       m_max_period;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Smoothing Engines
   CMovingAverageCalculator  m_slowing_engine;
   CMovingAverageCalculator  m_signal_engine;

   //--- Composition Engine
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_er_buffer[];
   double                    m_nsp_buffer[];
   double                    m_raw_k[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CStochasticAdaptiveCalculator(void);
   virtual                  ~CStochasticAdaptiveCalculator(void) {};

   //--- Enhanced Pro Init (8 Parameters)
   bool                      Init(const int er_p, const int min_p, const int max_p,
                                  const int slow_p, const ENUM_MA_TYPE slow_ma,
                                  const int d_p, const ENUM_MA_TYPE d_ma,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (7 Parameters)
   bool                      Init(const int er_p, const int min_p, const int max_p,
                                  const int slow_p, const ENUM_MA_TYPE slow_ma,
                                  const int d_p, const ENUM_MA_TYPE d_ma)
     {
      return Init(er_p, min_p, max_p, slow_p, slow_ma, d_p, d_ma, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculation Method (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &k_buffer[], double &d_buffer[]);

   //--- Modern Unified Calculation Method (With Volume for VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &k_buffer[], double &d_buffer[]);

   //--- Legacy Overload with price_type parameter (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       double &k_buffer[], double &d_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, k_buffer, d_buffer);
     }

   //--- Legacy Overload with price_type parameter (With Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       const long &volume[],
                                       double &k_buffer[], double &d_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, volume, k_buffer, d_buffer);
     }

   int                       GetRequiredWarmup(void) const { return m_er_period + m_max_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticAdaptiveCalculator::CStochasticAdaptiveCalculator(void) : m_er_period(10),
   m_min_period(5),
   m_max_period(30),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,      false);
   ArraySetAsSeries(m_er_buffer,  false);
   ArraySetAsSeries(m_nsp_buffer, false);
   ArraySetAsSeries(m_raw_k,      false);
   ArraySetAsSeries(m_ha_open,    false);
   ArraySetAsSeries(m_ha_high,    false);
   ArraySetAsSeries(m_ha_low,     false);
   ArraySetAsSeries(m_ha_close,   false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveCalculator::Init(const int er_p, const int min_p, const int max_p,
      const int slow_p, const ENUM_MA_TYPE slow_ma,
      const int d_p, const ENUM_MA_TYPE d_ma,
      const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_er_period    = (er_p < 1) ? 1 : er_p;
   m_min_period   = (min_p < 1) ? 1 : min_p;
   m_max_period   = (max_p <= m_min_period) ? (m_min_period + 1) : max_p;
   m_source_price = price_source;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveCalculator::PreparePriceSeries(const int rates_total, const int start_index,
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
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
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
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CStochasticAdaptiveCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup)
      return;

// Safe allocation of destination arrays
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,      rates_total);
      ArrayResize(m_er_buffer,  rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k,      rates_total);

      ArraySetAsSeries(m_price,      false);
      ArraySetAsSeries(m_er_buffer,  false);
      ArraySetAsSeries(m_nsp_buffer, false);
      ArraySetAsSeries(m_raw_k,      false);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Efficiency Ratio (ER)
   int loop_start_er = MathMax(m_er_period, start_index);

   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0.0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);

      m_er_buffer[i] = (volatility > 1.0e-9) ? (direction / volatility) : 0.0;
      m_nsp_buffer[i] = (int)(m_er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(m_nsp_buffer[i] < m_min_period)
         m_nsp_buffer[i] = m_min_period;
      if(m_nsp_buffer[i] > m_max_period)
         m_nsp_buffer[i] = m_max_period;
     }

// 2. Calculate Raw Adaptive %K
   int raw_k_start = m_er_period + m_max_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_price[i];
      double lowest  = m_price[i];

      for(int j = 1; j < current_nsp; j++)
        {
         int idx = i - j;
         if(idx < 0)
            break;
         highest = MathMax(highest, m_price[idx]);
         lowest  = MathMin(lowest,  m_price[idx]);
        }

      double range = highest - lowest;
      if(range > 1.0e-9)
         m_raw_k[i] = ((m_price[i] - lowest) / range) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

// 3. Smooth K and D (Without Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CStochasticAdaptiveCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const long &volume[],
      double &k_buffer[], double &d_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup)
      return;

// Safe allocation of destination arrays
   if(ArraySize(k_buffer) != rates_total)
     {
      ArrayResize(k_buffer, rates_total);
      ArraySetAsSeries(k_buffer, false);
      ArrayInitialize(k_buffer, EMPTY_VALUE);
     }
   if(ArraySize(d_buffer) != rates_total)
     {
      ArrayResize(d_buffer, rates_total);
      ArraySetAsSeries(d_buffer, false);
      ArrayInitialize(d_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,      rates_total);
      ArrayResize(m_er_buffer,  rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k,      rates_total);

      ArraySetAsSeries(m_price,      false);
      ArraySetAsSeries(m_er_buffer,  false);
      ArraySetAsSeries(m_nsp_buffer, false);
      ArraySetAsSeries(m_raw_k,      false);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Efficiency Ratio (ER)
   int loop_start_er = MathMax(m_er_period, start_index);

   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0.0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);

      m_er_buffer[i] = (volatility > 1.0e-9) ? (direction / volatility) : 0.0;
      m_nsp_buffer[i] = (int)(m_er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(m_nsp_buffer[i] < m_min_period)
         m_nsp_buffer[i] = m_min_period;
      if(m_nsp_buffer[i] > m_max_period)
         m_nsp_buffer[i] = m_max_period;
     }

// 2. Calculate Raw Adaptive %K
   int raw_k_start = m_er_period + m_max_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_price[i];
      double lowest  = m_price[i];

      for(int j = 1; j < current_nsp; j++)
        {
         int idx = i - j;
         if(idx < 0)
            break;
         highest = MathMax(highest, m_price[idx]);
         lowest  = MathMin(lowest,  m_price[idx]);
        }

      double range = highest - lowest;
      if(range > 1.0e-9)
         m_raw_k[i] = ((m_price[i] - lowest) / range) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

// 3. Convert volume to double array for VWMA support
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);

   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

// 4. Smooth K and D (With Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, vol_double, k_buffer, raw_k_start);
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, vol_double, d_buffer, d_offset);
  }

//+==================================================================+
//|             CLASS 2: CStochasticAdaptiveCalculator_HA            |
//+==================================================================+
class CStochasticAdaptiveCalculator_HA : public CStochasticAdaptiveCalculator
  {
public:
                     CStochasticAdaptiveCalculator_HA(void)
     {
      m_source_price = PRICE_HA_CLOSE;
     }
  };

#endif // STOCHASTIC_ADAPTIVE_CALCULATOR_MQH
//+------------------------------------------------------------------+
