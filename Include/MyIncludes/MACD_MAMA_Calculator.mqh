//+------------------------------------------------------------------+
//|                                         MACD_MAMA_Calculator.mqh |
//|      MACD calculation using MAMA and FAMA.                       |
//|      VERSION 1.10: Added Histogram/Line Only wrappers.           |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\MAMA_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CMACDMAMACalculator (Base)                    |
//+==================================================================+
class CMACDMAMACalculator
  {
protected:
   //--- Composition
   CMAMACalculator          *m_mama_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Internal Buffers
   double            m_mama_buf[];
   double            m_fama_buf[];
   double            m_macd_buf[];
   double            m_signal_buf[];
   double            m_hist_buf[];

   virtual void      CreateMAMAEngine(void);

public:
                     CMACDMAMACalculator(void);
   virtual          ~CMACDMAMACalculator(void);

   bool              Init(double fast_limit, double slow_limit, int signal_period, ENUM_MA_TYPE signal_method);

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &macd_out[], double &signal_out[], double &hist_out[]);

   //--- Wrappers
   void              CalculateHistogramOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
         double &hist_out[]);
   void              CalculateMACDLineOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                           double &macd_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDMAMACalculator::CMACDMAMACalculator(void)
  {
   m_mama_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDMAMACalculator::~CMACDMAMACalculator(void)
  {
   if(CheckPointer(m_mama_engine) != POINTER_INVALID)
      delete m_mama_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CMACDMAMACalculator::CreateMAMAEngine(void)
  {
   m_mama_engine = new CMAMACalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDMAMACalculator::Init(double fast_limit, double slow_limit, int signal_period, ENUM_MA_TYPE signal_method)
  {
   CreateMAMAEngine();

   if(CheckPointer(m_mama_engine) == POINTER_INVALID || !m_mama_engine.Init(fast_limit, slow_limit))
      return false;

   if(!m_signal_engine.Init(signal_period, signal_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CMACDMAMACalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                    double &macd_out[], double &signal_out[], double &hist_out[])
  {
   if(rates_total < 50)
      return;

// Resize internal buffers
   if(ArraySize(m_mama_buf) != rates_total)
     {
      ArrayResize(m_mama_buf, rates_total);
      ArrayResize(m_fama_buf, rates_total);
      ArrayResize(m_macd_buf, rates_total);
      ArrayResize(m_signal_buf, rates_total);
      ArrayResize(m_hist_buf, rates_total);
     }

// 1. Calculate MAMA and FAMA
   m_mama_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_mama_buf, m_fama_buf);

// 2. Calculate MACD Line (MAMA - FAMA)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(50, start_index); // MAMA warmup

   for(int i = loop_start; i < rates_total; i++)
     {
      m_macd_buf[i] = m_mama_buf[i] - m_fama_buf[i];
     }

// 3. Calculate Signal Line
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_macd_buf, m_signal_buf, 50);

// 4. Calculate Histogram & Output
   for(int i = loop_start; i < rates_total; i++)
     {
      m_hist_buf[i] = m_macd_buf[i] - m_signal_buf[i];

      if(ArraySize(macd_out) == rates_total)
         macd_out[i] = m_macd_buf[i];
      if(ArraySize(signal_out) == rates_total)
         signal_out[i] = m_signal_buf[i];
      if(ArraySize(hist_out) == rates_total)
         hist_out[i] = m_hist_buf[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate Histogram Only                                         |
//+------------------------------------------------------------------+
void CMACDMAMACalculator::CalculateHistogramOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &hist_out[])
  {
   double dummy_macd[], dummy_signal[];
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, dummy_macd, dummy_signal, hist_out);
  }

//+------------------------------------------------------------------+
//| Calculate MACD Line Only                                         |
//+------------------------------------------------------------------+
void CMACDMAMACalculator::CalculateMACDLineOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &macd_out[])
  {
   double dummy_signal[], dummy_hist[];
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, macd_out, dummy_signal, dummy_hist);
  }

//+==================================================================+
//|           CLASS 2: CMACDMAMACalculator_HA                        |
//+==================================================================+
class CMACDMAMACalculator_HA : public CMACDMAMACalculator
  {
protected:
   virtual void      CreateMAMAEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CMACDMAMACalculator_HA::CreateMAMAEngine(void)
  {
   m_mama_engine = new CMAMACalculator_HA();
  }
//+------------------------------------------------------------------+
