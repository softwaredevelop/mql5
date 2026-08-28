//+------------------------------------------------------------------+
//|                                                DMI_Engine.mqh    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Upgraded with robust bounds safety and chronological alignment
#property description "Core engine for Directional Movement Index calculations."

#ifndef DMI_ENGINE_MQH
#define DMI_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CDMIEngine (Base Class)                     |
//+==================================================================+
class CDMIEngine
  {
protected:
   int               m_period;

   //--- Persistent State Buffers
   double            m_pDM[], m_nDM[], m_TR[];
   double            m_smoothed_pdm[], m_smoothed_ndm[], m_smoothed_tr[];

   //--- Internal Price Buffers
   double            m_high[], m_low[], m_close[];

   virtual void      PrepareData(const int rates_total, const int start_index,
                                 const double &open[], const double &high[],
                                 const double &low[], const double &close[]);

public:
                     CDMIEngine(void) : m_period(14) {};
   virtual          ~CDMIEngine(void) {};

   bool              Init(const int period);
   int               GetPeriod(void) const { return m_period; }

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDMIEngine::Init(const int period)
  {
   m_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CDMIEngine::Calculate(const int rates_total, const int prev_calculated,
                           const double &open[], const double &high[],
                           const double &low[], const double &close[],
                           double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_period)
      return;

// Safe allocation of destination arrays
   if(ArraySize(pdi_buffer) != rates_total)
     {
      ArrayResize(pdi_buffer, rates_total);
      ArraySetAsSeries(pdi_buffer, false);
      ArrayInitialize(pdi_buffer, EMPTY_VALUE);
     }
   if(ArraySize(ndi_buffer) != rates_total)
     {
      ArrayResize(ndi_buffer, rates_total);
      ArraySetAsSeries(ndi_buffer, false);
      ArrayInitialize(ndi_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

// Resize Internal State Buffers
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

      ArraySetAsSeries(m_pDM, false);
      ArraySetAsSeries(m_nDM, false);
      ArraySetAsSeries(m_TR, false);
      ArraySetAsSeries(m_smoothed_pdm, false);
      ArraySetAsSeries(m_smoothed_ndm, false);
      ArraySetAsSeries(m_smoothed_tr, false);
      ArraySetAsSeries(m_high, false);
      ArraySetAsSeries(m_low, false);
      ArraySetAsSeries(m_close, false);
     }

// 1. Prepare Price Data
   PrepareData(rates_total, start_index, open, high, low, close);

// 2. Calculate Raw DM and TR
   int loop_start_dm = MathMax(1, start_index);
   for(int i = loop_start_dm; i < rates_total; i++)
     {
      double high_diff = m_high[i] - m_high[i - 1];
      double low_diff  = m_low[i - 1] - m_low[i];

      m_pDM[i] = (high_diff > low_diff && high_diff > 0.0) ? high_diff : 0.0;
      m_nDM[i] = (low_diff > high_diff && low_diff > 0.0) ? low_diff : 0.0;
      m_TR[i]  = MathMax(m_high[i], m_close[i - 1]) - MathMin(m_low[i], m_close[i - 1]);
     }

// 3. Calculate Smoothed Values (Wilder's Smoothing)
   int loop_start_smooth = MathMax(m_period, start_index);
   for(int i = loop_start_smooth; i < rates_total; i++)
     {
      if(i == m_period) // Initial Cumulative Sum
        {
         double sum_pdm = 0.0, sum_ndm = 0.0, sum_tr = 0.0;
         for(int j = 1; j <= m_period; j++)
           {
            sum_pdm += m_pDM[j];
            sum_ndm += m_nDM[j];
            sum_tr  += m_TR[j];
           }
         m_smoothed_pdm[i] = sum_pdm;
         m_smoothed_ndm[i] = sum_ndm;
         m_smoothed_tr[i]  = sum_tr;
        }
      else // Wilder's RMA recursion
        {
         m_smoothed_pdm[i] = m_smoothed_pdm[i - 1] - (m_smoothed_pdm[i - 1] / (double)m_period) + m_pDM[i];
         m_smoothed_ndm[i] = m_smoothed_ndm[i - 1] - (m_smoothed_ndm[i - 1] / (double)m_period) + m_nDM[i];
         m_smoothed_tr[i]  = m_smoothed_tr[i - 1]  - (m_smoothed_tr[i - 1]  / (double)m_period) + m_TR[i];
        }
     }

// 4. Calculate +DI and -DI
   for(int i = loop_start_smooth; i < rates_total; i++)
     {
      if(m_smoothed_tr[i] > 1.0e-9)
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
void CDMIEngine::PrepareData(const int rates_total, const int start_index,
                             const double &open[], const double &high[],
                             const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i]  = high[i];
      m_low[i]   = low[i];
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
   double                 m_ha_open[];

protected:
   virtual void           PrepareData(const int rates_total, const int start_index,
                                      const double &open[], const double &high[],
                                      const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi)                                       |
//+------------------------------------------------------------------+
void CDMIEngine_HA::PrepareData(const int rates_total, const int start_index,
                                const double &open[], const double &high[],
                                const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArraySetAsSeries(m_ha_open, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_high, m_low, m_close);
  }

#endif // DMI_ENGINE_MQH
//+------------------------------------------------------------------+
