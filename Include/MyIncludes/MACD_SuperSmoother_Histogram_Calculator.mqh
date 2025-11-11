//+------------------------------------------------------------------+
//|                       MACD_SuperSmoother_Histogram_Calculator.mqh|
//|      VERSION 1.01: Completed constructor/destructor logic.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh> // For ENUM_MA_TYPE

//+==================================================================+
class CMACDSuperSmootherHistogramCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;

   CEhlersSmootherCalculator *m_fast_smoother;
   CEhlersSmootherCalculator *m_slow_smoother;

   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CMACDSuperSmootherHistogramCalculator(void);
   virtual          ~CMACDSuperSmootherHistogramCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_MA_TYPE signal_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &histogram[]);
  };

//--- Derived class for Heikin Ashi version ---
class CMACDSuperSmootherHistogramCalculator_HA : public CMACDSuperSmootherHistogramCalculator
  {
protected:
   virtual CEhlersSmootherCalculator *CreateSmootherInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//--- CORRECTED: Constructor with pointer initialization ---
CMACDSuperSmootherHistogramCalculator::CMACDSuperSmootherHistogramCalculator(void)
  {
   m_fast_smoother = NULL;
   m_slow_smoother = NULL;
  }

//--- CORRECTED: Destructor with memory cleanup ---
CMACDSuperSmootherHistogramCalculator::~CMACDSuperSmootherHistogramCalculator(void)
  {
   if(CheckPointer(m_fast_smoother) != POINTER_INVALID)
      delete m_fast_smoother;
   if(CheckPointer(m_slow_smoother) != POINTER_INVALID)
      delete m_slow_smoother;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator *CMACDSuperSmootherHistogramCalculator::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator(); }
CEhlersSmootherCalculator *CMACDSuperSmootherHistogramCalculator_HA::CreateSmootherInstance(void) { return new CEhlersSmootherCalculator_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDSuperSmootherHistogramCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_MA_TYPE signal_type)
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

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherHistogramCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &histogram[])
  {
   if(rates_total < m_slow_period + m_signal_period)
      return;

   double macd_line[], signal_line[];
   ArrayResize(macd_line, rates_total);
   ArrayResize(signal_line, rates_total);

   double fast_buffer[], slow_buffer[];
   ArrayResize(fast_buffer, rates_total);
   ArrayResize(slow_buffer, rates_total);
   m_fast_smoother.Calculate(rates_total, price_type, open, high, low, close, fast_buffer);
   m_slow_smoother.Calculate(rates_total, price_type, open, high, low, close, slow_buffer);
   for(int i = 0; i < rates_total; i++)
      macd_line[i] = fast_buffer[i] - slow_buffer[i];

   CalculateMA(macd_line, signal_line, m_signal_period, m_signal_ma_type, m_slow_period + m_signal_period - 1);

   for(int i = 0; i < rates_total; i++)
      histogram[i] = macd_line[i] - signal_line[i];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMACDSuperSmootherHistogramCalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
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
