//+------------------------------------------------------------------+
//|                                               ATR_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi ATR.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CATRCalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CATRCalculator
  {
protected:
   int               m_atr_period;

   //--- Virtual method for preparing the raw True Range values.
   virtual void      PrepareTrueRange(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &tr_buffer[]);

public:
                     CATRCalculator(void) {};
   virtual          ~CATRCalculator(void) {};

   //--- Public methods
   bool              Init(int period);
   int               GetPeriod(void) const { return m_atr_period; }
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[]);
  };

//+------------------------------------------------------------------+
//| CATRCalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CATRCalculator::Init(int period)
  {
   m_atr_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| CATRCalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CATRCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &atr_buffer[])
  {
   if(rates_total <= m_atr_period)
      return;

//--- STEP 1: Calculate True Range (delegated to virtual method)
   double tr[];
   PrepareTrueRange(rates_total, open, high, low, close, tr);

//--- STEP 2: Calculate ATR (Wilder's Smoothing)
   for(int i = 1; i < rates_total; i++)
     {
      if(i == m_atr_period) // Initialization with a simple average of TR
        {
         double sum_tr = 0;
         for(int j = 1; j <= m_atr_period; j++)
            sum_tr += tr[j];
         atr_buffer[i] = sum_tr / m_atr_period;
        }
      else
         if(i > m_atr_period) // Recursive calculation
           {
            atr_buffer[i] = (atr_buffer[i-1] * (m_atr_period - 1) + tr[i]) / m_atr_period;
           }
     }
  }

//+------------------------------------------------------------------+
//| CATRCalculator: Prepares raw TR from standard prices.            |
//+------------------------------------------------------------------+
void CATRCalculator::PrepareTrueRange(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &tr_buffer[])
  {
   ArrayResize(tr_buffer, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      double range1 = high[i] - low[i];
      double range2 = MathAbs(high[i] - close[i-1]);
      double range3 = MathAbs(low[i] - close[i-1]);
      tr_buffer[i] = MathMax(range1, MathMax(range2, range3));
     }
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CATRCalculator_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CATRCalculator_HA : public CATRCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   //--- Overridden method to prepare Heikin Ashi based TR
   virtual void      PrepareTrueRange(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &tr_buffer[]) override;
  };

//+------------------------------------------------------------------+
//| CATRCalculator_HA: Prepares raw TR from HA prices.               |
//+------------------------------------------------------------------+
void CATRCalculator_HA::PrepareTrueRange(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &tr_buffer[])
  {
//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate the HA candles first
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, calculate TR using the HA candles
   ArrayResize(tr_buffer, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      double range1 = ha_high[i] - ha_low[i];
      double range2 = MathAbs(ha_high[i] - ha_close[i-1]);
      double range3 = MathAbs(ha_low[i] - ha_close[i-1]);
      tr_buffer[i] = MathMax(range1, MathMax(range2, range3));
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
