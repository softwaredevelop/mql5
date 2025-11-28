//+------------------------------------------------------------------+
//|                                               ADX_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi ADX.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CADXCalculator (Base Class)                 |
//+==================================================================+
class CADXCalculator
  {
protected:
   int               m_adx_period;

   //--- Internal buffers for intermediate calculations
   //--- We keep them as class members to preserve state between ticks
   double            m_pDM[], m_nDM[], m_TR[];
   double            m_smoothed_pdm[], m_smoothed_ndm[], m_smoothed_tr[], m_dx[];

   //--- Updated: Accepts start_index for optimization
   virtual void      PrepareDirectionalMovement(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[],
         double &pDM[], double &nDM[], double &TR[]);

public:
                     CADXCalculator(void) {};
   virtual          ~CADXCalculator(void) {};

   bool              Init(int period);
   int               GetPeriod(void) const { return m_adx_period; }

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CADXCalculator::Init(int period)
  {
   m_adx_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Method (Optimized)                              |
//+------------------------------------------------------------------+
void CADXCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_adx_period * 2)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize internal buffers if needed
   if(ArraySize(m_pDM) != rates_total)
     {
      ArrayResize(m_pDM, rates_total);
      ArrayResize(m_nDM, rates_total);
      ArrayResize(m_TR, rates_total);
      ArrayResize(m_smoothed_pdm, rates_total);
      ArrayResize(m_smoothed_ndm, rates_total);
      ArrayResize(m_smoothed_tr, rates_total);
      ArrayResize(m_dx, rates_total);
     }

//--- 3. Prepare Raw DM and TR (Optimized)
   PrepareDirectionalMovement(rates_total, start_index, open, high, low, close, m_pDM, m_nDM, m_TR);

//--- 4. Calculate Smoothed PDM, NDM, and TR
//--- Ensure we don't start before the period
   int loop_start = MathMax(m_adx_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == m_adx_period) // First calculation: Simple Sum
        {
         double sum_pdm=0, sum_ndm=0, sum_tr=0;
         for(int j=1; j<=m_adx_period; j++)
           {
            sum_pdm += m_pDM[j];
            sum_ndm += m_nDM[j];
            sum_tr  += m_TR[j];
           }
         m_smoothed_pdm[i] = sum_pdm;
         m_smoothed_ndm[i] = sum_ndm;
         m_smoothed_tr[i]  = sum_tr;
        }
      else // Subsequent: Wilder's Smoothing
        {
         // This works incrementally because m_smoothed_...[i-1] preserves its value from the previous tick
         m_smoothed_pdm[i] = m_smoothed_pdm[i-1] - (m_smoothed_pdm[i-1] / m_adx_period) + m_pDM[i];
         m_smoothed_ndm[i] = m_smoothed_ndm[i-1] - (m_smoothed_ndm[i-1] / m_adx_period) + m_nDM[i];
         m_smoothed_tr[i]  = m_smoothed_tr[i-1]  - (m_smoothed_tr[i-1] / m_adx_period) + m_TR[i];
        }
     }

//--- 5. Calculate +DI, -DI, and DX
   for(int i = loop_start; i < rates_total; i++)
     {
      if(m_smoothed_tr[i] != 0.0)
        {
         pdi_buffer[i] = (m_smoothed_pdm[i] / m_smoothed_tr[i]) * 100.0;
         ndi_buffer[i] = (m_smoothed_ndm[i] / m_smoothed_tr[i]) * 100.0;
        }
      else
        {
         pdi_buffer[i] = 0.0;
         ndi_buffer[i] = 0.0;
        }

      double di_sum = pdi_buffer[i] + ndi_buffer[i];
      if(di_sum != 0.0)
         m_dx[i] = MathAbs(pdi_buffer[i] - ndi_buffer[i]) / di_sum * 100.0;
      else
         m_dx[i] = 0.0;
     }

//--- 6. Calculate Final ADX
   int adx_start = m_adx_period * 2 - 1;
   int loop_start_adx = MathMax(adx_start, start_index);

   for(int i = loop_start_adx; i < rates_total; i++)
     {
      if(i == adx_start) // First ADX: Simple Average of DX
        {
         double sum_dx = 0;
         for(int j=i-m_adx_period+1; j<=i; j++)
            sum_dx += m_dx[j];
         adx_buffer[i] = sum_dx / m_adx_period;
        }
      else // Subsequent: Wilder's Smoothing on ADX
        {
         adx_buffer[i] = (adx_buffer[i-1] * (m_adx_period - 1) + m_dx[i]) / m_adx_period;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Raw DM (Standard - Optimized)                            |
//+------------------------------------------------------------------+
void CADXCalculator::PrepareDirectionalMovement(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[],
      double &pDM[], double &nDM[], double &TR[])
  {
// Ensure we start at least from index 1
   int i = (start_index < 1) ? 1 : start_index;

   for(; i < rates_total; i++)
     {
      pDM[i] = high[i] - high[i-1];
      nDM[i] = low[i-1] - low[i];

      if(pDM[i] < 0 || pDM[i] < nDM[i])
         pDM[i] = 0;
      if(nDM[i] < 0 || nDM[i] < pDM[i])
         nDM[i] = 0;

      TR[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }
  }

//+==================================================================+
//|             CLASS 2: CADXCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CADXCalculator_HA : public CADXCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      PrepareDirectionalMovement(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[],
         double &pDM[], double &nDM[], double &TR[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Raw DM (Heikin Ashi - Optimized)                         |
//+------------------------------------------------------------------+
void CADXCalculator_HA::PrepareDirectionalMovement(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[],
      double &pDM[], double &nDM[], double &TR[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- CRITICAL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Calculate DM/TR based on HA candles
   int i = (start_index < 1) ? 1 : start_index;

   for(; i < rates_total; i++)
     {
      pDM[i] = m_ha_high[i] - m_ha_high[i-1];
      nDM[i] = m_ha_low[i-1] - m_ha_low[i];

      if(pDM[i] < 0 || pDM[i] < nDM[i])
         pDM[i] = 0;
      if(nDM[i] < 0 || nDM[i] < pDM[i])
         nDM[i] = 0;

      TR[i] = MathMax(m_ha_high[i], m_ha_close[i-1]) - MathMin(m_ha_low[i], m_ha_close[i-1]);
     }
  }
//+------------------------------------------------------------------+
