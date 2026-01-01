//+------------------------------------------------------------------+
//|                                               MFI_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi MFI.     |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CMFICalculator (Base Class)                 |
//+==================================================================+
class CMFICalculator
  {
protected:
   int               m_mfi_period;
   ENUM_APPLIED_VOLUME m_volume_type;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_typical_price[];
   double            m_pos_mf[]; // Positive Money Flow
   double            m_neg_mf[]; // Negative Money Flow
   double            m_mfi_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMFICalculator(void) {};
   virtual          ~CMFICalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int mfi_p, int ma_p, ENUM_MA_TYPE ma_m, ENUM_APPLIED_VOLUME vol_t);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[],
                               double &mfi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMFICalculator::Init(int mfi_p, int ma_p, ENUM_MA_TYPE ma_m, ENUM_APPLIED_VOLUME vol_t)
  {
   m_mfi_period  = (mfi_p < 1) ? 1 : mfi_p;
   m_volume_type = vol_t;

// Initialize Signal Engine
   if(!m_signal_engine.Init(ma_p, ma_m))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMFICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[],
                               double &mfi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_mfi_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_typical_price) != rates_total)
     {
      ArrayResize(m_typical_price, rates_total);
      ArrayResize(m_pos_mf, rates_total);
      ArrayResize(m_neg_mf, rates_total);
      ArrayResize(m_mfi_buffer, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate Money Flow (Incremental)
   int loop_start_mf = MathMax(1, start_index);

   for(int i = loop_start_mf; i < rates_total; i++)
     {
      double raw_mf = m_typical_price[i] * ((m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i]);

      if(m_typical_price[i] > m_typical_price[i-1])
        {
         m_pos_mf[i] = raw_mf;
         m_neg_mf[i] = 0;
        }
      else
         if(m_typical_price[i] < m_typical_price[i-1])
           {
            m_pos_mf[i] = 0;
            m_neg_mf[i] = raw_mf;
           }
         else
           {
            m_pos_mf[i] = 0;
            m_neg_mf[i] = 0;
           }
     }

//--- 5. Calculate MFI (Incremental Sliding Window)
   int loop_start_mfi = MathMax(m_mfi_period, start_index);

// If full recalc, we need to handle the first value specially or just loop
   if(prev_calculated == 0)
     {
      // Initialize first few values
      for(int i=0; i<m_mfi_period; i++)
         m_mfi_buffer[i] = 50.0;
     }

   for(int i = loop_start_mfi; i < rates_total; i++)
     {
      double sum_pos = 0;
      double sum_neg = 0;

      // Sum over the lookback period
      // Optimization: We could use a running sum, but for MFI period (usually 14), a loop is fast enough and safer.
      for(int j = 0; j < m_mfi_period; j++)
        {
         sum_pos += m_pos_mf[i-j];
         sum_neg += m_neg_mf[i-j];
        }

      if(sum_neg > 0)
        {
         double ratio = sum_pos / sum_neg;
         m_mfi_buffer[i] = 100.0 - (100.0 / (1.0 + ratio));
        }
      else
         m_mfi_buffer[i] = 100.0;
     }

//--- 6. Calculate Signal Line (Using Engine)
// MFI is valid from index: m_mfi_period
   int mfi_offset = m_mfi_period;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_mfi_buffer, signal_buffer, mfi_offset);

//--- 7. Copy MFI to Output
   ArrayCopy(mfi_buffer, m_mfi_buffer, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMFICalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
   return true;
  }

//+==================================================================+
//|             CLASS 2: CMFICalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CMFICalculator_HA : public CMFICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMFICalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to typical price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
      m_typical_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
