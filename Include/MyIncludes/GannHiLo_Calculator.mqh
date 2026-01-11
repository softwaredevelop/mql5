//+------------------------------------------------------------------+
//|                                           Gann_HiLo_Calculator.mqh|
//|      VERSION 3.00: Refactored to use MovingAverage_Engine.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS 1: CGannHiLoCalculator (Base Class)              |
//+==================================================================+
class CGannHiLoCalculator
  {
protected:
   int               m_period;

   //--- Engines for High and Low MA
   CMovingAverageCalculator m_ma_high_engine;
   CMovingAverageCalculator m_ma_low_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_hi_avg[], m_lo_avg[], m_trend[];

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGannHiLoCalculator(void) {};
   virtual          ~CGannHiLoCalculator(void) {};

   //--- Init now takes ENUM_MA_TYPE instead of ENUM_MA_METHOD
   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &hilo_buffer[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = (period < 1) ? 1 : period;

// Initialize MA Engines
   if(!m_ma_high_engine.Init(m_period, ma_type))
      return false;
   if(!m_ma_low_engine.Init(m_period, ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CGannHiLoCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &hilo_buffer[], double &color_buffer[])
  {
   if(rates_total <= m_period)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);
      ArrayResize(m_hi_avg, rates_total);
      ArrayResize(m_lo_avg, rates_total);
      ArrayResize(m_trend, rates_total);
     }

//--- 3. Prepare Source Data (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate High/Low Averages (Using Engines)
// Note: Engines handle their own incremental logic internally
   m_ma_high_engine.CalculateOnArray(rates_total, prev_calculated, m_src_high, m_hi_avg, 0);
   m_ma_low_engine.CalculateOnArray(rates_total, prev_calculated, m_src_low, m_lo_avg, 0);

//--- 5. Determine Trend & Output (Incremental Loop)
// MA is valid from index: m_period - 1 (for SMA/LWMA) or 0 (for EMA)
// But Gann logic needs previous bar's MA, so we start at m_period
   int loop_start = MathMax(m_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Determine Trend
      if(m_src_close[i] > m_hi_avg[i-1])
         m_trend[i] = 1;
      else
         if(m_src_close[i] < m_lo_avg[i-1])
            m_trend[i] = -1;
         else
            m_trend[i] = m_trend[i-1]; // Keep previous trend

      // Output to Buffers
      if(m_trend[i] == 1)
        {
         hilo_buffer[i] = m_lo_avg[i];
         color_buffer[i] = 0; // Bullish Color

         // Backfill gap if trend changed from Bearish to Bullish
         if(m_trend[i-1] == -1)
            hilo_buffer[i-1] = m_lo_avg[i];
        }
      else
        {
         hilo_buffer[i] = m_hi_avg[i];
         color_buffer[i] = 1; // Bearish Color

         // Backfill gap if trend changed from Bullish to Bearish
         if(m_trend[i-1] == 1)
            hilo_buffer[i-1] = m_hi_avg[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i] = high[i];
      m_src_low[i]  = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CGannHiLoCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CGannHiLoCalculator_HA : public CGannHiLoCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
