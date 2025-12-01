//+------------------------------------------------------------------+
//|                                          Supertrend_Calculator.mqh|
//|      VERSION 3.30: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CSupertrendCalculator (Base Class)            |
//+==================================================================+
class CSupertrendCalculator
  {
protected:
   int               m_atr_period;
   double            m_factor;
   CATRCalculator    *m_atr_calculator;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_atr_buffer[]; // Internal ATR buffer

   //--- Persistent State for Supertrend Logic
   double            m_upper[], m_lower[], m_trend[];
   double            m_segment_idx[]; // Tracks segment index for coloring

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSupertrendCalculator(void);
   virtual          ~CSupertrendCalculator(void);

   bool              Init(int atr_p, double factor, ENUM_CANDLE_SOURCE atr_src);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &st_odd[], double &color_odd[], double &st_even[], double &color_even[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSupertrendCalculator::CSupertrendCalculator(void)
  {
   m_atr_calculator = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSupertrendCalculator::~CSupertrendCalculator(void)
  {
   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSupertrendCalculator::Init(int atr_p, double factor, ENUM_CANDLE_SOURCE atr_src)
  {
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_factor     = (factor <= 0) ? 3.0 : factor;

   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;

   if(atr_src == CANDLE_HEIKIN_ASHI)
      m_atr_calculator = new CATRCalculator_HA();
   else
      m_atr_calculator = new CATRCalculator();

   if(CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return false;

   return m_atr_calculator.Init(m_atr_period, ATR_POINTS);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CSupertrendCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &st_odd[], double &color_odd[], double &st_even[], double &color_even[])
  {
   if(rates_total <= m_atr_period || CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_atr_buffer, rates_total);
      ArrayResize(m_upper, rates_total);
      ArrayResize(m_lower, rates_total);
      ArrayResize(m_trend, rates_total);
      ArrayResize(m_segment_idx, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate ATR (Incremental)
   m_atr_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 5. Calculate Supertrend (Incremental Loop)
   int loop_start = (start_index < 1) ? 1 : start_index;

// Initialization for first bar
   if(loop_start == 1)
     {
      m_upper[0] = 0;
      m_lower[0] = 0;
      m_trend[0] = 0;
      m_segment_idx[0] = 1;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double hl2 = (m_src_high[i] + m_src_low[i]) / 2.0;
      double atr_val = m_factor * m_atr_buffer[i];

      double upper_basic = hl2 + atr_val;
      double lower_basic = hl2 - atr_val;

      // Recursive logic using persistent buffers [i-1]
      if(upper_basic < m_upper[i-1] || m_src_close[i-1] > m_upper[i-1])
         m_upper[i] = upper_basic;
      else
         m_upper[i] = m_upper[i-1];

      if(lower_basic > m_lower[i-1] || m_src_close[i-1] < m_lower[i-1])
         m_lower[i] = lower_basic;
      else
         m_lower[i] = m_lower[i-1];

      // Trend Logic
      if(i <= m_atr_period)
         m_trend[i] = (m_src_close[i] > hl2) ? 1 : -1;
      else
        {
         if(m_trend[i-1] == 1 && m_src_close[i] < m_lower[i])
            m_trend[i] = -1;
         else
            if(m_trend[i-1] == -1 && m_src_close[i] > m_upper[i])
               m_trend[i] = 1;
            else
               m_trend[i] = m_trend[i-1];
        }

      // Segment Index Logic (Persistent)
      if(m_trend[i] != m_trend[i-1])
         m_segment_idx[i] = m_segment_idx[i-1] + 1;
      else
         m_segment_idx[i] = m_segment_idx[i-1];

      // Output to Buffers
      int seg_idx = (int)m_segment_idx[i];

      if(m_trend[i] == 1) // Uptrend
        {
         if(seg_idx % 2 != 0) // Odd
           {
            st_odd[i] = m_lower[i];
            color_odd[i] = 0;
            st_even[i] = EMPTY_VALUE;
            color_even[i] = 0;
           }
         else // Even
           {
            st_even[i] = m_lower[i];
            color_even[i] = 0;
            st_odd[i] = EMPTY_VALUE;
            color_odd[i] = 0;
           }
        }
      else // Downtrend
        {
         if(seg_idx % 2 != 0) // Odd
           {
            st_odd[i] = m_upper[i];
            color_odd[i] = 1;
            st_even[i] = EMPTY_VALUE;
            color_even[i] = 1;
           }
         else // Even
           {
            st_even[i] = m_upper[i];
            color_even[i] = 1;
            st_odd[i] = EMPTY_VALUE;
            color_odd[i] = 1;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CSupertrendCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CSupertrendCalculator_HA (Heikin Ashi)      |
//+==================================================================+
class CSupertrendCalculator_HA : public CSupertrendCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CSupertrendCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

//--- Copy to source buffers (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
