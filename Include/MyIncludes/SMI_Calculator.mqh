//+------------------------------------------------------------------+
//|                                               SMI_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi SMI.     |
//|                                        Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00" // Fully modular 5-engine composition supporting selectable MA types & VWMA

#ifndef SMI_CALCULATOR_MQH
#define SMI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CSMICalculator (Base Class)                 |
//+==================================================================+
class CSMICalculator
  {
protected:
   int                        m_len_k, m_len_d, m_len_ema;
   ENUM_MA_TYPE               m_slowing_type;
   ENUM_MA_TYPE               m_signal_type;

   //--- Composition: 5 MA Engines for complete flexible double smoothing
   CMovingAverageCalculator   m_smooth1_rel;
   CMovingAverageCalculator   m_smooth1_ran;
   CMovingAverageCalculator   m_smooth2_rel;
   CMovingAverageCalculator   m_smooth2_ran;
   CMovingAverageCalculator   m_signal_calc;

   //--- Source Data Buffers (Persistent)
   double                     m_src_high[], m_src_low[], m_src_close[];

   //--- Intermediate Calculation Buffers (Persistent state for incremental update)
   double                     m_hl_range[], m_rel_range[];
   double                     m_ema_rel[], m_ema_range[];
   double                     m_ema_ema_rel[], m_ema_ema_range[];

   double                     Highest(int period, int current_pos);
   double                     Lowest(int period, int current_pos);

   virtual bool               PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSMICalculator(void);
   virtual                   ~CSMICalculator(void) {};

   bool                       Init(int len_k, int len_d, ENUM_MA_TYPE slowing_type, int len_ema, ENUM_MA_TYPE signal_type);

   //--- Standard Calculate (Without volume data)
   void                       Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                        double &smi_buffer[], double &signal_buffer[]);

   //--- Overloaded Calculate (With Volume for VWMA support)
   void                       Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                                        const long &volume[],
                                        double &smi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSMICalculator::CSMICalculator(void)
   : m_len_k(10), m_len_d(3), m_len_ema(3),
     m_slowing_type(EMA), m_signal_type(EMA)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSMICalculator::Init(int len_k, int len_d, ENUM_MA_TYPE slowing_type, int len_ema, ENUM_MA_TYPE signal_type)
  {
   m_len_k        = (len_k < 1) ? 1 : len_k;
   m_len_d        = (len_d < 1) ? 1 : len_d;
   m_slowing_type = slowing_type;
   m_len_ema      = (len_ema < 1) ? 1 : len_ema;
   m_signal_type  = signal_type;

// Initialize the 5-engine moving average pipeline
   if(!m_smooth1_rel.Init(m_len_d, m_slowing_type))
      return false;
   if(!m_smooth1_ran.Init(m_len_d, m_slowing_type))
      return false;
   if(!m_smooth2_rel.Init(m_len_d, m_slowing_type))
      return false;
   if(!m_smooth2_ran.Init(m_len_d, m_slowing_type))
      return false;
   if(!m_signal_calc.Init(m_len_ema, m_signal_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CSMICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &smi_buffer[], double &signal_buffer[])
  {
   int required_bars = m_len_k + m_len_d + m_len_d + m_len_ema - 4;
   if(rates_total <= required_bars)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);

      ArrayResize(m_hl_range, rates_total);
      ArrayResize(m_rel_range, rates_total);
      ArrayResize(m_ema_rel, rates_total);
      ArrayResize(m_ema_range, rates_total);
      ArrayResize(m_ema_ema_rel, rates_total);
      ArrayResize(m_ema_ema_range, rates_total);

      ArraySetAsSeries(m_src_high,      false);
      ArraySetAsSeries(m_src_low,       false);
      ArraySetAsSeries(m_src_close,      false);
      ArraySetAsSeries(m_hl_range,       false);
      ArraySetAsSeries(m_rel_range,      false);
      ArraySetAsSeries(m_ema_rel,        false);
      ArraySetAsSeries(m_ema_range,      false);
      ArraySetAsSeries(m_ema_ema_rel,    false);
      ArraySetAsSeries(m_ema_ema_range,  false);
     }

//--- Enforce chronological safety on output arrays
   if(ArraySize(smi_buffer) != rates_total)
     {
      ArrayResize(smi_buffer, rates_total);
      ArraySetAsSeries(smi_buffer, false);
     }
   if(ArraySize(signal_buffer) != rates_total)
     {
      ArrayResize(signal_buffer, rates_total);
      ArraySetAsSeries(signal_buffer, false);
     }

//--- 1. Prepare Source Data (Standard or HA)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 2. Calculate Raw Ranges
   int loop_start = MathMax(m_len_k - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double highest_h = Highest(m_len_k, i);
      double lowest_l  = Lowest(m_len_k, i);
      m_hl_range[i] = highest_h - lowest_l;
      m_rel_range[i] = m_src_close[i] - (highest_h + lowest_l) / 2.0;
     }

//--- 3. Calculate 1st Smoothing Stage (Selectable MA)
   m_smooth1_rel.CalculateOnArray(rates_total, prev_calculated, m_rel_range, m_ema_rel, m_len_k - 1);
   m_smooth1_ran.CalculateOnArray(rates_total, prev_calculated, m_hl_range, m_ema_range, m_len_k - 1);

//--- 4. Calculate 2nd Smoothing Stage (Double Smoothing)
   int ema1_start = m_len_k - 1 + m_smooth1_rel.GetPeriod() - 1;
   m_smooth2_rel.CalculateOnArray(rates_total, prev_calculated, m_ema_rel, m_ema_ema_rel, ema1_start);
   m_smooth2_ran.CalculateOnArray(rates_total, prev_calculated, m_ema_range, m_ema_ema_range, ema1_start);

//--- 5. Calculate Final SMI Value
   int ema2_start = ema1_start + m_smooth2_rel.GetPeriod() - 1;
   int start = (prev_calculated > 0) ? prev_calculated - 1 : ema2_start;
   if(start < ema2_start)
      start = ema2_start;

   for(int i = start; i < rates_total; i++)
     {
      if(m_ema_ema_range[i] != 0.0)
         smi_buffer[i] = 100.0 * (m_ema_ema_rel[i] / (m_ema_ema_range[i] / 2.0));
      else
         smi_buffer[i] = 0.0;
     }

//--- 6. Calculate Signal Line (Selectable MA)
   m_signal_calc.CalculateOnArray(rates_total, prev_calculated, smi_buffer, signal_buffer, ema2_start);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA support)            |
