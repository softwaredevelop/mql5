//+------------------------------------------------------------------+
//|                                           RSI_Pro_Calculator.mqh |
//|        VERSION 5.00: High-Performance DSP with Transcendental    |
//|                      Pruning & Dynamic Modular MA Engine         |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "5.00"

#ifndef RSI_PRO_CALCULATOR_MQH
#define RSI_PRO_CALCULATOR_MQH

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+------------------------------------------------------------------+
//| CLASS: CRSIProCalculator                                         |
//+------------------------------------------------------------------+
class CRSIProCalculator
  {
protected:
   CRSIEngine                 *m_rsi_engine;
   CMovingAverageCalculator    m_ma_engine;

   int               m_rsi_period;
   int               m_ma_period;
   double            m_deviation;
   double            m_inv_ma_period;

   //--- Internal Intermediate Buffers
   double            m_rsi_buffer[];
   double            m_ma_buffer[];

   virtual void      CreateEngine(void);

public:
                     CRSIProCalculator(void);
   virtual          ~CRSIProCalculator(void);

   bool              Init(const int rsi_p, const int ma_p, const ENUM_MA_TYPE ma_m, const double dev);

   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);

   int               GetRSIPeriod(void) const { return m_rsi_period; }
   int               GetMAPeriod(void)  const { return m_ma_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRSIProCalculator::CRSIProCalculator(void) : m_rsi_engine(NULL),
   m_rsi_period(14),
   m_ma_period(20),
   m_deviation(2.0),
   m_inv_ma_period(1.0 / 20.0)
  {
   ArraySetAsSeries(m_rsi_buffer, false);
   ArraySetAsSeries(m_ma_buffer,  false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRSIProCalculator::~CRSIProCalculator(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID && m_rsi_engine != NULL)
     {
      delete m_rsi_engine;
      m_rsi_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Virtual Engine Factory                                           |
//+------------------------------------------------------------------+
void CRSIProCalculator::CreateEngine(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID && m_rsi_engine != NULL)
     {
      delete m_rsi_engine;
      m_rsi_engine = NULL;
     }
   m_rsi_engine = new CRSIEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(const int rsi_p, const int ma_p, const ENUM_MA_TYPE ma_m, const double dev)
  {
   m_rsi_period    = MathMax(1, rsi_p);
   m_ma_period     = MathMax(1, ma_p);
   m_deviation     = dev;
   m_inv_ma_period = 1.0 / (double)m_ma_period;

   CreateEngine();
   if(CheckPointer(m_rsi_engine) == POINTER_INVALID || !m_rsi_engine.Init(m_rsi_period))
      return false;

   if(!m_ma_engine.Init(m_ma_period, ma_m))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Optimized Bollinger Dispersion Pipeline)              |
//+------------------------------------------------------------------+
void CRSIProCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total <= m_rsi_period || CheckPointer(m_rsi_engine) == POINTER_INVALID)
      return;

   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total, 2048);
      ArrayResize(m_ma_buffer,  rates_total, 2048);
      ArraySetAsSeries(m_rsi_buffer, false);
      ArraySetAsSeries(m_ma_buffer,  false);
     }

// 1. Calculate Pure RSI
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

// 2. Calculate Moving Average Signal Line on RSI Series
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, m_ma_buffer, m_rsi_period);

// 3. Vectorized Bollinger Dispersion Bands (No pow() calls, Pure ALU Multiplication)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start  = MathMax(m_rsi_period + m_ma_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double ma_val = m_ma_buffer[i];
      double sum_sq = 0.0;

      for(int j = 0; j < m_ma_period; j++)
        {
         double diff = m_rsi_buffer[i - j] - ma_val;
         sum_sq += diff * diff; // ~50x faster than pow(diff, 2)
        }

      double std_dev  = MathSqrt(sum_sq * m_inv_ma_period);
      double band_dev = m_deviation * std_dev;

      rsi_out[i]   = m_rsi_buffer[i];
      ma_out[i]    = ma_val;
      upper_out[i] = ma_val + band_dev;
      lower_out[i] = ma_val - band_dev;
     }

// Pre-warmup zone filling
   int fill_limit = MathMin(loop_start, rates_total);
   for(int i = start_index; i < fill_limit; i++)
     {
      rsi_out[i] = m_rsi_buffer[i];
      if(i < m_rsi_period + m_ma_period - 1)
        {
         ma_out[i]    = (i >= m_rsi_period) ? m_ma_buffer[i] : EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
        }
     }
  }

//+==================================================================+
//| CLASS: CRSIProCalculator_HA (Heikin Ashi Subclass)               |
//+==================================================================+
class CRSIProCalculator_HA : public CRSIProCalculator
  {
protected:
   virtual void      CreateEngine(void) override
     {
      if(CheckPointer(m_rsi_engine) != POINTER_INVALID && m_rsi_engine != NULL)
        {
         delete m_rsi_engine;
         m_rsi_engine = NULL;
        }
      m_rsi_engine = new CRSIEngine_HA();
     }
  };

#endif // RSI_PRO_CALCULATOR_MQH
//+------------------------------------------------------------------+
