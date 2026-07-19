//+------------------------------------------------------------------+
//|                                               ATR_Calculator.mqh |
//|         VERSION 3.00: Optimized state safety & zero-lag registers |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Fully optimized with chronological safeguards and type-cast efficiency
#property description "Institutional-grade stateful ATR Calculator Engine."

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
   int                   m_atr_period;
   ENUM_ATR_DISPLAY_MODE m_display_mode;

   //--- Persistent State Buffers
   double                m_tr[];
   double                m_atr_raw[];

   virtual bool          PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CATRCalculator(void) {};
   virtual              ~CATRCalculator(void) {};

   bool                  Init(int period, ENUM_ATR_DISPLAY_MODE mode);
   int                   GetPeriod(void) const { return m_atr_period; }

   void                  Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[]);
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
//| Main Calculation (Strict Chronological Safety & Performance)      |
//+------------------------------------------------------------------+
void CATRCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[])
  {
//--- Safety 1: Period check
   if(rates_total <= m_atr_period)
      return;

//--- Safety 2: Boundary check to prevent access violations
   if(ArraySize(open) < rates_total || ArraySize(high) < rates_total ||
      ArraySize(low) < rates_total || ArraySize(close) < rates_total)
     {
      return;
     }

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_tr) != rates_total)
     {
      ArrayResize(m_tr,      rates_total);
      ArrayResize(m_atr_raw, rates_total);

      ArraySetAsSeries(m_tr,      false);
      ArraySetAsSeries(m_atr_raw, false);
     }

//--- Enforce chronological safety on caller output buffer if resized
   if(ArraySize(atr_buffer) != rates_total)
     {
      ArrayResize(atr_buffer, rates_total);
      ArraySetAsSeries(atr_buffer, false);
     }

//--- Prepare True Range
   if(!PrepareTrueRange(rates_total, start_index, open, high, low, close))
      return;

   int loop_start = MathMax(m_atr_period, start_index);
   double period_double = (double)m_atr_period;

//--- Primary calculation loop (Wilder's RMA smoothing)
   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == m_atr_period) // Initial SMA setup
        {
         double sum_tr = 0.0;
         for(int j = 0; j < m_atr_period; j++)
            sum_tr += m_tr[i - j];
         m_atr_raw[i] = sum_tr / period_double;
        }
      else // Dynamic state-safe recursive smoothing
        {
         m_atr_raw[i] = (m_atr_raw[i - 1] * (period_double - 1.0) + m_tr[i]) / period_double;
        }
     }

//--- Map raw values to display output
   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_display_mode == ATR_PERCENT)
        {
         atr_buffer[i] = (close[i] > 0.0) ? (m_atr_raw[i] / close[i]) * 100.0 : 0.0;
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

   if(start_index == 0)
     {
      m_tr[0] = high[0] - low[0];
     }

   for(; i < rates_total; i++)
     {
      double range1 = high[i] - low[i];
      double range2 = MathAbs(high[i] - close[i - 1]);
      double range3 = MathAbs(low[i] - close[i - 1]);
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
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool          PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare True Range (Heikin Ashi - Chronologically Safe)          |
//+------------------------------------------------------------------+
bool CATRCalculator_HA::PrepareTrueRange(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- Resize HA caches and enforce chronological alignment
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

//--- Delegate calculation to Heikin Ashi core toolkit
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
      double range2 = MathAbs(m_ha_high[i] - m_ha_close[i - 1]);
      double range3 = MathAbs(m_ha_low[i] - m_ha_close[i - 1]);
      m_tr[i] = MathMax(range1, MathMax(range2, range3));
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
