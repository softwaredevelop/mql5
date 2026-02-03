//+------------------------------------------------------------------+
//|                                               ATR_Calculator.mqh |
//|         VERSION 2.32: Added strict array bounds safety checks.   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enums Definitions Guard
#ifndef ENUM_ATR_DEFINITIONS_DEFINED
#define ENUM_ATR_DEFINITIONS_DEFINED
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };
#endif
enum ENUM_ATR_DISPLAY_MODE { ATR_POINTS, ATR_PERCENT };
enum ENUM_ATR_SOURCE
  {
   ATR_SOURCE_STANDARD,
   ATR_SOURCE_HEIKIN_ASHI
  };
#endif

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
   double            m_atr_raw[];

   virtual bool      PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CATRCalculator(void) {};
   virtual          ~CATRCalculator(void) {};

   bool              Init(int period, ENUM_ATR_DISPLAY_MODE mode);
   int               GetPeriod(void) const { return m_atr_period; }

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
//| Main Calculation (Strict Safety)                                 |
//+------------------------------------------------------------------+
void CATRCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[])
  {
// Safety 1: Period Check
   if(rates_total <= m_atr_period)
      return;

// Safety 2: Array Bounds Check (Crucial Fix)
// Ensure all input arrays are at least as large as the loop limit (rates_total)
   if(ArraySize(open) < rates_total || ArraySize(high) < rates_total ||
      ArraySize(low) < rates_total || ArraySize(close) < rates_total)
     {
      // Log error (optional) and exit to prevent crash
      return;
     }

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_tr) != rates_total)
     {
      ArrayResize(m_tr, rates_total);
      ArrayResize(m_atr_raw, rates_total);
     }

// Resize output buffer if needed (usually handled by caller, but safety first)
   if(ArraySize(atr_buffer) != rates_total)
      ArrayResize(atr_buffer, rates_total);

   if(!PrepareTrueRange(rates_total, start_index, open, high, low, close))
      return;

   int loop_start = MathMax(m_atr_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == m_atr_period) // Initialization (SMA)
        {
         double sum_tr = 0;
         for(int j = 0; j < m_atr_period; j++)
            sum_tr += m_tr[i-j];
         m_atr_raw[i] = sum_tr / m_atr_period;
        }
      else // Smoothing (RMA/Wilder's)
         m_atr_raw[i] = (m_atr_raw[i-1] * (m_atr_period - 1) + m_tr[i]) / m_atr_period;
     }

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
//| Prepare True Range (Standard)                                    |
//+------------------------------------------------------------------+
bool CATRCalculator::PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Correct logic: Start from 1 to allow [i-1] access
   int i = (start_index < 1) ? 1 : start_index;

// Handle special case for index 0 (if full recalc)
   if(start_index == 0)
     {
      m_tr[0] = high[0] - low[0];
     }

   for(; i < rates_total; i++)
     {
      double range1 = high[i] - low[i];
      // Bound check implicitly handled by Calculate's Safety 2, but logic ensures i-1 >= 0
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
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare True Range (Heikin Ashi)                                 |
//+------------------------------------------------------------------+
bool CATRCalculator_HA::PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   int i = (start_index < 1) ? 1 : start_index;

   if(start_index == 0)
     {
      m_tr[0] = m_ha_high[0] - m_ha_low[0];
     }

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
//+------------------------------------------------------------------+
