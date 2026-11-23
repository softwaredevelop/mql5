//+------------------------------------------------------------------+
//|                                   Roofing_Filter_Calculator.mqh  |
//|      DSP Engine for John Ehlers' Zero-Mean Roofing Filter        |
//|      VERSION 2.00: 2026 Enterprise Edition with Precomputed      |
//|                    DSP Matrix & True Incremental O(1) Pipeline   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef ROOFING_FILTER_CALCULATOR_MQH
#define ROOFING_FILTER_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//| CLASS 1: CRoofingFilterCalculator (Base Class)                   |
//+==================================================================+
class CRoofingFilterCalculator
  {
protected:
   int               m_hp_period; // High-Pass Period (removes spectral dilation)
   int               m_ss_period; // SuperSmoother Period (removes aliasing noise)

   //--- Precomputed Analytical High-Pass Coefficients (Ehlers 2013)
   double            m_alpha1_hp;
   double            m_hp_k0;
   double            m_hp_k1;
   double            m_hp_k2;

   //--- Precomputed Analytical SuperSmoother Coefficients
   double            m_c1_half_ss;
   double            m_c2_ss;
   double            m_c3_ss;

   //--- Persistent State Buffers
   double            m_price[];
   double            m_hp_buf[];
   double            m_roofing_internal[];

   //--- Synthetic Heikin Ashi Composition
   CHeikinAshi_Calculator m_ha_engine;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool      PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]);

   void              PrecomputeCoefficients(void);

