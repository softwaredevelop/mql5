//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|      VERSION 1.10: Added optional signal line.                   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh> // For ENUM_MA_TYPE

//+==================================================================+
class CLaguerreRSICalculator
  {
protected:
   CLaguerreEngine   *m_engine;
   int               m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;

   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CLaguerreRSICalculator(void) { m_engine = new CLaguerreEngine(); };
   virtual          ~CLaguerreRSICalculator(void) { if(CheckPointer(m_engine) != POINTER_INVALID) delete m_engine; };

   bool              Init(double gamma, int signal_p, ENUM_MA_TYPE signal_ma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
bool CLaguerreRSICalculator::Init(double gamma, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;
   return m_engine.Init(gamma, SOURCE_PRICE);
  }

//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2)
      return;

   double L0[], L1[], L2[], L3[], dummy_filt[];
   m_engine.CalculateFilter(rates_total, price_type, open, high, low, close, L0, L1, L2, L3, dummy_filt);

   for(int i = 1; i < rates_total; i++)
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

      double lrsi_value;
      if(cu + cd > 0.0)
         lrsi_value = 100.0 * cu / (cu + cd);
      else
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0;

      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;
      lrsi_buffer[i] = lrsi_value;
     }

//--- Step 2: Calculate Signal Line on the LRSI buffer ---
   int signal_start = m_signal_period + 1; // LRSI starts at index 1, so we need more bars
   CalculateMA(lrsi_buffer, signal_buffer, m_signal_period, m_signal_ma_type, signal_start);
  }

//+------------------------------------------------------------------+
void CLaguerreRSICalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
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

//+==================================================================+
class CLaguerreRSICalculator_HA : public CLaguerreRSICalculator
  {
public:
                     CLaguerreRSICalculator_HA(void)
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
         delete m_engine;
      m_engine = new CLaguerreEngine_HA();
     };
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
