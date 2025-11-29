//+------------------------------------------------------------------+
//|                       MACD_SuperSmoother_Histogram_Calculator.mqh|
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

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
class CMACDSuperSmootherHistogramCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_SMOOTHING_METHOD m_signal_ma_type;

   //--- Engines
   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;
   CEhlersSmootherCalculator *m_signal_smoother;
   CMovingAverageCalculator  *m_signal_ma_engine;

   //--- Persistent buffers for intermediate calculations
   double            m_fast_buffer[];
   double            m_slow_buffer[];

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);

public:
                     CMACDSuperSmootherHistogramCalculator(void);
   virtual          ~CMACDSuperSmootherHistogramCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_SMOOTHING_METHOD signal_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &histogram[]);
  };

//+------------------------------------------------------------------+
class CMACDSuperSmootherHistogramCalculator_HA : public CMACDSuperSmootherHistogramCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherHistogramCalculator::CMACDSuperSmootherHistogramCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
   m_signal_smoother = NULL;
   m_signal_ma_engine = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherHistogramCalculator::~CMACDSuperSmootherHistogramCalculator(void)
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
//|                                                                  |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherHistogramCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherHistogramCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDSuperSmootherHistogramCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_SMOOTHING_METHOD signal_type)
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
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherHistogramCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &histogram[])
  {
   if(rates_total < m_slow_period + m_signal_period)
      return;

//--- Resize persistent internal buffers
   if(ArraySize(m_fast_buffer) != rates_total)
      ArrayResize(m_fast_buffer, rates_total);
   if(ArraySize(m_slow_buffer) != rates_total)
      ArrayResize(m_slow_buffer, rates_total);

//--- Calculate Fast and Slow Smoothers (Incremental)
   m_fast_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_fast_buffer);
   m_slow_smoother.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_slow_buffer);

//--- Calculate MACD Line
   double macd_line[];
   ArrayResize(macd_line, rates_total);

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start_index; i < rates_total; i++)
      macd_line[i] = m_fast_buffer[i] - m_slow_buffer[i];

//--- Calculate Signal Line
   double signal_line[];
   ArrayResize(signal_line, rates_total);

   if(m_signal_ma_type == SMOOTH_SuperSmoother)
     {
      m_signal_smoother.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                  macd_line, macd_line, macd_line, macd_line,
                                  signal_line);
     }
   else
     {
      m_signal_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                   macd_line, macd_line, macd_line, macd_line,
                                   signal_line);
     }

//--- Calculate Histogram
   for(int i = start_index; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }
//+------------------------------------------------------------------+
