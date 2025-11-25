//+------------------------------------------------------------------+
//|                           MACD_Laguerre_Histogram_Calculator.mqh |
//|      VERSION 1.10: Added selectable signal line.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

enum ENUM_SMOOTHING_METHOD_LAGUERRE
  {
   SMOOTH_Laguerre,
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA
  };

//+==================================================================+
class CMACDLaguerreHistogramCalculator
  {
protected:
   double            m_fast_gamma, m_slow_gamma, m_signal_gamma;
   int               m_signal_period;
   ENUM_SMOOTHING_METHOD_LAGUERRE m_signal_ma_type;

   CLaguerreEngine   *m_fast_engine, *m_slow_engine;
   double            m_sig_L0_prev, m_sig_L1_prev, m_sig_L2_prev, m_sig_L3_prev;

   virtual CLaguerreEngine *CreateEngineInstance(void);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CMACDLaguerreHistogramCalculator(void);
   virtual          ~CMACDLaguerreHistogramCalculator(void);

   bool              Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &histogram[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMACDLaguerreHistogramCalculator_HA : public CMACDLaguerreHistogramCalculator
  {
protected:
   virtual CLaguerreEngine *CreateEngineInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDLaguerreHistogramCalculator::CMACDLaguerreHistogramCalculator(void)
  {
   m_fast_engine = NULL;
   m_slow_engine = NULL;
   m_sig_L0_prev = 0;
   m_sig_L1_prev = 0;
   m_sig_L2_prev = 0;
   m_sig_L3_prev = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDLaguerreHistogramCalculator::~CMACDLaguerreHistogramCalculator(void)
  {
   if(CheckPointer(m_fast_engine) != POINTER_INVALID)
      delete m_fast_engine;
   if(CheckPointer(m_slow_engine) != POINTER_INVALID)
      delete m_slow_engine;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLaguerreEngine *CMACDLaguerreHistogramCalculator::CreateEngineInstance(void) { return new CLaguerreEngine(); }
CLaguerreEngine *CMACDLaguerreHistogramCalculator_HA::CreateEngineInstance(void) { return new CLaguerreEngine_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDLaguerreHistogramCalculator::Init(double g1, double g2, double sig_g, int sig_p, ENUM_SMOOTHING_METHOD_LAGUERRE sig_type)
  {
   m_fast_gamma = MathMin(g1, g2);
   m_slow_gamma = MathMax(g1, g2);
   m_signal_gamma = fmax(0.0, fmin(1.0, sig_g));
   m_signal_period = (sig_p < 1) ? 1 : sig_p;
   m_signal_ma_type = sig_type;

   m_sig_L0_prev=0;
   m_sig_L1_prev=0;
   m_sig_L2_prev=0;
   m_sig_L3_prev=0;

   m_fast_engine = CreateEngineInstance();
   m_slow_engine = CreateEngineInstance();

   if(CheckPointer(m_fast_engine) == POINTER_INVALID || !m_fast_engine.Init(m_fast_gamma, SOURCE_PRICE) ||
      CheckPointer(m_slow_engine) == POINTER_INVALID || !m_slow_engine.Init(m_slow_gamma, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDLaguerreHistogramCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &histogram[])
  {
   if(rates_total < 2)
      return;

   double macd_line[], signal_line[];
   ArrayResize(macd_line, rates_total);
   ArrayResize(signal_line, rates_total);

   double fast_filter[], slow_filter[];
   double L0_dummy[], L1_dummy[], L2_dummy[], L3_dummy[];
   m_fast_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, fast_filter);
   m_slow_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0_dummy, L1_dummy, L2_dummy, L3_dummy, slow_filter);
   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_filter[i] - slow_filter[i];

   switch(m_signal_ma_type)
     {
      case SMOOTH_Laguerre:
         if(rates_total > 0)
           {
            signal_line[0] = macd_line[0];
            m_sig_L0_prev = macd_line[0];
            m_sig_L1_prev = macd_line[0];
            m_sig_L2_prev = macd_line[0];
            m_sig_L3_prev = macd_line[0];
           }
         for(int i = 1; i < rates_total; i++)
           {
            double L0 = (1.0 - m_signal_gamma) * macd_line[i] + m_signal_gamma * m_sig_L0_prev;
            double L1 = -m_signal_gamma * L0 + m_sig_L0_prev + m_signal_gamma * m_sig_L1_prev;
            double L2 = -m_signal_gamma * L1 + m_sig_L1_prev + m_signal_gamma * m_sig_L2_prev;
            double L3 = -m_signal_gamma * L2 + m_sig_L2_prev + m_signal_gamma * m_sig_L3_prev;
            signal_line[i] = (L0 + 2.0 * L1 + 2.0 * L2 + L3) / 6.0;
            m_sig_L0_prev = L0;
            m_sig_L1_prev = L1;
            m_sig_L2_prev = L2;
            m_sig_L3_prev = L3;
           }
         break;
      default:
        {
         ENUM_MA_TYPE ma_type = (ENUM_MA_TYPE)(m_signal_ma_type - 1);
         CalculateMA(macd_line, signal_line, m_signal_period, ma_type, m_signal_period + 1);
         break;
        }
     }

   for(int i = 0; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDLaguerreHistogramCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case EMA:
         case SMMA:
            if(i == start_pos)
              {
               double sum=0;
               int count=0;
               for(int j=0; j<period; j++)
                 {
                  if(source_array[i-j] != EMPTY_VALUE)
                    {
                     sum+=source_array[i-j];
                     count++;
                    }
                 }
               if(count > 0)
                  dest_array[i]=sum/count;
              }
            else
              {
               if(method==EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case LWMA:
           {
            double sum=0, w_sum=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] == EMPTY_VALUE)
                  continue;
               int w=period-j;
               sum+=source_array[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest_array[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            int count=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] != EMPTY_VALUE)
                 {
                  sum+=source_array[i-j];
                  count++;
                 }
              }
            if(count > 0)
               dest_array[i]=sum/count;
           }
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
