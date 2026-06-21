//+------------------------------------------------------------------+
//|                                          ZScore_Calculator.mqh   |
//|      Engine for Statistical Z-Score Calculation.                 |
//|      Standard Deviation distance from any Moving Average Type.   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.40" // Upgraded to support any ENUM_MA_TYPE and volume integration

#ifndef ZSCORE_CALCULATOR_MQH
#define ZSCORE_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS: CZScoreCalculator                             |
//+==================================================================+
class CZScoreCalculator
  {
protected:
   int               m_period;

   //--- Dynamic Engine for Mean (User selected MA Type)
   CMovingAverageCalculator *m_ma_calc;

   //--- Buffers
   double            m_price[];
   double            m_ma_buffer[];
   double            m_volume[];

   virtual bool      PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CZScoreCalculator();
   virtual          ~CZScoreCalculator();

   //--- Updated Init signature to accept dynamic MA type
   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Standard Calculate (Without volume data)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_z[]);

   //--- Overloaded Calculate with Volume (Specifically for VWMA support)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const long &volume[],
                               double &out_z[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CZScoreCalculator::CZScoreCalculator() : m_ma_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CZScoreCalculator::~CZScoreCalculator()
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CZScoreCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = (period < 2) ? 2 : period;

// Set up dynamic calculator engine based on selected MA type
   m_ma_calc = new CMovingAverageCalculator();
   if(CheckPointer(m_ma_calc) == POINTER_INVALID || !m_ma_calc.Init(m_period, ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CZScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  double &out_z[])
  {
   if(rates_total < m_period)
      return;

// 1. Resize Internal Prices
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

// 2. Prepare Price Array
   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePrice(rates_total, start_prep, price_type, open, high, low, close))
      return;

// 3. Calculate Mean (Using standard array calculation)
   m_ma_calc.CalculateOnArray(rates_total, prev_calculated, m_price, m_ma_buffer, 0);

// 4. Calculate Z-Score Distance
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period - 1;
   if(start_index < m_period - 1)
      start_index = m_period - 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double sum_sq = 0;

      for(int k = 0; k < m_period; k++)
        {
         double diff = m_price[i - k] - m_ma_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / m_period);

      if(std_dev > 1.0e-9) // Anti-division-by-zero guard
         out_z[i] = (m_price[i] - m_ma_buffer[i]) / std_dev;
      else
         out_z[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CZScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                  const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  const long &volume[],
                                  double &out_z[])
  {
   if(rates_total < m_period)
      return;

// 1. Resize Internal Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }
   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total);
     }

// 2. Prepare Price Array
   int start_prep = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePrice(rates_total, start_prep, price_type, open, high, low, close))
      return;

// 3. Prepare Volume Array
   for(int i = start_prep; i < rates_total; i++)
     {
      m_volume[i] = (double)volume[i];
     }

// 4. Calculate Mean (Using volume-based array calculation)
   m_ma_calc.CalculateOnArray(rates_total, prev_calculated, m_price, m_volume, m_ma_buffer, 0);

// 5. Calculate Z-Score Distance
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period - 1;
   if(start_index < m_period - 1)
      start_index = m_period - 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double sum_sq = 0;

      for(int k = 0; k < m_period; k++)
        {
         double diff = m_price[i - k] - m_ma_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq / m_period);

      if(std_dev > 1.0e-9) // Anti-division-by-zero guard
         out_z[i] = (m_price[i] - m_ma_buffer[i]) / std_dev;
      else
         out_z[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Value                                                    |
//+------------------------------------------------------------------+
bool CZScoreCalculator::PreparePrice(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])*0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+close[i]*2.0)*0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

#endif // ZSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+