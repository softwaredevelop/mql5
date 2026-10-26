//+------------------------------------------------------------------+
//|                          ChaosWeightedStochastic_Calculator.mqh  |
//|      Engine for Fractal-Chaos-Weighted Stochastic Oscillator     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.00" // Enterprise Edition: Range-Based Candle Source Architecture (Standard vs Heikin Ashi)
#property description "Mathematical engine for Stochastic Oscillator with Sevcik Fractal Chaos modulation."

#ifndef CHAOS_WEIGHTED_STOCHASTIC_CALCULATOR_MQH
#define CHAOS_WEIGHTED_STOCHASTIC_CALCULATOR_MQH

#include <MyIncludes\Fractal_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Candle Source Selection (Standard Suite Convention)
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Standard raw OHLC candles
   CANDLE_HEIKIN_ASHI    // Heikin Ashi smoothed candles
  };
#endif

//+==================================================================+
//|             CLASS: CChaosWeightedStochastic_Calculator           |
//+==================================================================+
class CChaosWeightedStochastic_Calculator
  {
private:
   int                       m_k_period;
   int                       m_slowing_period;
   int                       m_fdi_period;
   double                    m_sensitivity;
   ENUM_CANDLE_SOURCE        m_candle_source;
   double                    m_base_alpha;

   // Embedded Central DSP Engines
   CFractalEngine            m_fractal_engine;
   CMovingAverageCalculator  m_signal_engine;
   CHeikinAshi_Calculator    m_ha_engine;

   // Persistent Working Buffers
   double                    m_src_open[];
   double                    m_src_high[];
   double                    m_src_low[];
   double                    m_src_close[];
   double                    m_raw_k[];
   double                    m_k[];
   double                    m_double_volume[];

   bool                      PrepareSourceData(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);
   double                    Highest(const int period, const int current_pos) const;
   double                    Lowest(const int period, const int current_pos) const;

public:
                     CChaosWeightedStochastic_Calculator(void);
                    ~CChaosWeightedStochastic_Calculator(void);

   bool                      Init(const int k_period, const int slowing_period, const int d_period,
                                  const ENUM_MA_TYPE d_ma, const int fdi_period, const double sensitivity,
                                  const ENUM_CANDLE_SOURCE candle_source = CANDLE_STANDARD);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_k[], double &out_d[], const int history_limit = 0);

   int                       GetWarmupBars(void) const { return MathMax(m_k_period + m_slowing_period, m_fdi_period) + 5; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChaosWeightedStochastic_Calculator::CChaosWeightedStochastic_Calculator(void) :
   m_k_period(14),
   m_slowing_period(3),
   m_fdi_period(20),
   m_sensitivity(1.0),
   m_candle_source(CANDLE_STANDARD),
   m_base_alpha(0.5)
  {
   ArraySetAsSeries(m_src_open,      false);
   ArraySetAsSeries(m_src_high,      false);
   ArraySetAsSeries(m_src_low,       false);
   ArraySetAsSeries(m_src_close,     false);
   ArraySetAsSeries(m_raw_k,         false);
   ArraySetAsSeries(m_k,             false);
   ArraySetAsSeries(m_double_volume, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChaosWeightedStochastic_Calculator::~CChaosWeightedStochastic_Calculator(void)
  {
   ArrayFree(m_src_open);
   ArrayFree(m_src_high);
   ArrayFree(m_src_low);
   ArrayFree(m_src_close);
   ArrayFree(m_raw_k);
   ArrayFree(m_k);
   ArrayFree(m_double_volume);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CChaosWeightedStochastic_Calculator::Init(const int k_period, const int slowing_period, const int d_period,
      const ENUM_MA_TYPE d_ma, const int fdi_period, const double sensitivity,
      const ENUM_CANDLE_SOURCE candle_source)
  {
   m_k_period       = (k_period < 1) ? 1 : k_period;
   m_slowing_period = (slowing_period < 1) ? 1 : slowing_period;
   m_fdi_period     = (fdi_period < 5) ? 5 : fdi_period;
   m_sensitivity    = (sensitivity <= 0.0) ? 1.0 : sensitivity;
   m_candle_source  = candle_source;

   m_base_alpha     = 2.0 / (double)(m_slowing_period + 1.0);

   if(!m_fractal_engine.Init(m_fdi_period, FDI_CANONICAL_SEVCIK))
      return false;

   if(!m_signal_engine.Init(d_period, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Full Candle Triplet (Standard High/Low/Close vs HA)      |
//+------------------------------------------------------------------+
bool CChaosWeightedStochastic_Calculator::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_src_close) != rates_total)
     {
      ArrayResize(m_src_open,      rates_total, 2048);
      ArrayResize(m_src_high,      rates_total, 2048);
      ArrayResize(m_src_low,       rates_total, 2048);
      ArrayResize(m_src_close,     rates_total, 2048);
      ArrayResize(m_double_volume, rates_total, 2048);
      ArraySetAsSeries(m_src_open,      false);
      ArraySetAsSeries(m_src_high,      false);
      ArraySetAsSeries(m_src_low,       false);
      ArraySetAsSeries(m_src_close,     false);
      ArraySetAsSeries(m_double_volume, false);
     }

   if(m_candle_source == CANDLE_HEIKIN_ASHI)
     {
      // Direct in-place Heikin Ashi calculation
      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_src_open, m_src_high, m_src_low, m_src_close);
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         m_src_open[i]  = open[i];
         m_src_high[i]  = high[i];
         m_src_low[i]   = low[i];
         m_src_close[i] = close[i];
        }
     }

   for(int i = start_index; i < rates_total; i++)
      m_double_volume[i] = 1.0;

   return true;
  }

//+------------------------------------------------------------------+
//| Extremes Helpers                                                 |
//+------------------------------------------------------------------+
double CChaosWeightedStochastic_Calculator::Highest(const int period, const int current_pos) const
  {
   double res = m_src_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      double val = m_src_high[current_pos - i];
      if(val > res)
         res = val;
     }
   return res;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CChaosWeightedStochastic_Calculator::Lowest(const int period, const int current_pos) const
  {
   double res = m_src_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      double val = m_src_low[current_pos - i];
      if(val < res)
         res = val;
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Main Incremental Execution Loop (O(1) Live Ticks)                |
//+------------------------------------------------------------------+
void CChaosWeightedStochastic_Calculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_k[], double &out_d[], const int history_limit)
  {
   int warmup = GetWarmupBars();
   if(rates_total < warmup)
      return;

   if(ArraySize(out_k) != rates_total)
     {
      ArrayResize(out_k, rates_total, 2048);
      ArrayResize(out_d, rates_total, 2048);
      ArraySetAsSeries(out_k, false);
      ArraySetAsSeries(out_d, false);
     }

   if(ArraySize(m_raw_k) != rates_total)
     {
      int old_sz = ArraySize(m_raw_k);
      ArrayResize(m_raw_k, rates_total, 2048);
      ArrayResize(m_k,     rates_total, 2048);
      ArraySetAsSeries(m_raw_k, false);
      ArraySetAsSeries(m_k,     false);

      if(old_sz == 0 || prev_calculated == 0)
        {
         ArrayInitialize(m_raw_k, 50.0);
         ArrayInitialize(m_k,     50.0);
        }
      else
        {
         for(int j = old_sz; j < rates_total; j++)
           {
            m_raw_k[j] = 50.0;
            m_k[j]     = 50.0;
           }
        }
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PrepareSourceData(rates_total, start_prep, open, high, low, close))
      return;

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : (m_k_period - 1);
   int actual_start = m_k_period - 1;

   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start)
        {
         start = limit_start;
         actual_start = limit_start;
        }
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start; i++)
        {
         m_raw_k[i] = 50.0;
         m_k[i]     = 50.0;
         out_k[i]   = 50.0;
         out_d[i]   = 50.0;
        }
     }

