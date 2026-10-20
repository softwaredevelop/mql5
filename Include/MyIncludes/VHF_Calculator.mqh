//+------------------------------------------------------------------+
//|                                            VHF_Calculator.mqh    |
//|      Engine for Vertical Horizontal Filter (Adam White, 1991).   |
//|      Algorithm: Selectable (Standard Close vs High-Low Range).   |
//|      VERSION 1.20: Chronological Safety & 100% Backward Compat.  |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Enterprise: Enforced Chronological Alignment & Zero-Heap Execution
#property description "High-performance calculation engine for Vertical Horizontal Filter (VHF)."

#ifndef VHF_CALCULATOR_MQH
#define VHF_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

#ifndef ENUM_VHF_MODE_DEFINED
#define ENUM_VHF_MODE_DEFINED
enum ENUM_VHF_MODE
  {
   VHF_MODE_CLOSE_ONLY, // Adam White Classic (Highest Close - Lowest Close)
   VHF_MODE_HIGH_LOW    // Professional Range (Highest High - Lowest Low)
  };
#endif

//+==================================================================+
//|             CLASS 1: CVHFCalculator (Base Class)                 |
//+==================================================================+
class CVHFCalculator
  {
protected:
   int               m_period;
   ENUM_VHF_MODE     m_mode;

   // Data Buffers
   double            m_price[]; // Close/Source Price (Denominator & Classic Numerator)
   double            m_high[];  // High Prices (Numerator High-Low Mode)
   double            m_low[];   // Low Prices (Numerator High-Low Mode)

   virtual bool      PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVHFCalculator(void);
   virtual          ~CVHFCalculator(void) {};

   bool              Init(const int period, const ENUM_VHF_MODE mode);
   int               GetPeriod(void) const { return m_period; }
   ENUM_VHF_MODE     GetMode(void)   const { return m_mode; }

   //--- STRICT INTERFACE: Preserved 8-parameter signature (100% backward compatible with existing scripts)
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[]);

   //--- EXTENDED INTERFACE: With history limit support for massive workspaces
   void              Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[], const int history_limit);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVHFCalculator::CVHFCalculator(void) :
   m_period(28),
   m_mode(VHF_MODE_CLOSE_ONLY)
  {
   ArraySetAsSeries(m_price, false);
   ArraySetAsSeries(m_high,  false);
   ArraySetAsSeries(m_low,   false);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVHFCalculator::Init(const int period, const ENUM_VHF_MODE mode)
  {
   m_period = (period < 2) ? 2 : period;
   m_mode   = mode;
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard Chronological Alignment)                  |
//+------------------------------------------------------------------+
bool CVHFCalculator::PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
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
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         case PRICE_CLOSE:
         default:
            m_price[i] = close[i];
            break;
        }

      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         m_high[i] = high[i];
         m_low[i]  = low[i];
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Legacy Signature: 8-Parameters (100% Backward Compatible)        |
//+------------------------------------------------------------------+
void CVHFCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[])
  {
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, out_vhf, 0);
  }

//+------------------------------------------------------------------+
//| Extended Signature: With History Limit & Pipelined Execution     |
//+------------------------------------------------------------------+
void CVHFCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[], const int history_limit)
  {
   if(rates_total <= m_period)
      return;

   if(ArraySize(out_vhf) != rates_total)
     {
      ArrayResize(out_vhf, rates_total);
      ArraySetAsSeries(out_vhf, false);
     }

// Safe allocation and chronological indexing of internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);

      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         ArrayResize(m_high, rates_total);
         ArrayResize(m_low,  rates_total);
         ArraySetAsSeries(m_high, false);
         ArraySetAsSeries(m_low,  false);
        }
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PrepareData(rates_total, start_prep, price_type, open, high, low, close))
      return;

   int start_index = (prev_calculated > m_period) ? (prev_calculated - 1) : m_period;
   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start_index)
         start_index = limit_start;
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start_index; i++)
         out_vhf[i] = EMPTY_VALUE;
     }

// Main Pipelined Calculation Loop
   for(int i = start_index; i < rates_total; i++)
     {
      double max_p = -DBL_MAX;
      double min_p =  DBL_MAX;
      double sum_change = 0.0;
      int win_start = i - m_period + 1;

      // 1. Numerator: Vertical Extremes
      if(m_mode == VHF_MODE_CLOSE_ONLY)
        {
         for(int k = 0; k < m_period; k++)
           {
            double p = m_price[win_start + k];
            if(p > max_p)
               max_p = p;
            if(p < min_p)
               min_p = p;
           }
        }
      else // VHF_MODE_HIGH_LOW
        {
         for(int k = 0; k < m_period; k++)
           {
            int idx = win_start + k;
            if(m_high[idx] > max_p)
               max_p = m_high[idx];
            if(m_low[idx]  < min_p)
               min_p = m_low[idx];
           }
        }

      // 2. Denominator: Cumulative Path Length (Sum of 1-bar price increments)
      for(int k = 0; k < m_period; k++)
        {
         int idx = win_start + k;
         sum_change += MathAbs(m_price[idx] - m_price[idx - 1]);
        }

      // 3. Compute Final Ratio
      if(sum_change > 1.0e-9)
        {
         double vhf = (max_p - min_p) / sum_change;
         out_vhf[i] = (vhf > 1.0) ? 1.0 : vhf; // Bounded to theoretical 1.0 limit
        }
      else
        {
         out_vhf[i] = 0.0;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CVHFCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CVHFCalculator_HA : public CVHFCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                      const double &open[], const double &high[], const double &low[], const double &close[]) override;

public:
                     CVHFCalculator_HA(void);
   virtual               ~CVHFCalculator_HA(void) {};
  };

//+------------------------------------------------------------------+
//| Constructor (Heikin Ashi)                                        |
//+------------------------------------------------------------------+
CVHFCalculator_HA::CVHFCalculator_HA(void)
  {
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi Chronological Pipeline)                |
//+------------------------------------------------------------------+
bool CVHFCalculator_HA::PrepareData(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
                                    const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArrayResize(m_ha_high,  rates_total);
      ArrayResize(m_ha_low,   rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         case PRICE_CLOSE:
         default:
            m_price[i] = m_ha_close[i];
            break;
        }

      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         m_high[i] = m_ha_high[i];
         m_low[i]  = m_ha_low[i];
        }
     }
   return true;
  }

#endif // VHF_CALCULATOR_MQH
//+------------------------------------------------------------------+
