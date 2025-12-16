//+------------------------------------------------------------------+
//|                                           Gann_HiLo_Calculator.mqh|
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CGannHiLoCalculator (Base Class)              |
//+==================================================================+
class CGannHiLoCalculator
  {
protected:
   int               m_period;
   ENUM_MA_METHOD    m_ma_method;

   //--- Persistent Buffers for Incremental Calculation
   double            m_src_high[], m_src_low[], m_src_close[];
   double            m_hi_avg[], m_lo_avg[], m_trend[];

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGannHiLoCalculator(void) {};
   virtual          ~CGannHiLoCalculator(void) {};

   bool              Init(int period, ENUM_MA_METHOD ma_method);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], double &hilo_buffer[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator::Init(int period, ENUM_MA_METHOD ma_method)
  {
   m_period    = (period < 1) ? 1 : period;
   m_ma_method = ma_method;
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

//--- 4. Calculate High/Low Averages (Incremental)
   int ma_start_pos = m_period - 1;
   int loop_start = MathMax(ma_start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum_h=0, sum_l=0;
               for(int j=0; j<m_period; j++)
                 {
                  sum_h+=m_src_high[i-j];
                  sum_l+=m_src_low[i-j];
                 }
               m_hi_avg[i]=sum_h/m_period;
               m_lo_avg[i]=sum_l/m_period;
              }
            else
              {
               if(m_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_period+1.0);
                  m_hi_avg[i]=m_src_high[i]*pr+m_hi_avg[i-1]*(1.0-pr);
                  m_lo_avg[i]=m_src_low[i]*pr+m_lo_avg[i-1]*(1.0-pr);
                 }
               else
                 {
                  m_hi_avg[i]=(m_hi_avg[i-1]*(m_period-1)+m_src_high[i])/m_period;
                  m_lo_avg[i]=(m_lo_avg[i-1]*(m_period-1)+m_src_low[i])/m_period;
                 }
              }
            break;
         case MODE_LWMA:
           {
            double wh=0,wl=0,ws=0;
            for(int j=0; j<m_period; j++)
              {
               int w=m_period-j;
               wh+=m_src_high[i-j]*w;
               wl+=m_src_low[i-j]*w;
               ws+=w;
              }
            if(ws>0)
              {
               m_hi_avg[i]=wh/ws;
               m_lo_avg[i]=wl/ws;
              }
           }
         break;
         default: // SMA
           {
            double sh=0,sl=0;
            for(int j=0; j<m_period; j++)
              {
               sh+=m_src_high[i-j];
               sl+=m_src_low[i-j];
              }
            m_hi_avg[i]=sh/m_period;
            m_lo_avg[i]=sl/m_period;
           }
         break;
        }

      //--- 5. Determine Trend (Incremental)
      // We need m_trend[i-1] which is persistent
      if(i < m_period)
         continue;

      if(m_src_close[i] > m_hi_avg[i-1])
         m_trend[i] = 1;
      else
         if(m_src_close[i] < m_lo_avg[i-1])
            m_trend[i] = -1;
         else
            m_trend[i] = m_trend[i-1]; // Keep previous trend

      //--- 6. Output to Buffers
      if(m_trend[i] == 1)
        {
         hilo_buffer[i] = m_lo_avg[i];
         color_buffer[i] = 0;
         // Backfill gap if trend changed
         if(m_trend[i-1] == -1)
            hilo_buffer[i-1] = m_lo_avg[i];
        }
      else
        {
         hilo_buffer[i] = m_hi_avg[i];
         color_buffer[i] = 1;
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
// Optimized copy loop
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
   // Internal HA buffers
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp, rates_total);
      ArrayResize(m_ha_close_temp, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

//--- Copy to source buffers (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
