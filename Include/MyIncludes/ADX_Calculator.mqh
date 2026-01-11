//+------------------------------------------------------------------+
//|                                               ADX_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi ADX.      |
//|        VERSION 3.00: Refactored to use DMI_Engine.               |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\DMI_Engine.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CADXCalculator
  {
protected:
   CDMIEngine        *m_dmi_engine;
   int               m_adx_period;
   double            m_dx[]; // Internal DX buffer

   virtual void      CreateEngine(void);

public:
                     CADXCalculator(void);
   virtual          ~CADXCalculator(void);

   bool              Init(int period);
   int               GetPeriod(void) const { return m_adx_period; }

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CADXCalculator::CADXCalculator(void) { m_dmi_engine = NULL; }
CADXCalculator::~CADXCalculator(void) { if(CheckPointer(m_dmi_engine) != POINTER_INVALID) delete m_dmi_engine; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CADXCalculator::CreateEngine(void)
  {
   m_dmi_engine = new CDMIEngine();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CADXCalculator::Init(int period)
  {
   m_adx_period = (period < 1) ? 1 : period;
   CreateEngine();
   return m_dmi_engine.Init(m_adx_period);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CADXCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_adx_period * 2)
      return;

   if(ArraySize(m_dx) != rates_total)
      ArrayResize(m_dx, rates_total);

// 1. Calculate DI values using Engine
   m_dmi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, pdi_buffer, ndi_buffer);

// 2. Calculate DX
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_adx_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double di_sum = pdi_buffer[i] + ndi_buffer[i];
      if(di_sum != 0.0)
         m_dx[i] = MathAbs(pdi_buffer[i] - ndi_buffer[i]) / di_sum * 100.0;
      else
         m_dx[i] = 0.0;
     }

// 3. Calculate ADX (Wilder's Smoothing on DX)
   int adx_start = m_adx_period * 2 - 1;
   int loop_start_adx = MathMax(adx_start, start_index);

   for(int i = loop_start_adx; i < rates_total; i++)
     {
      if(i == adx_start)
        {
         double sum_dx = 0;
         for(int j=i-m_adx_period+1; j<=i; j++)
            sum_dx += m_dx[j];
         adx_buffer[i] = sum_dx / m_adx_period;
        }
      else
        {
         adx_buffer[i] = (adx_buffer[i-1] * (m_adx_period - 1) + m_dx[i]) / m_adx_period;
        }
     }
  }

//--- HA Subclass
class CADXCalculator_HA : public CADXCalculator
  {
protected:
   virtual void      CreateEngine(void) override { m_dmi_engine = new CDMIEngine_HA(); }
  };
//+------------------------------------------------------------------+
