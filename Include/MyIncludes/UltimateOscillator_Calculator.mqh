//+------------------------------------------------------------------+
//|                                 UltimateOscillator_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi Ultimate Oscillator.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CUltimateOscillatorCalculator (Base Class)      |
//|                                                                  |
//+==================================================================+
class CUltimateOscillatorCalculator
  {
protected:
   int               m_p1, m_p2, m_p3;
   //--- CORRECTED: Removed invalid const member initialization
   double            m_src_high[], m_src_low[], m_src_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CUltimateOscillatorCalculator(void) {};
   virtual          ~CUltimateOscillatorCalculator(void) {};

   bool              Init(int p1, int p2, int p3);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &uo_buffer[]);
  };

//+------------------------------------------------------------------+
//| CUltimateOscillatorCalculator: Initialization                    |
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator::Init(int p1, int p2, int p3)
  {
   m_p1 = (p1 < 1) ? 1 : p1;
   m_p2 = (p2 < 1) ? 1 : p2;
   m_p3 = (p3 < 1) ? 1 : p3;
   return true;
  }

//+------------------------------------------------------------------+
//| CUltimateOscillatorCalculator: Main Calculation Method           |
//+------------------------------------------------------------------+
void CUltimateOscillatorCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &uo_buffer[])
  {
   if(rates_total <= MathMax(m_p1, MathMax(m_p2, m_p3)))
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

//--- CORRECTED: Define constants locally inside the method
   const double W1=4.0, W2=2.0, W3=1.0, W_SUM=7.0;

   double bp[], tr[];
   ArrayResize(bp, rates_total);
   ArrayResize(tr, rates_total);
   for(int i=1; i<rates_total; i++)
     {
      double true_low = MathMin(m_src_low[i], m_src_close[i-1]);
      bp[i] = m_src_close[i] - true_low;
      tr[i] = MathMax(m_src_high[i], m_src_close[i-1]) - true_low;
     }

   double sum_bp1=0, sum_tr1=0, sum_bp2=0, sum_tr2=0, sum_bp3=0, sum_tr3=0;
   for(int i = 1; i < rates_total; i++)
     {
      sum_bp1+=bp[i];
      sum_tr1+=tr[i];
      sum_bp2+=bp[i];
      sum_tr2+=tr[i];
      sum_bp3+=bp[i];
      sum_tr3+=tr[i];
      if(i>m_p1)
        {
         sum_bp1-=bp[i-m_p1];
         sum_tr1-=tr[i-m_p1];
        }
      if(i>m_p2)
        {
         sum_bp2-=bp[i-m_p2];
         sum_tr2-=tr[i-m_p2];
        }
      if(i>m_p3)
        {
         sum_bp3-=bp[i-m_p3];
         sum_tr3-=tr[i-m_p3];
        }
      if(i >= m_p3)
        {
         double avg1 = (sum_tr1 > 0) ? sum_bp1 / sum_tr1 : 0;
         double avg2 = (sum_tr2 > 0) ? sum_bp2 / sum_tr2 : 0;
         double avg3 = (sum_tr3 > 0) ? sum_bp3 / sum_tr3 : 0;
         uo_buffer[i] = 100.0 * (W1*avg1 + W2*avg2 + W3*avg3) / W_SUM;
        }
     }
  }

//+------------------------------------------------------------------+
//| CUltimateOscillatorCalculator: Prepares the standard source data.|
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CUltimateOscillatorCalculator_HA (Heikin Ashi)    |
//|                                                                  |
//+==================================================================+
class CUltimateOscillatorCalculator_HA : public CUltimateOscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CUltimateOscillatorCalculator_HA: Prepares the HA source data.   |
//+------------------------------------------------------------------+
bool CUltimateOscillatorCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(m_src_high, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayResize(m_src_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_src_high, m_src_low, m_src_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
