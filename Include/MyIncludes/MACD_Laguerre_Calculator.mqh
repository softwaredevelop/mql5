//+------------------------------------------------------------------+
//|                                     MACD_Laguerre_Calculator.mqh |
//|      VERSION 3.00: Unified calculator for ALL Laguerre MACD inds.|
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Universal enum for smoothing types
enum ENUM_SMOOTHING_METHOD_LAGUERRE
  {
   SMOOTH_Laguerre,
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA,
   SMOOTH_TMA,
   SMOOTH_DEMA,
   SMOOTH_TEMA
  };

//+==================================================================+
//|           CLASS 1: CMACDLaguerreCalculator (Base)                |
//+==================================================================+
class CMACDLaguerreCalculator
  {
protected:
   double            m_fast_gamma, m_slow_gamma, m_signal_gamma;
   int               m_signal_period;
   ENUM_SMOOTHING_METHOD_LAGUERRE m_signal_ma_type;

   //--- Engines
   CLaguerreEngine   *m_fast_engine;
   CLaguerreEngine   *m_slow_engine;
   CLaguerreEngine   *m_signal_laguerre_engine;
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Persistent Internal Buffers
   double            m_fast_filter[];
   double            m_slow_filter[];
   double            m_macd_internal[];   // Stores MACD Line
   double            m_signal_internal[]; // Stores Signal Line
   double            m_hist_internal[];   // Stores Histogram

   virtual CLaguerreEngine *CreateEngineInstance(void);

public:
                     CMACDLaguerreCalculator(void);
   virtual          ~CMACDLaguerreCalculator(void);

   bool              Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type);

   //--- Main Calculation (All outputs)
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
//|           CLASS 2: CMACDLaguerreCalculator_HA                    |
//+------------------------------------------------------------------+
class CMACDLaguerreCalculator_HA : public CMACDLaguerreCalculator
  {
protected:
   virtual CLaguerreEngine *CreateEngineInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDLaguerreCalculator::CMACDLaguerreCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
   m_signal_laguerre_engine = NULL;
   m_signal_ma_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDLaguerreCalculator::~CMACDLaguerreCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
   if(CheckPointer(m_signal_laguerre_engine) != POINTER_INVALID)
      delete m_signal_laguerre_engine;
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDLaguerreCalculator::Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type)
  {
   m_fast_gamma = MathMin(g1, g2);
   m_slow_gamma = MathMax(g1, g2);
   m_signal_gamma = fmax(0.0, fmin(1.0, sig_g));
   m_signal_period = (sig_p < 1) ? 1 : sig_p;
   m_signal_ma_type = sig_type;

   m_fast_engine = CreateEngineInstance();
   m_slow_engine = CreateEngineInstance();

   if(CheckPointer(m_fast_engine) == POINTER_INVALID || !m_fast_engine.Init(m_fast_gamma, SOURCE_PRICE) ||
      CheckPointer(m_slow_engine) == POINTER_INVALID || !m_slow_engine.Init(m_slow_gamma, SOURCE_PRICE))
      return false;

   if(m_signal_ma_type == SMOOTH_Laguerre)
     {
      m_signal_laguerre_engine = new CLaguerreEngine();
      if(!m_signal_laguerre_engine.Init(m_signal_gamma, SOURCE_PRICE))
         return false;
     }
   else
     {
      m_signal_ma_engine = new CMovingAverageCalculator();
      ENUM_MA_TYPE ma_type = (ENUM_MA_TYPE)(m_signal_ma_type - 1);
      if(!m_signal_ma_engine.Init(m_signal_period, ma_type))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CMACDLaguerreCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                        double &macd_out[], double &signal_out[], double &hist_out[])
  {
   if(rates_total < 2)
      return;

// Resize internal buffers
   if(ArraySize(m_fast_filter) != rates_total)
     {
      ArrayResize(m_fast_filter, rates_total);
      ArrayResize(m_slow_filter, rates_total);
      ArrayResize(m_macd_internal, rates_total);
      ArrayResize(m_signal_internal, rates_total);
      ArrayResize(m_hist_internal, rates_total);
     }

// 1. Calculate Fast and Slow Laguerre
   m_fast_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, m_fast_filter);
   m_slow_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, m_slow_filter);

// 2. Calculate MACD Line
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_index; i < rates_total; i++)
      m_macd_internal[i] = m_fast_filter[i] - m_slow_filter[i];

// 3. Calculate Signal Line
   if(m_signal_ma_type == SMOOTH_Laguerre)
     {
      m_signal_laguerre_engine.CalculateFilter(rates_total, prev_calculated, PRICE_CLOSE,
            m_macd_internal, m_macd_internal, m_macd_internal, m_macd_internal,
            m_signal_internal);
     }
   else
     {
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_macd_internal, m_signal_internal, 2);
     }

// 4. Calculate Histogram & Output
   for(int i = start_index; i < rates_total; i++)
     {
      m_hist_internal[i] = m_macd_internal[i] - m_signal_internal[i];

      // Copy to output buffers if they are valid (not dummy)
      // Note: We check array size to avoid writing to dummy arrays if they are small (though we resize them in wrappers)
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
void CMACDLaguerreCalculator::CalculateHistogramOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &hist_out[])
  {
   double dummy_macd[], dummy_signal[];
// No need to resize dummies, the Main Calculate checks size before writing
   Calculate(rates_total, prev_calculated, open, high, low, close, price_type, dummy_macd, dummy_signal, hist_out);
  }

//+------------------------------------------------------------------+
//| Calculate MACD Line Only                                         |
//+------------------------------------------------------------------+
void CMACDLaguerreCalculator::CalculateMACDLineOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_out[])
  {
   double dummy_signal[], dummy_hist[];
   Calculate(rates_total, prev_calculated, open, high, low, close, price_type, macd_out, dummy_signal, dummy_hist);
  }
//+------------------------------------------------------------------+
