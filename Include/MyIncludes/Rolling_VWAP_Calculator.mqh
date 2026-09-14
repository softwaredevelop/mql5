//+------------------------------------------------------------------+
//|                                   Rolling_VWAP_Calculator.mqh   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef ROLLING_VWAP_CALCULATOR_MQH
#define ROLLING_VWAP_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for Rolling Window Mode
#ifndef ENUM_ROLLING_TYPE_DEFINED
#define ENUM_ROLLING_TYPE_DEFINED
enum ENUM_ROLLING_TYPE
  {
   ROLLING_BARS, // Fixed Bar Window
   ROLLING_TIME  // Fixed Time Window (Minutes)
  };
#endif

//+==================================================================+
//| CLASS: CRollingVWAPCalculator                                    |
//| High-Performance Prefix-Sum Engine for Continuous Rolling VWAP   |
//+==================================================================+
class CRollingVWAPCalculator
  {
protected:
   ENUM_ROLLING_TYPE   m_rolling_type;
   int                 m_window_bars;
   long                m_window_seconds;
   ENUM_APPLIED_VOLUME m_volume_type;
   bool                m_enabled;

   //--- Persistent Cache Buffers
   double              m_typical_price[];
   double              m_sum_tpv[];
   double              m_sum_vol[];

   virtual bool        PrepareSourceData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

public:
                     CRollingVWAPCalculator(void);
   virtual            ~CRollingVWAPCalculator(void) {};

   bool                Init(const ENUM_ROLLING_TYPE rolling_type,
                            const int window_value,
                            const ENUM_APPLIED_VOLUME vol_type,
                            const bool enabled = true);

   void                Calculate(const int rates_total,
                                 const int prev_calculated,
                                 const datetime &time[],
                                 const double &open[],
                                 const double &high[],
                                 const double &low[],
                                 const double &close[],
                                 const long &tick_volume[],
                                 const long &volume[],
                                 double &rolling_vwap[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRollingVWAPCalculator::CRollingVWAPCalculator(void) :
   m_rolling_type(ROLLING_BARS),
   m_window_bars(100),
   m_window_seconds(86400),
   m_volume_type(VOLUME_TICK),
   m_enabled(true)
  {
   ArraySetAsSeries(m_typical_price, false);
   ArraySetAsSeries(m_sum_tpv,       false);
   ArraySetAsSeries(m_sum_vol,       false);
  }

//+------------------------------------------------------------------+
//| Engine Initialization                                            |
//+------------------------------------------------------------------+
bool CRollingVWAPCalculator::Init(const ENUM_ROLLING_TYPE rolling_type,
                                  const int window_value,
                                  const ENUM_APPLIED_VOLUME vol_type,
                                  const bool enabled)
  {
   m_enabled      = enabled;
   m_rolling_type = rolling_type;
   m_volume_type  = vol_type;

   if(!m_enabled)
      return true;

   if(m_rolling_type == ROLLING_BARS)
     {
      m_window_bars = (window_value > 1) ? window_value : 100;
     }
   else
     {
      int minutes = (window_value > 0) ? window_value : 1440;
      m_window_seconds = (long)minutes * 60;
     }

   if(m_volume_type == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) <= 0)
     {
      PrintFormat("Rolling VWAP Warning: Real Volume not available for '%s'. Falling back to Tick Volume.", _Symbol);
      m_volume_type = VOLUME_TICK;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Source Price Preparation (Typical Price: (H+L+C)/3)              |
//+------------------------------------------------------------------+
bool CRollingVWAPCalculator::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_typical_price) != rates_total)
     {
      ArrayResize(m_typical_price, rates_total);
      ArraySetAsSeries(m_typical_price, false);
     }

   for(int i = start_index; i < rates_total; i++)
     {
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Incremental Prefix-Sum Calculation Pipeline (O(1))               |
//+------------------------------------------------------------------+
void CRollingVWAPCalculator::Calculate(const int rates_total,
                                       const int prev_calculated,
                                       const datetime &time[],
                                       const double &open[],
                                       const double &high[],
                                       const double &low[],
                                       const double &close[],
                                       const long &tick_volume[],
                                       const long &volume[],
                                       double &rolling_vwap[])
  {
   if(!m_enabled || rates_total < 1)
      return;

// Safe output array resizing
   if(ArraySize(rolling_vwap) != rates_total)
     {
      ArrayResize(rolling_vwap, rates_total);
      ArraySetAsSeries(rolling_vwap, false);
      ArrayInitialize(rolling_vwap, EMPTY_VALUE);
     }

// Safe prefix cache array resizing (Preserving previous historical states)
   if(ArraySize(m_sum_tpv) != rates_total)
     {
      ArrayResize(m_sum_tpv, rates_total);
      ArrayResize(m_sum_vol, rates_total);
      ArraySetAsSeries(m_sum_tpv, false);
      ArraySetAsSeries(m_sum_vol, false);
     }

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

// Step 1: Update Cumulative Prefix Sums
   for(int i = start_index; i < rates_total; i++)
     {
      long current_vol = (m_volume_type == VOLUME_REAL) ? volume[i] : tick_volume[i];
      if(current_vol < 1)
         current_vol = 1;

      double current_tpv = m_typical_price[i] * (double)current_vol;

      if(i == 0)
        {
         m_sum_tpv[0] = current_tpv;
         m_sum_vol[0] = (double)current_vol;
        }
      else
        {
         m_sum_tpv[i] = m_sum_tpv[i - 1] + current_tpv;
         m_sum_vol[i] = m_sum_vol[i - 1] + (double)current_vol;
        }
     }

// Step 2: Compute Continuous Rolling Window via Subtraction
   for(int i = start_index; i < rates_total; i++)
     {
      double diff_tpv = 0.0;
      double diff_vol = 0.0;

      if(m_rolling_type == ROLLING_BARS)
        {
         int left_idx = i - m_window_bars;
         if(left_idx < 0)
           {
            // Initial Warmup Phase: expanding cumulative sum
            diff_tpv = m_sum_tpv[i];
            diff_vol = m_sum_vol[i];
           }
         else
           {
            // Rolling Window Window
            diff_tpv = m_sum_tpv[i] - m_sum_tpv[left_idx];
            diff_vol = m_sum_vol[i] - m_sum_vol[left_idx];
           }
        }
      else // ROLLING_TIME
        {
         datetime cutoff_time = time[i] - (datetime)m_window_seconds;

         // Microsecond binary search for oldest bar within the sliding time window
         int left_idx = ArrayBsearch(time, cutoff_time);
         if(left_idx < 0)
            left_idx = 0;

         // Ensure left_idx matches earliest valid bar >= cutoff_time
         if(time[left_idx] < cutoff_time && left_idx < i)
            left_idx++;

         if(left_idx <= 0)
           {
            diff_tpv = m_sum_tpv[i];
            diff_vol = m_sum_vol[i];
           }
         else
           {
            diff_tpv = m_sum_tpv[i] - m_sum_tpv[left_idx - 1];
            diff_vol = m_sum_vol[i] - m_sum_vol[left_idx - 1];
           }
        }

      // Robust Zero Division Guard
      if(diff_vol > 0.0)
         rolling_vwap[i] = diff_tpv / diff_vol;
      else
         rolling_vwap[i] = m_typical_price[i];
     }
  }

//+==================================================================+
//| CLASS: CRollingVWAPCalculator_HA                                 |
//| Heikin Ashi Smoothed Rolling VWAP Variant                        |
//+==================================================================+
class CRollingVWAPCalculator_HA : public CRollingVWAPCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PrepareSourceData(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Heikin Ashi Source Price Preparation                             |
//+------------------------------------------------------------------+
bool CRollingVWAPCalculator_HA::PrepareSourceData(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
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

   if(ArraySize(m_typical_price) != rates_total)
     {
      ArrayResize(m_typical_price, rates_total);
      ArraySetAsSeries(m_typical_price, false);
     }

   for(int i = start_index; i < rates_total; i++)
     {
      m_typical_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
     }

   return true;
  }

#endif // ROLLING_VWAP_CALCULATOR_MQH
//+------------------------------------------------------------------+
