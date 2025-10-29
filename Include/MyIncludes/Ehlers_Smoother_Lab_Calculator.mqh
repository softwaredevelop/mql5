//+------------------------------------------------------------------+
//|                               Ehlers_Smoother_Lab_Calculator.mqh |
//|      Universal calculation engine for a selection of Ehlers'     |
//|      and classic smoothing filters.                              |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_SMOOTHER_TYPE
  {
   EMA,
   SMA_RECURSIVE,
   GAUSSIAN,
   BUTTERWORTH_2P,
   SUPERSMOOTHER,
   ULTIMATESMOOTHER
  };

//+==================================================================+
class CSmootherLabCalculator
  {
protected:
   // Universal Filter Coefficients
   double            c0, c1, b0, b1, b2, a1, a2;
   int               N;
   int               m_period; // Keep period for SMA
   ENUM_SMOOTHER_TYPE m_type;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSmootherLabCalculator(void) {};
   virtual          ~CSmootherLabCalculator(void) {};

   bool              Init(ENUM_SMOOTHER_TYPE type, int period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
bool CSmootherLabCalculator::Init(ENUM_SMOOTHER_TYPE type, int period)
  {
   m_type = type;
   m_period = period; // Store period for SMA

// Default all coefficients
   c0=1;
   c1=0;
   N=0;
   b0=1;
   b1=0;
   b2=0;
   a1=0;
   a2=0;

   switch(type)
     {
      case EMA:
        {
         if(period<1)
            period=1;
         double alpha = 2.0 / (period + 1.0);
         b0 = alpha;
         a1 = 1.0 - alpha;
         break;
        }
      case SMA_RECURSIVE:
        {
         // No coefficients needed, will be handled by a special case in Calculate()
         break;
        }
      // ... (Other cases are unchanged and correct)
      case GAUSSIAN:
        {
         if(period<2)
            period=2;
         double beta = 2.451 * (1.0 - cos(2.0 * M_PI / period));
         double alpha = -beta + sqrt(beta * beta + 2.0 * beta);
         c0 = alpha * alpha;
         b0 = 1.0;
         a1 = 2.0 * (1.0 - alpha);
         a2 = -pow(1.0 - alpha, 2);
         break;
        }
      case BUTTERWORTH_2P:
        {
         if(period<2)
            period=2;
         double beta = 2.451 * (1.0 - cos(2.0 * M_PI / period));
         double alpha = -beta + sqrt(beta * beta + 2.0 * beta);
         c0 = alpha * alpha / 4.0;
         b0 = 1.0;
         b1 = 2.0;
         b2 = 1.0;
         a1 = 2.0 * (1.0 - alpha);
         a2 = -pow(1.0 - alpha, 2);
         break;
        }
      case SUPERSMOOTHER:
        {
         if(period<2)
            period=2;
         double arg = M_SQRT2 * M_PI / period;
         double a_ss = exp(-arg);
         double b_ss = 2.0 * a_ss * cos(arg);
         double c1_ss = 1.0 - b_ss + a_ss * a_ss;
         c0 = 1.0;
         b0 = c1_ss / 2.0;
         b1 = c1_ss / 2.0;
         a1 = b_ss;
         a2 = -a_ss * a_ss;
         break;
        }
      case ULTIMATESMOOTHER:
        {
         if(period<2)
            period=2;
         double arg = M_SQRT2 * M_PI / period;
         double a_us = exp(-arg);
         double b_us = 2.0 * a_us * cos(arg);
         double c3_us = -a_us * a_us;
         double c1_hp = (1.0 + b_us - c3_us) / 4.0;
         c0 = 1.0;
         b0 = 1.0 - c1_hp;
         b1 = 2.0 * c1_hp - b_us;
         b2 = -(c1_hp + c3_us);
         a1 = b_us;
         a2 = c3_us;
         break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
void CSmootherLabCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < m_period + 3)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- CORRECTED: Special handling for Recursive SMA ---
   if(m_type == SMA_RECURSIVE)
     {
      double sma_prev = 0;
      // Initial SMA calculation
      double first_sum = 0;
      for(int i = 0; i < m_period; i++)
        {
         first_sum += m_price[i];
        }
      filter_buffer[m_period - 1] = first_sum / m_period;
      sma_prev = filter_buffer[m_period - 1];

      // Recursive calculation for the rest of the bars
      for(int i = m_period; i < rates_total; i++)
        {
         double current_sma = sma_prev + (m_price[i] - m_price[i - m_period]) / m_period;
         filter_buffer[i] = current_sma;
         sma_prev = current_sma;
        }
      return; // Calculation for SMA is done, exit the method
     }

// --- General IIR Filter Calculation for all other types ---
   double f1=0, f2=0;
   for(int i = 0; i < rates_total; i++)
     {
      if(i < N + 2)
        {
         filter_buffer[i] = m_price[i];
         continue;
        }

      double input_term = c0 * (b0 * m_price[i] + b1 * m_price[i-1] + b2 * m_price[i-2]);
      double feedback_term = a1 * f1 + a2 * f2;
      double subtract_term = (N > 0) ? c1 * m_price[i-N] : 0;

      double current_f = input_term + feedback_term - subtract_term;
      filter_buffer[i] = current_f;

      f2 = f1;
      f1 = current_f;
     }
  }

// ... (PreparePriceSeries and _HA class are unchanged) ...
//+------------------------------------------------------------------+
bool CSmootherLabCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
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
//|                                                                  |
//+------------------------------------------------------------------+
class CSmootherLabCalculator_HA : public CSmootherLabCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmootherLabCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
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
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
