//+------------------------------------------------------------------+
//|                  StochasticFast_on_LaguerreRSI_Calculator.mqh    |
//|      Fast Stochastic Oscillator applied to Laguerre RSI.         |
//|      VERSION 1.00: Strictly O(1) and VWMA compatible.            |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef STOCHASTIC_FAST_ON_LAGUERRE_RSI_CALCULATOR_MQH
#define STOCHASTIC_FAST_ON_LAGUERRE_RSI_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|      CLASS: CStochasticFastOnLaguerreRSICalculator (Base)        |
//+==================================================================+
class CStochasticFastOnLaguerreRSICalculator
  {
protected:
   int               m_k_period;

   //--- Composition
   CLaguerreEngine          *m_laguerre_engine; // For RSI calculation
   CMovingAverageCalculator *m_signal_engine;    // For %D Signal Line

   //--- Internal Buffers
   double            m_rsi_buffer[]; // Stores Laguerre RSI

   virtual void      CreateEngine(void);

   //--- Helpers
   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochasticFastOnLaguerreRSICalculator(void);
   virtual          ~CStochasticFastOnLaguerreRSICalculator(void);

   bool              Init(double gamma, int k_p, int d_p, ENUM_MA_TYPE d_ma);

   //--- Standard Calculate (Without volume)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);

   //--- Overloaded Calculate (With volume for VWMA support)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticFastOnLaguerreRSICalculator::CStochasticFastOnLaguerreRSICalculator(void)
  {
   m_laguerre_engine = NULL;
   m_signal_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticFastOnLaguerreRSICalculator::~CStochasticFastOnLaguerreRSICalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochasticFastOnLaguerreRSICalculator::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
   m_signal_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticFastOnLaguerreRSICalculator::Init(double gamma, int k_p, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_k_period = (k_p < 1) ? 1 : k_p;

   CreateEngine();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   if(CheckPointer(m_signal_engine) == POINTER_INVALID || !m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CStochasticFastOnLaguerreRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_k_period)
      return;

//--- Resize Internal Buffers
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
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

//--- 2. Calculate Fast %K (Stochastic on RSI directly into k_buffer)
   int k_start = MathMax(m_k_period, start_index);

   for(int i = k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         k_buffer[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 3. Calculate %D Signal Line (Smoothing Fast %K)
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, m_k_period);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA Signal)             |
//+------------------------------------------------------------------+
void CStochasticFastOnLaguerreRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_k_period)
      return;

//--- Resize Internal Buffers
   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
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

//--- 2. Calculate Fast %K (Stochastic on RSI directly into k_buffer)
   int k_start = MathMax(m_k_period, start_index);

   for(int i = k_start; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         k_buffer[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 3. Convert long volume to double to support VWMA Signal
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

//--- 4. Calculate %D Signal Line (Smoothing Fast %K with Volume)
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, vol_double, d_buffer, m_k_period);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double CStochasticFastOnLaguerreRSICalculator::Highest(const double &array[], int period, int current_pos)
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
//|                                                                  |
//+------------------------------------------------------------------+
double CStochasticFastOnLaguerreRSICalculator::Lowest(const double &array[], int period, int current_pos)
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
//|      CLASS 2: CStochasticFastOnLaguerreRSICalculator_HA          |
//+==================================================================+
class CStochasticFastOnLaguerreRSICalculator_HA : public CStochasticFastOnLaguerreRSICalculator
  {
protected:
   virtual void      CreateEngine(void) override;
  };

//+------------------------------------------------------------------+
void CStochasticFastOnLaguerreRSICalculator_HA::CreateEngine(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
   m_signal_engine = new CMovingAverageCalculator();
  }
//+------------------------------------------------------------------+
#endif // STOCHASTIC_FAST_ON_LAGUERRE_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+