//+------------------------------------------------------------------+
void CSMICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &smi_buffer[], double &signal_buffer[])
  {
   int required_bars = m_len_k + m_len_d + m_len_d + m_len_ema - 4;
   if(rates_total <= required_bars)
      return;

//--- Convert volume locally to support volume-weighted types (VWMA) across the pipeline
   double d_vol[];
   ArrayResize(d_vol, rates_total);
   ArraySetAsSeries(d_vol, false);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_sync; i < rates_total; i++)
      d_vol[i] = (double)volume[i];

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_close, rates_total);

      ArrayResize(m_hl_range, rates_total);
      ArrayResize(m_rel_range, rates_total);
      ArrayResize(m_ema_rel, rates_total);
      ArrayResize(m_ema_range, rates_total);
      ArrayResize(m_ema_ema_rel, rates_total);
      ArrayResize(m_ema_ema_range, rates_total);

      ArraySetAsSeries(m_src_high,      false);
      ArraySetAsSeries(m_src_low,       false);
      ArraySetAsSeries(m_src_close,      false);
      ArraySetAsSeries(m_hl_range,       false);
      ArraySetAsSeries(m_rel_range,      false);
      ArraySetAsSeries(m_ema_rel,        false);
      ArraySetAsSeries(m_ema_range,      false);
      ArraySetAsSeries(m_ema_ema_rel,    false);
      ArraySetAsSeries(m_ema_ema_range,  false);
     }

