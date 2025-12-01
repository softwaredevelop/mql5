//+------------------------------------------------------------------+
//|                                               ATR_Calculator.mqh |
//|         VERSION 2.21: Fixed ATR Percent incremental bug.         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- CORRECTED: Moved enum here to be accessible by other calculators ---
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };

//--- NEW: Enum for display mode ---
enum ENUM_ATR_DISPLAY_MODE { ATR_POINTS, ATR_PERCENT };

//+==================================================================+
//|             CLASS 1: CATRCalculator (Base Class)                 |
//+==================================================================+
class CATRCalculator
  {
protected:
   int               m_atr_period;
   ENUM_ATR_DISPLAY_MODE m_display_mode;

   //--- Persistent Buffer for True Range and Raw ATR
   double            m_tr[];
   double            m_atr_raw[]; // Stores ATR in points for recursion

   //--- Updated: Accepts start_index
   virtual bool      PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CATRCalculator(void) {};
   virtual          ~CATRCalculator(void) {};

   bool              Init(int period, ENUM_ATR_DISPLAY_MODE mode);
   int               GetPeriod(void) const { return m_atr_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CATRCalculator::Init(int period, ENUM_ATR_DISPLAY_MODE mode)
  {
   m_atr_period = (period < 1) ? 1 : period;
   m_display_mode = mode;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CATRCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[])
  {
   if(rates_total <= m_atr_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_tr) != rates_total)
     {
      ArrayResize(m_tr, rates_total);
      ArrayResize(m_atr_raw, rates_total);
     }

//--- 3. Prepare True Range (Optimized)
   if(!PrepareTrueRange(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate ATR (Wilder's Smoothing) using Internal Raw Buffer
   int loop_start = MathMax(m_atr_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == m_atr_period) // Initialization
        {
         double sum_tr = 0;
         for(int j = 1; j <= m_atr_period; j++)
            sum_tr += m_tr[j];
         m_atr_raw[i] = sum_tr / m_atr_period;
        }
      else
         // Recursive calculation uses m_atr_raw[i-1] which is always in POINTS
         m_atr_raw[i] = (m_atr_raw[i-1] * (m_atr_period - 1) + m_tr[i]) / m_atr_period;
     }

//--- 5. Output to Buffer (Convert if needed)
// We must update the output buffer from loop_start
   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_display_mode == ATR_PERCENT)
        {
         if(close[i] > 0)
            atr_buffer[i] = (m_atr_raw[i] / close[i]) * 100.0;
         else
            atr_buffer[i] = 0;
        }
      else
        {
         atr_buffer[i] = m_atr_raw[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare True Range (Standard - Optimized)                        |
//+------------------------------------------------------------------+
bool CATRCalculator::PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   int i = (start_index < 1) ? 1 : start_index;

   for(; i < rates_total; i++)
     {
      double range1 = high[i] - low[i];
      double range2 = MathAbs(high[i] - close[i-1]);
      double range3 = MathAbs(low[i] - close[i-1]);
      m_tr[i] = MathMax(range1, MathMax(range2, range3));
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CATRCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CATRCalculator_HA : public CATRCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare True Range (Heikin Ashi - Optimized)                     |
//+------------------------------------------------------------------+
bool CATRCalculator_HA::PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Calculate TR using HA candles (Optimized loop)
   int i = (start_index < 1) ? 1 : start_index;

   for(; i < rates_total; i++)
     {
      double range1 = m_ha_high[i] - m_ha_low[i];
      double range2 = MathAbs(m_ha_high[i] - m_ha_close[i-1]);
      double range3 = MathAbs(m_ha_low[i] - m_ha_close[i-1]);
      m_tr[i] = MathMax(range1, MathMax(range2, range3));
     }
   return true;
  }
//+------------------------------------------------------------------+
