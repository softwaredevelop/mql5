//+------------------------------------------------------------------+
//|                           Stochastic_Adaptive_RSI_Calculator.mqh |
//|      Engine for Variable-Length Stochastic applied to RSI.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh> // For ENUM_MA_TYPE

//+==================================================================+
class CStochasticAdaptiveRSICalculator
  {
protected:
   int               m_rsi_period, m_er_period, m_min_period, m_max_period, m_slowing_period, m_d_period;
   ENUM_MA_METHOD    m_d_ma_type;
   double            m_price[]; // Only for ER calculation

   CRSIProCalculator *m_rsi_calculator;

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos);

public:
                     CStochasticAdaptiveRSICalculator(void);
   virtual          ~CStochasticAdaptiveRSICalculator(void);

   bool              Init(int rsi_p, int er_p, int min_p, int max_p, int slow_p, int d_p, ENUM_MA_METHOD d_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStochasticAdaptiveRSICalculator_HA : public CStochasticAdaptiveRSICalculator
  {
public:
                     CStochasticAdaptiveRSICalculator_HA(void);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticAdaptiveRSICalculator::CStochasticAdaptiveRSICalculator(void) { m_rsi_calculator = new CRSIProCalculator(); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticAdaptiveRSICalculator::~CStochasticAdaptiveRSICalculator(void) { if(CheckPointer(m_rsi_calculator) != POINTER_INVALID) delete m_rsi_calculator; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochasticAdaptiveRSICalculator_HA::CStochasticAdaptiveRSICalculator_HA(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
   m_rsi_calculator = new CRSIProCalculator_HA();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveRSICalculator::Init(int rsi_p, int er_p, int min_p, int max_p, int slow_p, int d_p, ENUM_MA_METHOD d_ma)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_er_period = (er_p < 1) ? 1 : er_p;
   m_min_period = (min_p < 1) ? 1 : min_p;
   m_max_period = (max_p <= m_min_period) ? m_min_period + 1 : max_p;
   m_slowing_period = (slow_p < 1) ? 1 : slow_p;
   m_d_period = (d_p < 1) ? 1 : d_p;
   m_d_ma_type = d_ma;
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;
   return m_rsi_calculator.Init(m_rsi_period, 1, MODE_SMA, 2.0); // Dummy params for MA/Bands
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticAdaptiveRSICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_rsi_period + m_er_period + m_max_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double rsi_buffer[], dummy1[], dummy2[], dummy3[];
   ArrayResize(rsi_buffer, rates_total);
   m_rsi_calculator.Calculate(rates_total, price_type, open, high, low, close, rsi_buffer, dummy1, dummy2, dummy3);

   double er_buffer[], nsp_buffer[];
   ArrayResize(er_buffer, rates_total);
   ArrayResize(nsp_buffer, rates_total);
   for(int i = m_er_period; i < rates_total; i++)
     {
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
      er_buffer[i] = (volatility > 0.000001) ? direction / volatility : 0;
      nsp_buffer[i] = (int)(er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(nsp_buffer[i] < 1)
         nsp_buffer[i] = 1;
     }

   double raw_k[];
   ArrayResize(raw_k, rates_total);
   for(int i = m_rsi_period + m_er_period + m_max_period - 1; i < rates_total; i++)
     {
      int current_nsp = (int)nsp_buffer[i];
      double highest = rsi_buffer[i], lowest = rsi_buffer[i];
      for(int j = 1; j < current_nsp; j++)
        {
         if(i-j < 0)
            break;
         highest = MathMax(highest, rsi_buffer[i-j]);
         lowest = MathMin(lowest, rsi_buffer[i-j]);
        }
      double range = highest - lowest;
      if(range > 0.00001)
         raw_k[i] = (rsi_buffer[i] - lowest) / range * 100.0;
      else
         raw_k[i] = (i > 0) ? raw_k[i-1] : 50.0;
     }

   int k_slow_start = m_rsi_period + m_er_period + m_max_period + m_slowing_period - 2;
   CalculateMA(raw_k, k_buffer, m_slowing_period, MODE_SMA, k_slow_start);
   int d_start = k_slow_start + m_d_period - 1;
   CalculateMA(k_buffer, d_buffer, m_d_period, m_d_ma_type, d_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticAdaptiveRSICalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_METHOD method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case MODE_EMA:
         case MODE_SMMA:
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
               if(method==MODE_EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case MODE_LWMA:
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
         default: // MODE_SMA
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
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveRSICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
