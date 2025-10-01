//+------------------------------------------------------------------+
//|                                                 TSI_Engine.mqh   |
//|        Core calculation engine for all TSI-based indicators.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CTSICalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CTSICalculator
  {
protected:
   int               m_slow_p, m_fast_p, m_signal_p;
   ENUM_MA_METHOD    m_signal_ma_type;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTSICalculator(void) {};
   virtual          ~CTSICalculator(void) {};

   bool              Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[]);

   int               GetPeriodSlow() const { return m_slow_p; }
   int               GetPeriodFast() const { return m_fast_p; }
   int               GetPeriodSignal() const { return m_signal_p; }
  };

// ... (A teljes Init, Calculate, PreparePriceSeries metódusok ide másolva a javított TSI_Calculator.mqh-ból) ...
//+------------------------------------------------------------------+
//| CTSICalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CTSICalculator::Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma)
  {
   m_slow_p         = (slow_p < 1) ? 1 : slow_p;
   m_fast_p         = (fast_p < 1) ? 1 : fast_p;
   m_signal_p       = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| CTSICalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CTSICalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_slow_p + m_fast_p + m_signal_p)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

   double momentum[], abs_momentum[];
   ArrayResize(momentum, rates_total);
   ArrayResize(abs_momentum, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      momentum[i] = m_price[i] - m_price[i-1];
      abs_momentum[i] = MathAbs(momentum[i]);
     }

   double ema1_mtm[], ema1_abs[];
   ArrayResize(ema1_mtm, rates_total);
   ArrayResize(ema1_abs, rates_total);
   double pr_slow = 2.0 / (m_slow_p + 1.0);
   for(int i=1; i<rates_total; i++)
     {
      ema1_mtm[i] = momentum[i] * pr_slow + ema1_mtm[i-1] * (1.0 - pr_slow);
      ema1_abs[i] = abs_momentum[i] * pr_slow + ema1_abs[i-1] * (1.0 - pr_slow);
     }

   double ema2_mtm[], ema2_abs[];
   ArrayResize(ema2_mtm, rates_total);
   ArrayResize(ema2_abs, rates_total);
   double pr_fast = 2.0 / (m_fast_p + 1.0);
   for(int i=1; i<rates_total; i++)
     {
      ema2_mtm[i] = ema1_mtm[i] * pr_fast + ema2_mtm[i-1] * (1.0 - pr_fast);
      ema2_abs[i] = ema1_abs[i] * pr_fast + ema2_abs[i-1] * (1.0 - pr_fast);
     }

   int tsi_start = m_slow_p + m_fast_p - 2;
   for(int i = tsi_start; i < rates_total; i++)
     {
      if(ema2_abs[i] > 0)
         tsi_buffer[i] = 100 * (ema2_mtm[i] / ema2_abs[i]);
     }

   int signal_start = tsi_start + m_signal_p - 1;
   for(int i = signal_start; i < rates_total; i++)
     {
      switch(m_signal_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == signal_start)
              {
               double sum=0;
               for(int j=0; j<m_signal_p; j++)
                  sum+=tsi_buffer[i-j];
               signal_buffer[i]=sum/m_signal_p;
              }
            else
              {
               if(m_signal_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_signal_p+1.0);
                  signal_buffer[i]=tsi_buffer[i]*pr+signal_buffer[i-1]*(1.0-pr);
                 }
               else
                  signal_buffer[i]=(signal_buffer[i-1]*(m_signal_p-1)+tsi_buffer[i])/m_signal_p;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_signal_p; j++) {int w=m_signal_p-j; sum+=tsi_buffer[i-j]*w; w_sum+=w;} if(w_sum>0) signal_buffer[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_signal_p; j++) sum+=tsi_buffer[i-j]; signal_buffer[i]=sum/m_signal_p;}
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CTSICalculator: Prepares the standard source price.              |
//+------------------------------------------------------------------+
bool CTSICalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CTSICalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CTSICalculator_HA : public CTSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CTSICalculator_HA: Prepares the HA source price.                 |
//+------------------------------------------------------------------+
bool CTSICalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
