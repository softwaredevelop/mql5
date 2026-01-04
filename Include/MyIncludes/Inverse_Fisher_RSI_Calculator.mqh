//+------------------------------------------------------------------+
//|                               Inverse_Fisher_RSI_Calculator.mqh  |
//|      Calculation engine for the Inverse Fisher Transform of RSI. |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|         CLASS 1: CInverseFisherRSICalculator (Base)              |
//+==================================================================+
class CInverseFisherRSICalculator
  {
protected:
   int               m_rsi_period;
   int               m_wma_period;

   //--- Engines
   CRSIProCalculator *m_rsi_calculator;
   CMovingAverageCalculator m_wma_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_rsi_buffer[];
   double            m_value1[]; // Scaled RSI
   double            m_value2[]; // Smoothed Scaled RSI

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Factory Method for RSI Engine
   virtual void      CreateRSIEngine(void);

public:
                     CInverseFisherRSICalculator(void);
   virtual          ~CInverseFisherRSICalculator(void);

   bool              Init(int rsi_period, int wma_period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ifish_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInverseFisherRSICalculator::CInverseFisherRSICalculator(void)
  {
   m_rsi_calculator = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CInverseFisherRSICalculator::~CInverseFisherRSICalculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CInverseFisherRSICalculator::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator::Init(int rsi_period, int wma_period)
  {
   m_rsi_period = (rsi_period < 2) ? 2 : rsi_period;
   m_wma_period = (wma_period < 1) ? 1 : wma_period;

   CreateRSIEngine();
// Init RSI with dummy MA params (1, SMA, 2.0) as we only need the RSI line
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID || !m_rsi_calculator.Init(m_rsi_period, 1, SMA, 2.0))
      return false;

// Init WMA Engine (LWMA)
   if(!m_wma_engine.Init(m_wma_period, LWMA))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CInverseFisherRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ifish_buffer[])
  {
   int start_pos = m_rsi_period + m_wma_period;
   if(rates_total <= start_pos)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_value1, rates_total);
      ArrayResize(m_value2, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate RSI (Delegated to Engine)
   double dummy1[], dummy2[], dummy3[];
// Note: RSI engine handles its own price preparation internally!
// We pass the raw OHLC arrays and price_type.
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                              m_rsi_buffer, dummy1, dummy2, dummy3);

//--- 2. Scale RSI (Incremental)
// RSI valid from: m_rsi_period
   int loop_start_scale = MathMax(m_rsi_period, start_index);

   for(int i = loop_start_scale; i < rates_total; i++)
     {
      // Scale RSI from 0..100 to -5..+5
      m_value1[i] = 0.1 * (m_rsi_buffer[i] - 50.0);
     }

//--- 3. Smooth with WMA (Using Engine)
// Offset: m_rsi_period
   m_wma_engine.CalculateOnArray(rates_total, prev_calculated, m_value1, m_value2, m_rsi_period);

//--- 4. Apply Inverse Fisher Transform (Incremental)
// Valid from: m_rsi_period + m_wma_period - 1
   int ifish_start = m_rsi_period + m_wma_period - 1;
   int loop_start_ifish = MathMax(ifish_start, start_index);

   for(int i = loop_start_ifish; i < rates_total; i++)
     {
      double x = m_value2[i];
      // Avoid overflow with exp(2x)
      if(x > 10)
         x = 10;
      if(x < -10)
         x = -10;

      double exp2x = exp(2.0 * x);
      ifish_buffer[i] = (exp2x - 1.0) / (exp2x + 1.0);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CInverseFisherRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// This method is just a placeholder for the base class.
// The RSI calculator handles its own data preparation internally.
   return true;
  }

//+==================================================================+
//|             CLASS 2: CInverseFisherRSICalculator_HA              |
//+==================================================================+
class CInverseFisherRSICalculator_HA : public CInverseFisherRSICalculator
  {
protected:
   virtual void      CreateRSIEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Method for HA RSI Engine                                 |
//+------------------------------------------------------------------+
void CInverseFisherRSICalculator_HA::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CRSIProCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
