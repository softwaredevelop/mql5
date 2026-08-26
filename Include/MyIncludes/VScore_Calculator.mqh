//+------------------------------------------------------------------+
//|                                          VScore_Calculator.mqh   |
//|      Engine for Statistical V-Score (VWAP Z-Score) Calculation.  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Overloaded initialization, bounds safety & Custom Session support

#ifndef VSCORE_CALCULATOR_MQH
#define VSCORE_CALCULATOR_MQH

#include <MyIncludes\VWAP_Calculator.mqh>

//+==================================================================+
//| Class CVScoreCalculator                                          |
//+==================================================================+
class CVScoreCalculator
  {
protected:
   int               m_period;
   CVWAPCalculator   *m_vwap_calc;

   // Persistent Buffers for Incremental Calculation
   double            m_vwap_buf[];
   double            m_vwap_odd[];
   double            m_vwap_even[];
   double            m_price[];

public:
                     CVScoreCalculator();
   virtual          ~CVScoreCalculator();

   //--- Legacy Signature (100% Backward Compatible)
   bool              Init(int period, ENUM_VWAP_PERIOD vwap_reset);

   //--- Enhanced Pro Signature (Standard Periods)
   bool              Init(const int period, const ENUM_VWAP_PERIOD vwap_reset, const ENUM_APPLIED_VOLUME vol_type,
                          const int tz_shift_hours=0, const bool is_heikin_ashi=false, const int max_history_days=0);

   //--- Enhanced Pro Signature (Custom Session)
   bool              Init(const int period, const string custom_start, const string custom_end, const ENUM_APPLIED_VOLUME vol_type,
                          const int tz_shift_hours=0, const bool is_heikin_ashi=false, const int max_history_days=0);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[],
                               double &out_vscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVScoreCalculator::CVScoreCalculator() : m_period(20), m_vwap_calc(NULL)
  {
   ArraySetAsSeries(m_vwap_buf,  false);
   ArraySetAsSeries(m_vwap_odd,  false);
   ArraySetAsSeries(m_vwap_even, false);
   ArraySetAsSeries(m_price,     false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVScoreCalculator::~CVScoreCalculator()
  {
   if(CheckPointer(m_vwap_calc) != POINTER_INVALID)
     {
      delete m_vwap_calc;
      m_vwap_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Legacy Init (Preserves compatibility with all scripts)           |
//+------------------------------------------------------------------+
bool CVScoreCalculator::Init(int period, ENUM_VWAP_PERIOD vwap_reset)
  {
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   ENUM_APPLIED_VOLUME vol_type = (volume_limit > 0) ? VOLUME_REAL : VOLUME_TICK;
   return Init(period, vwap_reset, vol_type, 0, false, 0);
  }

//+------------------------------------------------------------------+
//| Enhanced Init (Standard Periods)                                 |
//+------------------------------------------------------------------+
bool CVScoreCalculator::Init(const int period, const ENUM_VWAP_PERIOD vwap_reset, const ENUM_APPLIED_VOLUME vol_type,
                             const int tz_shift_hours, const bool is_heikin_ashi, const int max_history_days)
  {
   m_period = (period < 2) ? 2 : period;

   if(CheckPointer(m_vwap_calc) != POINTER_INVALID)
     {
      delete m_vwap_calc;
      m_vwap_calc = NULL;
     }

   if(is_heikin_ashi)
      m_vwap_calc = new CVWAPCalculator_HA();
   else
      m_vwap_calc = new CVWAPCalculator();

   if(CheckPointer(m_vwap_calc) == POINTER_INVALID)
      return false;

   return m_vwap_calc.Init(vwap_reset, vol_type, tz_shift_hours, true, max_history_days);
  }

//+------------------------------------------------------------------+
//| Enhanced Init (Custom Session)                                   |
//+------------------------------------------------------------------+
bool CVScoreCalculator::Init(const int period, const string custom_start, const string custom_end, const ENUM_APPLIED_VOLUME vol_type,
                             const int tz_shift_hours, const bool is_heikin_ashi, const int max_history_days)
  {
   m_period = (period < 2) ? 2 : period;

   if(CheckPointer(m_vwap_calc) != POINTER_INVALID)
     {
      delete m_vwap_calc;
      m_vwap_calc = NULL;
     }

   if(is_heikin_ashi)
      m_vwap_calc = new CVWAPCalculator_HA();
   else
      m_vwap_calc = new CVWAPCalculator();

   if(CheckPointer(m_vwap_calc) == POINTER_INVALID)
      return false;

   return m_vwap_calc.Init(custom_start, custom_end, vol_type, true, max_history_days, tz_shift_hours);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Bounds-Safe O(1))                              |
//+------------------------------------------------------------------+
void CVScoreCalculator::Calculate(const int rates_total, const int prev_calculated,
                                  const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                  const long &tick_volume[], const long &volume[],
                                  double &out_vscore[])
  {
   if(rates_total < m_period || CheckPointer(m_vwap_calc) == POINTER_INVALID)
      return;

// 1. Safe Allocation of Internal Buffers
   if(ArraySize(m_vwap_buf) != rates_total)
     {
      ArrayResize(m_vwap_buf,  rates_total);
      ArrayResize(m_vwap_odd,  rates_total);
      ArrayResize(m_vwap_even, rates_total);
      ArrayResize(m_price,     rates_total);

      ArraySetAsSeries(m_vwap_buf,  false);
      ArraySetAsSeries(m_vwap_odd,  false);
      ArraySetAsSeries(m_vwap_even, false);
      ArraySetAsSeries(m_price,     false);
     }

   if(ArraySize(out_vscore) != rates_total)
     {
      ArrayResize(out_vscore, rates_total);
      ArraySetAsSeries(out_vscore, false);
      ArrayInitialize(out_vscore, 0.0);
     }

// 2. Compute Underlying VWAP
   m_vwap_calc.Calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, m_vwap_odd, m_vwap_even);

   int start = (prev_calculated > m_period) ? (prev_calculated - 1) : (m_period - 1);
   if(start < m_period - 1)
      start = m_period - 1;

// 3. Compute V-Score (Standard Deviation Distance from VWAP)
   for(int i = start; i < rates_total; i++)
     {
      m_price[i] = close[i];

      double current_vwap = (m_vwap_odd[i] != EMPTY_VALUE && m_vwap_odd[i] > 0.0) ? m_vwap_odd[i] : m_vwap_even[i];
      m_vwap_buf[i] = current_vwap;

      if(current_vwap == 0.0 || current_vwap == EMPTY_VALUE)
        {
         out_vscore[i] = 0.0;
         continue;
        }

      double sum_sq_diff = 0.0;

      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p = m_price[idx];
         double v = m_vwap_buf[idx];

         if(v == 0.0 || v == EMPTY_VALUE)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / (double)m_period);

      if(std_dev > 1.0e-9)
         out_vscore[i] = (close[i] - current_vwap) / std_dev;
      else
         out_vscore[i] = 0.0;
     }
  }

#endif // VSCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
