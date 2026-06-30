//+------------------------------------------------------------------+
//|                  StochasticSlow_on_LaguerreRSI_Calculator.mqh    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.22" // Upgraded with strict internal chronological sorting safeguards

#ifndef STOCHASTIC_SLOW_ON_LAGUERRE_RSI_CALCULATOR_MQH
#define STOCHASTIC_SLOW_ON_LAGUERRE_RSI_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CStochasticSlowOnLaguerreRSICalculator        |
//+==================================================================+
class CStochasticSlowOnLaguerreRSICalculator
  {
protected:
   int               m_k_period;

   //--- Composition
   CLaguerreEngine          *m_laguerre_engine; // For RSI calculation
   CMovingAverageCalculator m_slowing_engine;   // For Slow %K
   CMovingAverageCalculator m_signal_engine;    // For %D

   //--- Internal Buffers
   double            m_rsi_buffer[]; // Stores Laguerre RSI
   double            m_raw_k[];      // Stores Fast %K

   virtual void      CreateEngine(void);

   //--- Helpers
   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochasticSlowOnLaguerreRSICalculator(void);
   virtual          ~CStochasticSlowOnLaguerreRSICalculator(void);

   bool              Init(double gamma, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma);

   //--- Standard Calculate (Without volume)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Overloaded Calculate (With volume to support VWMA Slowing/Signal)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &slow_k_buffer[], double &signal_d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticSlowOnLaguerreRSICalculator::CStochasticSlowOnLaguerreRSICalculator(void)
  {
   m_laguerre_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticSlowOnLaguerreRSICalculator::~CStochasticSlowOnLaguerreRSICalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreRSICalculator::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticSlowOnLaguerreRSICalculator::Init(double gamma, int k_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;

   CreateEngine();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_k_period)
      return;

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

//--- Resize Internal Buffers & force strict chronological indexing
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_rsi_buffer, false); // Fixed: strict chronological safety on internal buffers
      ArraySetAsSeries(m_raw_k, false);      // Fixed: strict chronological safety on internal buffers
     }

//--- 1. Calculate Laguerre RSI (Inline Logic)
   double dummy_filt[];
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

   double L0[], L1[], L2[], L3[];
   m_laguerre_engine.GetLBuffers(L0, L1, L2, L3);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 1;
   if(start_index < 1)
      start_index = 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;
      if(L0[i] >= L1[i])
         cu = L0[i] - L1[i];
      else
         cd = L1[i] - L0[i];
      if(L1[i] >= L2[i])
         cu += L1[i] - L2[i];
      else
         cd += L2[i] - L1[i];
      if(L2[i] >= L3[i])
         cu += L2[i] - L3[i];
      else
         cd += L3[i] - L2[i];

      if(cu + cd > 0.0)
         m_rsi_buffer[i] = 100.0 * cu / (cu + cd);
      else
         m_rsi_buffer[i] = (i > 0) ? m_rsi_buffer[i-1] : 50.0;
     }

//--- 2. Calculate Raw %K (Stochastic on RSI)
   int k_start = MathMax(m_k_period, start_index);

   for(int i = k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Calculate Slow %K (Main Line)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, m_k_period);

//--- 4. Calculate %D (Signal Line)
   int d_offset = m_k_period + m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (With Volume)                                          |
//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   if(rates_total < m_k_period)
      return;

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID)
      return;

//--- Resize Internal Buffers & force strict chronological indexing
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
      ArraySetAsSeries(m_rsi_buffer, false); // Fixed: strict chronological safety on internal buffers
      ArraySetAsSeries(m_raw_k, false);      // Fixed: strict chronological safety on internal buffers
     }

//--- 1. Calculate Laguerre RSI (Inline Logic)
   double dummy_filt[];
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

   double L0[], L1[], L2[], L3[];
   m_laguerre_engine.GetLBuffers(L0, L1, L2, L3);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 1;
   if(start_index < 1)
      start_index = 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;
      if(L0[i] >= L1[i])
         cu = L0[i] - L1[i];
      else
         cd = L1[i] - L0[i];
      if(L1[i] >= L2[i])
         cu += L1[i] - L2[i];
      else
         cd += L2[i] - L1[i];
      if(L2[i] >= L3[i])
         cu += L2[i] - L3[i];
      else
         cd += L3[i] - L2[i];

      if(cu + cd > 0.0)
         m_rsi_buffer[i] = 100.0 * cu / (cu + cd);
      else
         m_rsi_buffer[i] = (i > 0) ? m_rsi_buffer[i-1] : 50.0;
     }

//--- 2. Calculate Raw %K (Stochastic on RSI)
   int k_start = MathMax(m_k_period, start_index);

   for(int i = k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 3. Convert long volume to double to support VWMA Slowing & Signal
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false); // Fixed: strict chronological array safety on local buffers
   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

//--- 4. Calculate Slow %K (Smoothing Raw %K with Volume)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, vol_double, slow_k_buffer, m_k_period);

//--- 5. Calculate %D (Signal Line with Volume)
   int d_offset = m_k_period + m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, vol_double, signal_d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Highest Helper                                                   |
//+------------------------------------------------------------------+
double CStochasticSlowOnLaguerreRSICalculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res < array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+------------------------------------------------------------------+
//| Lowest Helper                                                    |
//+------------------------------------------------------------------+
double CStochasticSlowOnLaguerreRSICalculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      if(current_pos - i < 0)
         break;
      if(res > array[current_pos - i])
         res = array[current_pos - i];
     }
   return res;
  }

//+==================================================================+
//|           CLASS 2: CStochasticSlowOnLaguerreRSICalculator_HA     |
//+==================================================================+
class CStochasticSlowOnLaguerreRSICalculator_HA : public CStochasticSlowOnLaguerreRSICalculator
  {
protected:
   virtual void      CreateEngine(void) override;
  };

//+------------------------------------------------------------------+
void CStochasticSlowOnLaguerreRSICalculator_HA::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
  }

#endif // STOCHASTIC_SLOW_ON_LAGUERRE_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
