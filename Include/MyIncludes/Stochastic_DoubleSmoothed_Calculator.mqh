//+------------------------------------------------------------------+
//|                           Stochastic_DoubleSmoothed_Calculator.mqh |
//|         VERSION 1.10: Corrected EMA calculation chain logic.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CStochasticDoubleSmoothedCalculator
  {
protected:
   int               m_q, m_r, m_s, m_signal_p;
   double            m_high[], m_low[], m_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);
   //--- UPDATED: Helper now accepts a starting position ---
   void              CalculateEMA(int rates_total, int period, const double &source[], double &dest[], int start_pos);

public:
                     CStochasticDoubleSmoothedCalculator(void) {};
   virtual          ~CStochasticDoubleSmoothedCalculator(void) {};

   bool              Init(int q, int r, int s, int signal_p);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CStochasticDoubleSmoothedCalculator_HA : public CStochasticDoubleSmoothedCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::Init(int q, int r, int s, int signal_p)
  {
   m_q = (q < 1) ? 1 : q;
   m_r = (r < 1) ? 1 : r;
   m_s = (s < 1) ? 1 : s;
   m_signal_p = (signal_p < 1) ? 1 : signal_p;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CStochasticDoubleSmoothedCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total < m_q + m_r + m_s)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double num_raw[], den_raw[];
   ArrayResize(num_raw, rates_total);
   ArrayResize(den_raw, rates_total);

   for(int i = m_q - 1; i < rates_total; i++)
     {
      double highest = m_high[i], lowest = m_low[i];
      for(int j = 1; j < m_q; j++)
        {
         highest = MathMax(highest, m_high[i-j]);
         lowest = MathMin(lowest, m_low[i-j]);
        }
      num_raw[i] = m_close[i] - lowest;
      den_raw[i] = highest - lowest;
     }

   double num_ema1[], num_ema2[], den_ema1[], den_ema2[];
   ArrayResize(num_ema1, rates_total);
   ArrayResize(num_ema2, rates_total);
   ArrayResize(den_ema1, rates_total);
   ArrayResize(den_ema2, rates_total);

//--- CORRECTED: Chaining the calculations with proper start positions ---
   int start_pos1 = m_q + m_r - 2;
   CalculateEMA(rates_total, m_r, num_raw, num_ema1, start_pos1);
   CalculateEMA(rates_total, m_r, den_raw, den_ema1, start_pos1);

   int start_pos2 = start_pos1 + m_s - 1;
   CalculateEMA(rates_total, m_s, num_ema1, num_ema2, start_pos2);
   CalculateEMA(rates_total, m_s, den_ema1, den_ema2, start_pos2);

   for(int i = 0; i < rates_total; i++)
     {
      if(i < start_pos2)
         k_buffer[i] = EMPTY_VALUE;
      else
         if(den_ema2[i] > 0.000001)
            k_buffer[i] = 100.0 * num_ema2[i] / den_ema2[i];
         else
            k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

   int start_pos_signal = start_pos2 + m_signal_p - 1;
   CalculateEMA(rates_total, m_signal_p, k_buffer, d_buffer, start_pos_signal);
  }

//--- UPDATED: Helper now uses the provided start_pos ---
void CStochasticDoubleSmoothedCalculator::CalculateEMA(int rates_total, int period, const double &source[], double &dest[], int start_pos)
  {
   if(rates_total <= start_pos)
      return;
   double pr = 2.0 / (double)(period + 1.0);

   for(int i=0; i<start_pos; i++)
      dest[i] = EMPTY_VALUE;

   double sum=0;
   int count=0;
   for(int j=0; j<period; j++)
      if(source[start_pos-j] != EMPTY_VALUE)
        {
         sum += source[start_pos-j];
         count++;
        }
   if(count > 0)
      dest[start_pos] = sum / count;
   else
      dest[start_pos] = EMPTY_VALUE;

   for(int i = start_pos + 1; i < rates_total; i++)
     {
      if(source[i] != EMPTY_VALUE && dest[i-1] != EMPTY_VALUE)
         dest[i] = source[i] * pr + dest[i-1] * (1.0 - pr);
      else
         if(dest[i-1] != EMPTY_VALUE)
            dest[i] = dest[i-1];
         else
            dest[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);
   ArrayCopy(m_close, close, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CStochasticDoubleSmoothedCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_low, ha_low, 0, 0, rates_total);
   ArrayCopy(m_close, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
