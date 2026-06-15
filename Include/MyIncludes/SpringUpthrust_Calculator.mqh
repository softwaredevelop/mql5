//+------------------------------------------------------------------+
//|                                   SpringUpthrust_Calculator.mqh  |
//|      Engine for Wyckoff Springs & Upthrusts Detection (VSA).     |
//|      Strictly O(1) Incremental Optimized.                        |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Added level age filters and close rejection thresholds

#ifndef SPRINGUPTHRUST_CALCULATOR_MQH
#define SPRINGUPTHRUST_CALCULATOR_MQH

//+==================================================================+
//|             CLASS: CSpringUpthrustCalculator                     |
//+==================================================================+
class CSpringUpthrustCalculator
  {
private:
   int               m_fractal_period;
   int               m_min_level_age;   // FIXED: Minimum bars required to consider S/R level significant

   //--- Persistent States
   double            m_active_sup;
   datetime          m_sup_time;
   int               m_sup_idx;

   double            m_active_res;
   datetime          m_res_time;
   int               m_res_idx;

public:
                     CSpringUpthrustCalculator();
                    ~CSpringUpthrustCalculator() {};

   bool              Init(int fractal_period, int min_level_age = 8);
   void              Calculate(int rates_total, int prev_calculated,
                               const datetime &time[], const double &high[], const double &low[], const double &close[],
                               const double &atr_buffer[], const double &rvol_buffer[],
                               double &out_spring[], double &out_upthrust[],
                               double &out_sup_level[], double &out_res_level[],
                               double &out_sup_time[], double &out_res_time[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSpringUpthrustCalculator::CSpringUpthrustCalculator() :
   m_fractal_period(5), m_min_level_age(8),
   m_active_sup(0.0), m_sup_time(0), m_sup_idx(0),
   m_active_res(0.0), m_res_time(0), m_res_idx(0) {}

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSpringUpthrustCalculator::Init(int fractal_period, int min_level_age)
  {
   m_fractal_period = (fractal_period < 2) ? 2 : fractal_period;
   m_min_level_age = (min_level_age < 1) ? 1 : min_level_age;

   m_active_sup = 0.0;
   m_sup_time = 0;
   m_sup_idx = 0;
   m_active_res = 0.0;
   m_res_time = 0;
   m_res_idx = 0;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CSpringUpthrustCalculator::Calculate(int rates_total, int prev_calculated,
      const datetime &time[], const double &high[], const double &low[], const double &close[],
      const double &atr_buffer[], const double &rvol_buffer[],
      double &out_spring[], double &out_upthrust[],
      double &out_sup_level[], double &out_res_level[],
      double &out_sup_time[], double &out_res_time[])
  {
   if(rates_total < m_fractal_period + 10)
      return;

   int start = (prev_calculated == 0) ? m_fractal_period + 4 : prev_calculated - 1;
   if(start < m_fractal_period + 4)
      start = m_fractal_period + 4;

   for(int i = start; i < rates_total; i++)
     {
      out_spring[i] = EMPTY_VALUE;
      out_upthrust[i] = EMPTY_VALUE;
      out_sup_level[i] = 0.0;
      out_res_level[i] = 0.0;
      out_sup_time[i] = 0.0;
      out_res_time[i] = 0.0;

      //--- 1. Dynamic S/R Level Scan: Bill Williams 2-Bar Fractal at i-2
      if(high[i-2] > high[i-1] && high[i-2] > high[i] && high[i-2] > high[i-3] && high[i-2] > high[i-4])
        {
         m_active_res = high[i-2];
         m_res_time   = time[i-2];
         m_res_idx    = i-2;
        }
      if(low[i-2] < low[i-1] && low[i-2] < low[i] && low[i-2] < low[i-3] && low[i-2] < low[i-4])
        {
         m_active_sup = low[i-2];
         m_sup_time   = time[i-2];
         m_sup_idx    = i-2;
        }

      double atr  = atr_buffer[i];
      double rvol = rvol_buffer[i];
      double spread = high[i] - low[i];

      if(atr <= 0 || spread <= 0)
         continue;

      //--- 2. Wyckoff Spring Detection (with Age & Rejection close filters)
      if(m_active_sup > 0.0 && low[i] < m_active_sup && close[i] > m_active_sup)
        {
         // Verify level is old enough to filter out consolidation noise
         if(i - m_sup_idx >= m_min_level_age)
           {
            bool is_spring = false;
            double close_ratio = (close[i] - low[i]) / spread;

            // VSA Type 1: Low-Volume Exhaustion (No Supply) + close must be in upper half
            if(rvol < 1.0 && close_ratio >= 0.5)
               is_spring = true;
            // VSA Type 2: High-Volume Absorption (Effort vs Result) + strong bullish close
            else
               if(rvol > 1.8 && close_ratio >= 0.6)
                  is_spring = true;

            if(is_spring)
              {
               out_spring[i] = low[i] - atr * 0.3;
               out_sup_level[i] = m_active_sup;
               out_sup_time[i] = (double)m_sup_time; // Store level anchor time
              }
           }
        }

      //--- 3. Wyckoff Upthrust Detection (with Age & Rejection close filters)
      if(m_active_res > 0.0 && high[i] > m_active_res && close[i] < m_active_res)
        {
         if(i - m_res_idx >= m_min_level_age)
           {
            bool is_upthrust = false;
            double close_ratio = (high[i] - close[i]) / spread;

            // VSA Type 1: Low-Volume Exhaustion (No Demand) + close must be in lower half
            if(rvol < 1.0 && close_ratio >= 0.5)
               is_upthrust = true;
            // VSA Type 2: High-Volume Absorption (Effort vs Result) + strong bearish close
            else
               if(rvol > 1.8 && close_ratio >= 0.6)
                  is_upthrust = true;

            if(is_upthrust)
              {
               out_upthrust[i] = high[i] + atr * 0.3;
               out_res_level[i] = m_active_res;
               out_res_time[i] = (double)m_res_time; // Store level anchor time
              }
           }
        }
     }
  }

#endif // SPRINGUPTHRUST_CALCULATOR_MQH
//+------------------------------------------------------------------+
