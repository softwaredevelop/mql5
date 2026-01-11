//+------------------------------------------------------------------+
//|                                                DMI_Engine.mqh    |
//|      Core engine for Directional Movement Index calculations.    |
//|      Calculates +DI, -DI, TR, +DM, -DM.                          |
//|      VERSION 1.00                                                |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CDMIEngine (Base Class)                     |
//+==================================================================+
class CDMIEngine
  {
protected:
   int               m_period;

   //--- Persistent Buffers
   double            m_pDM[], m_nDM[], m_TR[];
   double            m_smoothed_pdm[], m_smoothed_ndm[], m_smoothed_tr[];

   //--- Internal Price Buffers (for TR calculation)
   double            m_high[], m_low[], m_close[];

   //--- Virtual Prepare (Standard vs HA)
   virtual void      PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDMIEngine(void) {};
   virtual          ~CDMIEngine(void) {};

   bool              Init(int period);
   int               GetPeriod(void) const { return m_period; }

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDMIEngine::Init(int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CDMIEngine::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                           double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_period)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers
   if(ArraySize(m_pDM) != rates_total)
     {
      ArrayResize(m_pDM, rates_total);
      ArrayResize(m_nDM, rates_total);
      ArrayResize(m_TR, rates_total);
      ArrayResize(m_smoothed_pdm, rates_total);
      ArrayResize(m_smoothed_ndm, rates_total);
      ArrayResize(m_smoothed_tr, rates_total);

      ArrayResize(m_high, rates_total);
      ArrayResize(m_low, rates_total);
      ArrayResize(m_close, rates_total);
     }

// 1. Prepare Data (Standard or HA)
   PrepareData(rates_total, start_index, open, high, low, close);

// 2. Calculate Raw DM and TR
   int loop_start_dm = MathMax(1, start_index);
   for(int i = loop_start_dm; i < rates_total; i++)
     {
      double high_diff = m_high[i] - m_high[i-1];
      double low_diff  = m_low[i-1] - m_low[i];

      m_pDM[i] = (high_diff > low_diff && high_diff > 0) ? high_diff : 0;
      m_nDM[i] = (low_diff > high_diff && low_diff > 0) ? low_diff : 0;
      m_TR[i]  = MathMax(m_high[i], m_close[i-1]) - MathMin(m_low[i], m_close[i-1]);
     }

// 3. Calculate Smoothed Values (Wilder's Smoothing)
   int loop_start_smooth = MathMax(m_period, start_index);
   for(int i = loop_start_smooth; i < rates_total; i++)
     {
      if(i == m_period) // Initial Sum
        {
         double sum_pdm=0, sum_ndm=0, sum_tr=0;
         for(int j=1; j<=m_period; j++)
           {
            sum_pdm += m_pDM[j];
            sum_ndm += m_nDM[j];
            sum_tr  += m_TR[j];
           }
         m_smoothed_pdm[i] = sum_pdm;
         m_smoothed_ndm[i] = sum_ndm;
         m_smoothed_tr[i]  = sum_tr;
        }
      else // Wilder's Smoothing
        {
         m_smoothed_pdm[i] = m_smoothed_pdm[i-1] - (m_smoothed_pdm[i-1] / m_period) + m_pDM[i];
         m_smoothed_ndm[i] = m_smoothed_ndm[i-1] - (m_smoothed_ndm[i-1] / m_period) + m_nDM[i];
         m_smoothed_tr[i]  = m_smoothed_tr[i-1]  - (m_smoothed_tr[i-1] / m_period) + m_TR[i];
        }
     }

// 4. Calculate +DI and -DI
   for(int i = loop_start_smooth; i < rates_total; i++)
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
     }
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard)                                          |
//+------------------------------------------------------------------+
void CDMIEngine::PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = high[i];
      m_low[i]  = low[i];
      m_close[i] = close[i];
     }
  }

//+==================================================================+
//|             CLASS 2: CDMIEngine_HA (Heikin Ashi)                 |
//+==================================================================+
class CDMIEngine_HA : public CDMIEngine
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[]; // Only need open buffer for calc, others map to base members

protected:
   virtual void      PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi)                                       |
//+------------------------------------------------------------------+
void CDMIEngine_HA::PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
      ArrayResize(m_ha_open, rates_total);

// Calculate HA and store directly into base class buffers (m_high, m_low, m_close)
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_high, m_low, m_close);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