public:
                     CRoofingFilterCalculator(void);
   virtual          ~CRoofingFilterCalculator(void) {}

   bool              Init(const int hp_period, const int ss_period);

   //--- Modern Unified Calculation Method (True Incremental O(1))
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &roofing_buffer[]);

   //--- 100% Backward Compatible Legacy Method (Overloaded without prev_calculated)
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &roofing_buffer[])
     {
      Calculate(rates_total, 0, price_type, open, high, low, close, roofing_buffer);
     }

   int               GetHPPeriod(void)   const { return m_hp_period; }
   int               GetSSPeriod(void)   const { return m_ss_period; }
   int               GetWarmupBars(void) const { return MathMax(m_hp_period, m_ss_period) + 3; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRoofingFilterCalculator::CRoofingFilterCalculator(void) : m_hp_period(48),
   m_ss_period(10),
   m_alpha1_hp(0.0),
   m_hp_k0(0.0),
   m_hp_k1(0.0),
   m_hp_k2(0.0),
   m_c1_half_ss(0.0),
   m_c2_ss(0.0),
   m_c3_ss(0.0)
  {
   ArraySetAsSeries(m_price,            false);
   ArraySetAsSeries(m_hp_buf,           false);
   ArraySetAsSeries(m_roofing_internal, false);
   ArraySetAsSeries(m_ha_open,          false);
   ArraySetAsSeries(m_ha_high,          false);
   ArraySetAsSeries(m_ha_low,           false);
   ArraySetAsSeries(m_ha_close,         false);
  }

//+------------------------------------------------------------------+
//| Precompute Analytical DSP Coefficients (Run Once in Init)        |
//+------------------------------------------------------------------+
void CRoofingFilterCalculator::PrecomputeCoefficients(void)
  {
// 1. High-Pass Filter Coefficients (Ehlers Listing 2)
   double arg_hp = 1.414 * M_PI / (double)m_hp_period;
   double cos_hp = MathCos(arg_hp);
   double sin_hp = MathSin(arg_hp);

   if(cos_hp != 0.0)
      m_alpha1_hp = (cos_hp + sin_hp - 1.0) / cos_hp;
   else
      m_alpha1_hp = 0.07;

   double half_alpha = 1.0 - 0.5 * m_alpha1_hp;
   m_hp_k0 = half_alpha * half_alpha; // Pre-squared
   m_hp_k1 = 2.0 * (1.0 - m_alpha1_hp);
   m_hp_k2 = (1.0 - m_alpha1_hp) * (1.0 - m_alpha1_hp);

// 2. SuperSmoother Filter Coefficients
   double arg_ss = M_SQRT2 * M_PI / (double)m_ss_period;
   double a1_ss  = MathExp(-arg_ss);
   double b1_ss  = 2.0 * a1_ss * MathCos(arg_ss);

   m_c2_ss      = b1_ss;
   m_c3_ss      = -a1_ss * a1_ss;
   double c1_ss = 1.0 - m_c2_ss - m_c3_ss;
   m_c1_half_ss = 0.5 * c1_ss;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRoofingFilterCalculator::Init(const int hp_period, const int ss_period)
  {
   m_hp_period = (hp_period < 10) ? 10 : hp_period;
   m_ss_period = (ss_period < 2)  ? 2  : ss_period;

   PrecomputeCoefficients();
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Data (Standard vs Synthetic Heikin Ashi)           |
//+------------------------------------------------------------------+
bool CRoofingFilterCalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| High-Performance Incremental Calculation (True O(1))             |
//+------------------------------------------------------------------+
void CRoofingFilterCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &roofing_buffer[])
  {
   if(rates_total < 10)
      return;

// Safe capacity allocation of destination buffer
   if(ArraySize(roofing_buffer) != rates_total)
     {
      ArrayResize(roofing_buffer, rates_total, 2048);
      ArraySetAsSeries(roofing_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize working buffers with memory reservation capacity
   if(ArraySize(m_hp_buf) != rates_total)
     {
      ArrayResize(m_hp_buf,           rates_total, 2048);
      ArrayResize(m_roofing_internal, rates_total, 2048);

      ArraySetAsSeries(m_hp_buf,           false);
      ArraySetAsSeries(m_roofing_internal, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(2, start_index);

// Deterministic seeding for bars 0, 1
   if(prev_calculated == 0)
     {
      m_hp_buf[0]           = 0.0;
      m_hp_buf[1]           = 0.0;
      m_roofing_internal[0] = 0.0;
      m_roofing_internal[1] = 0.0;
      roofing_buffer[0]     = 0.0;
      roofing_buffer[1]     = 0.0;
      loop_start = 2;
     }

// 2-Stage Cascaded Pipelined Execution
   for(int i = loop_start; i < rates_total; i++)
     {
      // Stage 1: 2-Pole HighPass Filter (Removes Spectral Dilation -> Zero Mean!)
      double hp = m_hp_k0 * (m_price[i] - 2.0 * m_price[i - 1] + m_price[i - 2]) +
                  m_hp_k1 * m_hp_buf[i - 1] -
                  m_hp_k2 * m_hp_buf[i - 2];

      m_hp_buf[i] = hp;

      // Stage 2: 2-Pole SuperSmoother Filter (Removes Aliasing Noise)
      double filt = m_c1_half_ss * (hp + m_hp_buf[i - 1]) +
                    m_c2_ss * m_roofing_internal[i - 1] +
                    m_c3_ss * m_roofing_internal[i - 2];

      m_roofing_internal[i] = filt;
      roofing_buffer[i]     = filt;
     }
  }

//+==================================================================+
//| CLASS 2: CRoofingFilterCalculator_HA (Heikin Ashi Subclass)      |
//+==================================================================+
class CRoofingFilterCalculator_HA : public CRoofingFilterCalculator
  {
protected:
   virtual bool      PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Direct In-Place DSP)                |
//+------------------------------------------------------------------+
bool CRoofingFilterCalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total, 2048);
      ArrayResize(m_ha_high,  rates_total, 2048);
      ArrayResize(m_ha_low,   rates_total, 2048);
      ArrayResize(m_ha_close, rates_total, 2048);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                         m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // ROOFING_FILTER_CALCULATOR_MQH
//+------------------------------------------------------------------+
