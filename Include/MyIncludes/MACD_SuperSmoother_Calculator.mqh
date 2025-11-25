//+------------------------------------------------------------------+
//|                               MACD_SuperSmoother_Calculator.mqh  |
//|      VERSION 1.21: Corrected method definition placement.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include "Ehlers_Smoother_Calculator.mqh"
#include "MovingAverage_Engine.mqh"

//--- Universal enum for all smoothing types ---
enum ENUM_SMOOTHING_METHOD
  {
   SMOOTH_SMA,
   SMOOTH_EMA,
   SMOOTH_SMMA,
   SMOOTH_LWMA,
   SMOOTH_SuperSmoother
  };

//+==================================================================+
class CMACDSuperSmootherCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_SMOOTHING_METHOD m_signal_ma_type;

   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;

   double            m_sig_f1, m_sig_f2;

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_SMOOTHING_METHOD method, int start_pos);

public:
                     CMACDSuperSmootherCalculator(void);
   virtual          ~CMACDSuperSmootherCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_SMOOTHING_METHOD signal_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMACDSuperSmootherCalculator_HA : public CMACDSuperSmootherCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|         METHOD IMPLEMENTATIONS: CMACDSuperSmootherCalculator     |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::CMACDSuperSmootherCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
   m_sig_f1 = 0;
   m_sig_f2 = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMACDSuperSmootherCalculator::~CMACDSuperSmootherCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator::CreateSmootherInstance(void)
  {
   return new CEhlersSmootherCalculator();
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
   m_sig_f1 = 0;
   m_sig_f2 = 0;

   m_fast_smoother = CreateSmootherInstance();
   m_slow_smoother = CreateSmootherInstance();

   if(CheckPointer(m_fast_smoother) == POINTER_INVALID || !m_fast_smoother.Init(m_fast_period, SUPERSMOOTHER, SOURCE_PRICE) ||
      CheckPointer(m_slow_smoother) == POINTER_INVALID || !m_slow_smoother.Init(m_slow_period, SUPERSMOOTHER, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &macd_line[], double &signal_line[], double &histogram[])
  {
   if(rates_total < m_slow_period + m_signal_period)
      return;

   double fast_buffer[], slow_buffer[];
   ArrayResize(fast_buffer, rates_total);
   ArrayResize(slow_buffer, rates_total);
   m_fast_smoother.Calculate(rates_total, price_type, open, high, low, close, fast_buffer);
   m_slow_smoother.Calculate(rates_total, price_type, open, high, low, close, slow_buffer);
   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_buffer[i] - slow_buffer[i];

   int signal_start = m_slow_period + m_signal_period - 1;
   CalculateMA(macd_line, signal_line, m_signal_period, m_signal_ma_type, signal_start);

   for(int i = 0; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_SMOOTHING_METHOD method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case SMOOTH_SuperSmoother:
           {
            double a1 = exp(-M_SQRT2 * M_PI / period);
            double b1 = 2.0 * a1 * cos(M_SQRT2 * M_PI / period);
            double c2 = b1, c3 = -a1 * a1, c1 = 1.0 - c2 - c3;
            if(i==start_pos)
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
                  dest_array[i] = sum/count;
               m_sig_f1 = dest_array[i];
               m_sig_f2 = (i > 0 && dest_array[i-1] != EMPTY_VALUE) ? dest_array[i-1] : dest_array[i];
              }
            else
              {
               dest_array[i] = c1 * (source_array[i] + source_array[i-1]) / 2.0 + c2 * m_sig_f1 + c3 * m_sig_f2;
               m_sig_f2 = m_sig_f1;
               m_sig_f1 = dest_array[i];
              }
            break;
           }
         case SMOOTH_EMA:
         case SMOOTH_SMMA:
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
               if(method==SMOOTH_EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case SMOOTH_LWMA:
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
         default: // SMOOTH_SMA
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

//+==================================================================+
//|       METHOD IMPLEMENTATIONS: CMACDSuperSmootherCalculator_HA    |
//+==================================================================+

//--- CORRECTED: This method definition now belongs to the _HA class ---
CEhlersSmootherCalculator *CMACDSuperSmootherCalculator_HA::CreateSmootherInstance(void)
  {
   return new CEhlersSmootherCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