// 1. Calculate Raw %K and Chaos-Modulated Adaptive Slowing (%K)
   for(int i = start; i < rates_total; i++)
     {
      double highest_h = Highest(m_k_period, i);
      double lowest_l  = Lowest(m_k_period, i);
      double range     = highest_h - lowest_l;

      if(range > 1.0e-9)
         m_raw_k[i] = ((m_src_close[i] - lowest_l) / range) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;

      // Evaluate Fractal Chaos on Close series
      double chaos = m_fractal_engine.CalculateChaosPoint(i, m_fdi_period, m_src_close);

      // Adaptive Slowing Alpha: Accelerates in Trend, Freezes in Chop!
      double adjusted_alpha = m_base_alpha * MathPow(1.0 - chaos, m_sensitivity);
      adjusted_alpha = MathMax(0.005, MathMin(1.0, adjusted_alpha));

      if(i == actual_start || m_k[i - 1] == EMPTY_VALUE)
         m_k[i] = m_raw_k[i];
      else
         m_k[i] = m_k[i - 1] + adjusted_alpha * (m_raw_k[i] - m_k[i - 1]);

      out_k[i] = m_k[i];
     }

// 2. Compute %D Signal Line via Unified Moving Average Engine
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, out_k, m_double_volume, out_d, actual_start);
  }

#endif // CHAOS_WEIGHTED_STOCHASTIC_CALCULATOR_MQH
//+------------------------------------------------------------------+
