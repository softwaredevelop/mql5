//+------------------------------------------------------------------+
//|                               MACD_SuperSmoother_Calculator.mqh  |
//|      VERSION 2.00: Unified calculator for ALL SS MACD inds.      |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

enum ENUM_SMOOTHING_METHOD
  {
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA,
   SMOOTH_SuperSmoother
  };

//+==================================================================+
//|           CLASS 1: CMACDSuperSmootherCalculator (Base)           |
//+==================================================================+
class CMACDSuperSmootherCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_SMOOTHING_METHOD m_signal_ma_type;

   //--- Engines
   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;
   CEhlersSmootherCalculator *m_signal_smoother;
   CMovingAverageCalculator  *m_signal_ma_engine;

   //--- Persistent Internal Buffers
   double            m_fast_buffer[];
   double            m_slow_buffer[];
   double            m_macd_internal[];
   double            m_signal_internal[];
   double            m_hist_internal[];

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);

public:
                     CMACDSuperSmootherCalculator(void);
   virtual          ~CMACDSuperSmootherCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_SMOOTHING_METHOD signal_type);

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_out[], double &signal_out[], double &hist_out[]);

   //--- Wrapper for Histogram Only
   void              CalculateHistogramOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
         double &hist_out[]);

   //--- Wrapper for MACD Line Only
   void              CalculateMACDLineOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                           double &macd_out[]);
  };

//+------------------------------------------------------------------+
//|           CLASS 2: CMACDSuperSmootherCalculator_HA               |
//+------------------------------------------------------------------+
class CMACDSuperSmootherCalculator_HA : public CMACDSuperSmootherCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::CMACDSuperSmootherCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
   m_signal_smoother = NULL;
   m_signal_ma_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::~CMACDSuperSmootherCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
   if(CheckPointer(m_signal_smoother) != POINTER_INVALID)
      delete m_signal_smoother;
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDSuperSmootherCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_SMOOTHING_METHOD signal_type)
  {
   if(fast_p > slow_p)
     {
      int temp=fast_p;
      fast_p=slow_p;
      slow_p=temp;
     }
   m_fast_period = fast_p;
   m_slow_period = slow_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_type;

   m_fast_smoother = CreateSmootherInstance();
   m_slow_smoother = CreateSmootherInstance();

   if(CheckPointer(m_fast_smoother) == POINTER_INVALID || !m_fast_smoother.Init(m_fast_period, SUPERSMOOTHER, SOURCE_PRICE) ||
      CheckPointer(m_slow_smoother) == POINTER_INVALID || !m_slow_smoother.Init(m_slow_period, SUPERSMOOTHER, SOURCE_PRICE))
      return false;

   if(m_signal_ma_type == SMOOTH_SuperSmoother)
     {
      m_signal_smoother = new CEhlersSmootherCalculator();
      if(!m_signal_smoother.Init(m_signal_period, SUPERSMOOTHER, SOURCE_PRICE))
         return false;
     }
   else
     {
      m_signal_ma_engine = new CMovingAverageCalculator();
      ENUM_MA_TYPE ma_type = (ENUM_MA_TYPE)m_signal_ma_type;
      if(!m_signal_ma_engine.Init(m_signal_period, ma_type))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_out[], double &signal_out[], double &hist_out[])
  {
   if(rates_total < m_slow_period + m_signal_period)
      return;

// Resize persistent internal buffers
   if(ArraySize(m_fast_buffer) != rates_total)
     {
      ArrayResize(m_fast_buffer, rates_total);
      ArrayResize(m_slow_buffer, rates_total);
      ArrayResize(m_macd_internal, rates_total);
      ArrayResize(m_signal_internal, rates_total);
      ArrayResize(m_hist_internal, rates_total);
     }

// 1. Calculate Fast and Slow Smoothers
   m_fast_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_fast_buffer);
   m_slow_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_slow_buffer);

// 2. Calculate MACD Line
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_index; i < rates_total; i++)
      m_macd_internal[i] = m_fast_buffer[i] - m_slow_buffer[i];

// 3. Calculate Signal Line
   if(m_signal_ma_type == SMOOTH_SuperSmoother)
     {
      m_signal_smoother.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                  m_macd_internal, m_macd_internal, m_macd_internal, m_macd_internal,
                                  m_signal_internal);
     }
   else
     {
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_macd_internal, m_signal_internal, m_slow_period);
     }

// 4. Calculate Histogram & Output
   for(int i = start_index; i < rates_total; i++)
     {
      m_hist_internal[i] = m_macd_internal[i] - m_signal_internal[i];

      if(ArraySize(macd_out) == rates_total)
         macd_out[i] = m_macd_internal[i];
      if(ArraySize(signal_out) == rates_total)
         signal_out[i] = m_signal_internal[i];
      if(ArraySize(hist_out) == rates_total)
         hist_out[i] = m_hist_internal[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate Histogram Only                                         |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::CalculateHistogramOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &hist_out[])
  {
   double dummy_macd[], dummy_signal[];
   Calculate(rates_total, prev_calculated, open, high, low, close, price_type, dummy_macd, dummy_signal, hist_out);
  }

//+------------------------------------------------------------------+
//| Calculate MACD Line Only                                         |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::CalculateMACDLineOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_out[])
  {
   double dummy_signal[], dummy_hist[];
   Calculate(rates_total, prev_calculated, open, high, low, close, price_type, macd_out, dummy_signal, dummy_hist);
  }
//+------------------------------------------------------------------+
