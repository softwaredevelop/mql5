//+------------------------------------------------------------------+
//|                                                AD_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi A/D.     |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS 1: CADCalculator (Base Class)                  |
//+==================================================================+
class CADCalculator
  {
protected:
   //--- Persistent Buffers for Incremental Calculation
   double            m_high[];
   double            m_low[];
   double            m_close[];

   //--- Updated: Accepts start_index
   virtual bool      PrepareCandleData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CADCalculator(void) {};
   virtual          ~CADCalculator(void) {};

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &ad_buffer[]);
  };

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CADCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                              const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &ad_buffer[])
  {
   if(rates_total < 1)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_high) != rates_total)
     {
      ArrayResize(m_high, rates_total);
      ArrayResize(m_low, rates_total);
      ArrayResize(m_close, rates_total);
     }

//--- 3. Prepare Candle Data (Optimized)
   if(!PrepareCandleData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate A/D (Incremental Loop)
   for(int i = start_index; i < rates_total; i++)
     {
      double mfm = 0; // Money Flow Multiplier
      double range = m_high[i] - m_low[i];

      if(range > 0)
        {
         mfm = ((m_close[i] - m_low[i]) - (m_high[i] - m_close[i])) / range;
        }

      long current_volume = (volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
      double mfv = mfm * current_volume; // Money Flow Volume

      if(i > 0)
         ad_buffer[i] = ad_buffer[i-1] + mfv;
      else
         ad_buffer[i] = mfv; // First value
     }
  }

//+------------------------------------------------------------------+
//| Prepare Candle Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CADCalculator::PrepareCandleData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = high[i];
      m_low[i]  = low[i];
      m_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CADCalculator_HA (Heikin Ashi)              |
//+==================================================================+
class CADCalculator_HA : public CADCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[]; // Temp buffer for HA Open

protected:
   virtual bool      PrepareCandleData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Candle Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CADCalculator_HA::PrepareCandleData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
      ArrayResize(m_ha_open, rates_total);

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_high, m_low, m_close);

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
