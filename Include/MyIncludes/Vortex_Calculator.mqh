//+------------------------------------------------------------------+
//|                                             Vortex_Calculator.mqh|
//|      Calculation engine for Standard and Heikin Ashi Vortex.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CVortexCalculator (Base Class)              |
//|                                                                  |
//+==================================================================+
class CVortexCalculator
  {
protected:
   int               m_period;
   double            m_src_high[], m_src_low[], m_src_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVortexCalculator(void) {};
   virtual          ~CVortexCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vi_plus_buffer[], double &vi_minus_buffer[]);
  };

//+------------------------------------------------------------------+
//| CVortexCalculator: Initialization                                |
//+------------------------------------------------------------------+
bool CVortexCalculator::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| CVortexCalculator: Main Calculation Method (Shared Logic)        |
//+------------------------------------------------------------------+
void CVortexCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &vi_plus_buffer[], double &vi_minus_buffer[])
  {
   if(rates_total <= m_period)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double tr[], vm_plus[], vm_minus[];
   ArrayResize(tr, rates_total);
   ArrayResize(vm_plus, rates_total);
   ArrayResize(vm_minus, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      tr[i]       = MathMax(m_src_high[i], m_src_close[i-1]) - MathMin(m_src_low[i], m_src_close[i-1]);
      vm_plus[i]  = MathAbs(m_src_high[i] - m_src_low[i-1]);
      vm_minus[i] = MathAbs(m_src_low[i] - m_src_high[i-1]);
     }

   double sum_tr = 0, sum_vplus = 0, sum_vminus = 0;
   for(int i = 1; i < rates_total; i++)
     {
      sum_tr     += tr[i];
      sum_vplus  += vm_plus[i];
      sum_vminus += vm_minus[i];

      if(i > m_period)
        {
         sum_tr     -= tr[i - m_period];
         sum_vplus  -= vm_plus[i - m_period];
         sum_vminus -= vm_minus[i - m_period];
        }

      if(i >= m_period)
        {
         if(sum_tr > 0)
           {
            vi_plus_buffer[i]  = sum_vplus / sum_tr;
            vi_minus_buffer[i] = sum_vminus / sum_tr;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CVortexCalculator: Prepares the standard source data.            |
//+------------------------------------------------------------------+
bool CVortexCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|           CLASS 2: CVortexCalculator_HA (Heikin Ashi)            |
//|                                                                  |
//+==================================================================+
class CVortexCalculator_HA : public CVortexCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CVortexCalculator_HA: Prepares the HA source data.               |
//+------------------------------------------------------------------+
bool CVortexCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
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