//--- Enforce chronological safety on output arrays
   if(ArraySize(smi_buffer) != rates_total)
     {
      ArrayResize(smi_buffer, rates_total);
      ArraySetAsSeries(smi_buffer, false);
     }
   if(ArraySize(signal_buffer) != rates_total)
     {
      ArrayResize(signal_buffer, rates_total);
      ArraySetAsSeries(signal_buffer, false);
     }

//--- 1. Prepare Source Data (Standard or HA)
   if(!PrepareSourceData(rates_total, start_sync, open, high, low, close))
      return;

//--- 2. Calculate Raw Ranges
   int loop_start = MathMax(m_len_k - 1, start_sync);

   for(int i = loop_start; i < rates_total; i++)
     {
      double highest_h = Highest(m_len_k, i);
      double lowest_l  = Lowest(m_len_k, i);
      m_hl_range[i] = highest_h - lowest_l;
      m_rel_range[i] = m_src_close[i] - (highest_h + lowest_l) / 2.0;
     }

//--- 3. Calculate 1st Smoothing Stage (Volume-Weighted)
   m_smooth1_rel.CalculateOnArray(rates_total, prev_calculated, m_rel_range, d_vol, m_ema_rel, m_len_k - 1);
   m_smooth1_ran.CalculateOnArray(rates_total, prev_calculated, m_hl_range, d_vol, m_ema_range, m_len_k - 1);

//--- 4. Calculate 2nd Smoothing Stage (Volume-Weighted)
   int ema1_start = m_len_k - 1 + m_smooth1_rel.GetPeriod() - 1;
   m_smooth2_rel.CalculateOnArray(rates_total, prev_calculated, m_ema_rel, d_vol, m_ema_ema_rel, ema1_start);
   m_smooth2_ran.CalculateOnArray(rates_total, prev_calculated, m_ema_range, d_vol, m_ema_ema_range, ema1_start);

//--- 5. Calculate Final SMI Value
   int ema2_start = ema1_start + m_smooth2_rel.GetPeriod() - 1;
   int start = (prev_calculated > 0) ? prev_calculated - 1 : ema2_start;
   if(start < ema2_start)
      start = ema2_start;

   for(int i = start; i < rates_total; i++)
     {
      if(m_ema_ema_range[i] != 0.0)
         smi_buffer[i] = 100.0 * (m_ema_ema_rel[i] / (m_ema_ema_range[i] / 2.0));
      else
         smi_buffer[i] = 0.0;
     }

//--- 6. Calculate Signal Line (Volume-Weighted)
   m_signal_calc.CalculateOnArray(rates_total, prev_calculated, smi_buffer, d_vol, signal_buffer, ema2_start);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Standard - Optimized)                       |
//+------------------------------------------------------------------+
bool CSMICalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = high[i];
      m_src_low[i]   = low[i];
      m_src_close[i] = close[i];
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CSMICalculator::Highest(int period, int current_pos)
  {
   double res = m_src_high[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < m_src_high[index])
         res = m_src_high[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CSMICalculator::Lowest(int period, int current_pos)
  {
   double res = m_src_low[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > m_src_low[index])
         res = m_src_low[index];
     }
   return(res);
  }

//+==================================================================+
//|             CLASS 2: CSMICalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CSMICalculator_HA : public CSMICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high_temp[], m_ha_low_temp[], m_ha_close_temp[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Chronologically Safe)          |
//+------------------------------------------------------------------+
bool CSMICalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,      rates_total);
      ArrayResize(m_ha_high_temp, rates_total);
      ArrayResize(m_ha_low_temp,  rates_total);
      ArrayResize(m_ha_close_temp,rates_total);

      ArraySetAsSeries(m_ha_open,      false);
      ArraySetAsSeries(m_ha_high_temp, false);
      ArraySetAsSeries(m_ha_low_temp,  false);
      ArraySetAsSeries(m_ha_close_temp,false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high_temp, m_ha_low_temp, m_ha_close_temp);

   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i]  = m_ha_high_temp[i];
      m_src_low[i]   = m_ha_low_temp[i];
      m_src_close[i] = m_ha_close_temp[i];
     }
   return true;
  }
#endif // SMI_CALCULATOR_MQH
//+------------------------------------------------------------------+
