//+------------------------------------------------------------------+
//|                                               ADX_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi ADX.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CADXCalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CADXCalculator
  {
protected:
   int               m_adx_period;

   //--- Virtual method for preparing the raw directional movement values.
   //--- CORRECTED: Added 'open' to the signature for the derived class.
   virtual void      PrepareDirectionalMovement(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
         double &pDM[], double &nDM[], double &TR[]);

public:
                     CADXCalculator(void) {};
   virtual          ~CADXCalculator(void) {};

   //--- Public methods
   bool              Init(int period);
   int               GetPeriod(void) const { return m_adx_period; }
   //--- CORRECTED: Added 'open' to the signature.
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[]);
  };

//+------------------------------------------------------------------+
//| CADXCalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CADXCalculator::Init(int period)
  {
   m_adx_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| CADXCalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CADXCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &adx_buffer[], double &pdi_buffer[], double &ndi_buffer[])
  {
   if(rates_total < m_adx_period * 2)
      return;

//--- STEP 1: Calculate raw +DM, -DM, and TR (delegated to virtual method)
   double pDM[], nDM[], TR[];
   PrepareDirectionalMovement(rates_total, open, high, low, close, pDM, nDM, TR);

//--- Intermediate calculation buffers
   double smoothed_pdm[], smoothed_ndm[], smoothed_tr[], dx[];
   ArrayResize(smoothed_pdm, rates_total);
   ArrayResize(smoothed_ndm, rates_total);
   ArrayResize(smoothed_tr, rates_total);
   ArrayResize(dx, rates_total);

//--- STEP 2: Calculate Smoothed PDM, NDM, and TR
   for(int i = m_adx_period; i < rates_total; i++)
     {
      if(i == m_adx_period) // First calculation is a simple sum
        {
         double sum_pdm=0, sum_ndm=0, sum_tr=0;
         for(int j=1; j<=m_adx_period; j++)
           {
            sum_pdm += pDM[j];
            sum_ndm += nDM[j];
            sum_tr  += TR[j];
           }
         smoothed_pdm[i] = sum_pdm;
         smoothed_ndm[i] = sum_ndm;
         smoothed_tr[i]  = sum_tr;
        }
      else // Subsequent calculations use Wilder's smoothing
        {
         smoothed_pdm[i] = smoothed_pdm[i-1] - (smoothed_pdm[i-1] / m_adx_period) + pDM[i];
         smoothed_ndm[i] = smoothed_ndm[i-1] - (smoothed_ndm[i-1] / m_adx_period) + nDM[i];
         smoothed_tr[i]  = smoothed_tr[i-1]  - (smoothed_tr[i-1] / m_adx_period) + TR[i];
        }
     }

//--- STEP 3: Calculate +DI, -DI, and DX
   for(int i = m_adx_period; i < rates_total; i++)
     {
      if(smoothed_tr[i] != 0.0)
        {
         pdi_buffer[i] = (smoothed_pdm[i] / smoothed_tr[i]) * 100.0;
         ndi_buffer[i] = (smoothed_ndm[i] / smoothed_tr[i]) * 100.0;
        }

      double di_sum = pdi_buffer[i] + ndi_buffer[i];
      if(di_sum != 0.0)
         dx[i] = MathAbs(pdi_buffer[i] - ndi_buffer[i]) / di_sum * 100.0;
      else
         dx[i] = 0.0;
     }

//--- STEP 4: Smooth DX to get the final ADX value
   for(int i = m_adx_period * 2 - 1; i < rates_total; i++)
     {
      if(i == m_adx_period * 2 - 1) // First ADX value is a simple average
        {
         double sum_dx = 0;
         for(int j=i-m_adx_period+1; j<=i; j++)
            sum_dx += dx[j];
         adx_buffer[i] = sum_dx / m_adx_period;
        }
      else // Subsequent ADX values are smoothed
        {
         adx_buffer[i] = (adx_buffer[i-1] * (m_adx_period - 1) + dx[i]) / m_adx_period;
        }
     }
  }

//+------------------------------------------------------------------+
//| CADXCalculator: Prepares raw DM and TR from standard prices.     |
//+------------------------------------------------------------------+
void CADXCalculator::PrepareDirectionalMovement(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &pDM[], double &nDM[], double &TR[])
  {
   ArrayResize(pDM, rates_total);
   ArrayResize(nDM, rates_total);
   ArrayResize(TR, rates_total);

   for(int i = 1; i < rates_total; i++)
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
//|                                                                  |
//|             CLASS 2: CADXCalculator_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CADXCalculator_HA : public CADXCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator; // Instance of the HA calculator tool

protected:
   //--- Overridden method to prepare Heikin Ashi based DM and TR
   //--- CORRECTED: Signature now matches the base class.
   virtual void      PrepareDirectionalMovement(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
         double &pDM[], double &nDM[], double &TR[]) override;
  };

//+------------------------------------------------------------------+
//| CADXCalculator_HA: Prepares raw DM and TR from HA prices.        |
//+------------------------------------------------------------------+
void CADXCalculator_HA::PrepareDirectionalMovement(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
      double &pDM[], double &nDM[], double &TR[])
  {
//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate the HA candles first
//--- CORRECTED: Removed invalid GetPointer() call and now passing 'open' correctly.
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, calculate DM and TR using the HA candles
   ArrayResize(pDM, rates_total);
   ArrayResize(nDM, rates_total);
   ArrayResize(TR, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      pDM[i] = ha_high[i] - ha_high[i-1];
      nDM[i] = ha_low[i-1] - ha_low[i];

      if(pDM[i] < 0 || pDM[i] < nDM[i])
         pDM[i] = 0;
      if(nDM[i] < 0 || nDM[i] < pDM[i])
         nDM[i] = 0;

      TR[i] = MathMax(ha_high[i], ha_close[i-1]) - MathMin(ha_low[i], ha_close[i-1]);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
