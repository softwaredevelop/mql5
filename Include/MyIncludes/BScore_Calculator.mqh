//+------------------------------------------------------------------+
//|                                             BScore_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.02" // Fully corrected dynamic buffers, dynamic pointers and Ha subclass

#ifndef BSCORE_CALCULATOR_MQH
#define BSCORE_CALCULATOR_MQH

#include <MyIncludes\Butterworth_Calculator.mqh>

//+==================================================================+
//|             CLASS: CBScoreCalculator                             |
//+==================================================================+
class CBScoreCalculator
  {
protected:
   int                     m_period;       // Volatility lookback period (N)
   int                     m_butter_period;// Butterworth cutoff period
   ENUM_BUTTERWORTH_POLES  m_poles;        // Butterworth poles
   bool                    m_use_ha;       // Use Heikin Ashi price?

   CButterworthCalculator *m_butter_calc;  // Embedded Butterworth Filter engine

   double                  m_butter_buf[]; // Cached Butterworth centerline
   double                  m_price_buf[];  // Cached price buffer

   double                  m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
   CHeikinAshi_Calculator  m_ha_calc;

   virtual void      CreateEngine(void);
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBScoreCalculator(void);
   virtual          ~CBScoreCalculator(void);

   bool              Init(int period, int butter_period, ENUM_BUTTERWORTH_POLES poles, bool use_ha);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_bscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBScoreCalculator::CBScoreCalculator(void) : m_period(20), m_butter_period(20), m_poles(POLES_TWO), m_use_ha(false), m_butter_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBScoreCalculator::~CBScoreCalculator(void)
  {
   if(CheckPointer(m_butter_calc) != POINTER_INVALID)
      delete m_butter_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CBScoreCalculator::CreateEngine(void)
  {
   m_butter_calc = new CButterworthCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CBScoreCalculator::Init(int period, int butter_period, ENUM_BUTTERWORTH_POLES poles, bool use_ha)
  {
   m_period = (period < 2) ? 2 : period;
   m_butter_period = (butter_period < 2) ? 2 : butter_period;
   m_poles = poles;
   m_use_ha = use_ha;

   CreateEngine(); // Polymorphically instantiates the correct engine

   if(CheckPointer(m_butter_calc) == POINTER_INVALID)
      return false;

   return m_butter_calc.Init(m_butter_period, m_poles, SOURCE_PRICE);
  }

//+------------------------------------------------------------------+
//| Calculate (Incremental O(1))                                     |
//+------------------------------------------------------------------+
void CBScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &out_bscore[])
  {
   if(rates_total < m_period + 5)
      return;

   if(CheckPointer(m_butter_calc) == POINTER_INVALID)
      return;

//--- Resize Internal Buffers & force strict chronological indexing
   if(ArraySize(m_butter_buf) != rates_total)
     {
      ArrayResize(m_butter_buf, rates_total);
      ArraySetAsSeries(m_butter_buf, false);
     }

// 1. Prepare aligned source prices (Standard or Heikin Ashi)
   if(!PreparePriceSeries(rates_total, prev_calculated, price_type, open, high, low, close))
      return;

// 2. Calculate underlying Ehlers Butterworth Filter
   m_butter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_butter_buf);

// 3. Compute rolling Z-Score around Butterworth Filter centerline
   int start = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   for(int i = start; i < rates_total; i++)
     {
      double current_butter = m_butter_buf[i];
      double p = m_price_buf[i];

      if(current_butter == 0.0 || current_butter == EMPTY_VALUE)
         current_butter = p;

      double sum_sq_diff = 0;
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p_k = m_price_buf[idx];
         double b_k = m_butter_buf[idx];

         if(b_k == 0.0 || b_k == EMPTY_VALUE)
            b_k = p_k;

         double diff = p_k - b_k;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / m_period);

      if(std_dev > 1.0e-9)
         out_bscore[i] = (p - current_butter) / std_dev;
      else
         out_bscore[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| PreparePriceSeries                                               |
//+------------------------------------------------------------------+
bool CBScoreCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   int start = (start_index == 0) ? 0 : start_index;

   if(ArraySize(m_price_buf) != rates_total)
     {
      ArrayResize(m_price_buf, rates_total);
      ArraySetAsSeries(m_price_buf, false); // Fixed: chronological sorting safety
     }

   for(int i = start; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price_buf[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price_buf[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price_buf[i] = high[i];
            break;
         case PRICE_LOW:
            m_price_buf[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price_buf[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price_buf[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price_buf[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
            break;
         default:
            m_price_buf[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CBScoreCalculator_HA                        |
//+==================================================================+
class CBScoreCalculator_HA : public CBScoreCalculator
  {
protected:
   virtual void      CreateEngine(void) override;
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
void CBScoreCalculator_HA::CreateEngine(void)
  {
   m_butter_calc = new CButterworthCalculator_HA();
  }

//+------------------------------------------------------------------+
bool CBScoreCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   int start = (start_index == 0) ? 0 : start_index;

   if(ArraySize(m_price_buf) != rates_total)
     {
      ArrayResize(m_price_buf, rates_total);
      ArraySetAsSeries(m_price_buf, false);
     }

   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open, false);
      ArraySetAsSeries(m_ha_high, false);
      ArraySetAsSeries(m_ha_low, false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calc.Calculate(rates_total, start, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price_buf[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price_buf[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price_buf[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price_buf[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price_buf[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price_buf[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
#endif // BSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
