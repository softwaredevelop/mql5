//+------------------------------------------------------------------+
//|                                     DSS_Bressert_Calculator.mqh |
//|      Engine for Walter Bressert's Double Smoothed Stochastic     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.20" // Clean Candle-Source (Standard/HA) Architecture
#property description "High-performance calculation engine for Walter Bressert's Double Smoothed Stochastic (DSS)."

#ifndef DSS_BRESSERT_CALCULATOR_MQH
#define DSS_BRESSERT_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };
#endif

//+==================================================================+
//|             CLASS: CDSSBressertCalculator                        |
//+==================================================================+
class CDSSBressertCalculator
  {
protected:
   int                       m_stoch_period;
   int                       m_smooth_p1;
   ENUM_MA_TYPE              m_smooth_ma1;
   int                       m_smooth_p2;
   ENUM_MA_TYPE              m_smooth_ma2;
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma;
   ENUM_CANDLE_SOURCE        m_candle_source;
   bool                      m_is_ha;

   //--- Composition Engines: 3 Embedded MA Processors (Zero Heap Overhead!)
   CMovingAverageCalculator  m_smooth1_engine; // Stage 1: FastK1 -> Y
   CMovingAverageCalculator  m_smooth2_engine; // Stage 2: FastK2 -> DSS
   CMovingAverageCalculator  m_signal_engine;  // Trigger Line: DSS -> Signal
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_high[], m_low[];
   double                    m_fast_k1[];
   double                    m_smooth_y[];
   double                    m_fast_k2[];
   double                    m_dss[];
   double                    m_signal[];
   double                    m_vol_double[];
   double                    m_ha_open[];

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CDSSBressertCalculator(void);
   virtual                  ~CDSSBressertCalculator(void) {};

   //--- Streamlined Universal Init (Candle Source Standard/HA)
   bool                      Init(const int stoch_p,
                                  const int smooth_p1, const ENUM_MA_TYPE smooth_ma1,
                                  const int smooth_p2, const ENUM_MA_TYPE smooth_ma2,
                                  const int signal_p,  const ENUM_MA_TYPE signal_ma,
                                  const ENUM_CANDLE_SOURCE candle_source = CANDLE_STANDARD);

   //--- Standard Calculate (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &dss_buffer[], double &signal_buffer[]);

   //--- Overloaded Calculate (With Volume for VWMA support)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &dss_buffer[], double &signal_buffer[]);

   int                       GetWarmupBars(void) const
     {
      return (m_stoch_period * 2) + m_smooth_p1 + m_smooth_p2 + m_signal_period;
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDSSBressertCalculator::CDSSBressertCalculator(void) :
   m_stoch_period(10),
   m_smooth_p1(3),
   m_smooth_ma1(EMA),
   m_smooth_p2(3),
   m_smooth_ma2(EMA),
   m_signal_period(3),
   m_signal_ma(EMA),
   m_candle_source(CANDLE_STANDARD),
   m_is_ha(false)
  {
   ArraySetAsSeries(m_price,      false);
   ArraySetAsSeries(m_high,       false);
   ArraySetAsSeries(m_low,        false);
   ArraySetAsSeries(m_fast_k1,    false);
   ArraySetAsSeries(m_smooth_y,   false);
   ArraySetAsSeries(m_fast_k2,    false);
   ArraySetAsSeries(m_dss,        false);
   ArraySetAsSeries(m_signal,     false);
   ArraySetAsSeries(m_vol_double, false);
   ArraySetAsSeries(m_ha_open,    false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CDSSBressertCalculator::Init(const int stoch_p,
                                  const int smooth_p1, const ENUM_MA_TYPE smooth_ma1,
                                  const int smooth_p2, const ENUM_MA_TYPE smooth_ma2,
                                  const int signal_p,  const ENUM_MA_TYPE signal_ma,
                                  const ENUM_CANDLE_SOURCE candle_source)
  {
   m_stoch_period  = (stoch_p < 1) ? 1 : stoch_p;
   m_smooth_p1     = (smooth_p1 < 1) ? 1 : smooth_p1;
   m_smooth_ma1    = smooth_ma1;
   m_smooth_p2     = (smooth_p2 < 1) ? 1 : smooth_p2;
   m_smooth_ma2    = smooth_ma2;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma     = signal_ma;
   m_candle_source = candle_source;
   m_is_ha         = (m_candle_source == CANDLE_HEIKIN_ASHI);

   if(!m_smooth1_engine.Init(m_smooth_p1, m_smooth_ma1))
      return false;
   if(!m_smooth2_engine.Init(m_smooth_p2, m_smooth_ma2))
      return false;
   if(!m_signal_engine.Init(m_signal_period, m_signal_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Direct In-Place Heikin Ashi Mapping)       |
//+------------------------------------------------------------------+
bool CDSSBressertCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
      ArrayResize(m_high,  rates_total);
      ArraySetAsSeries(m_high,  false);
      ArrayResize(m_low,   rates_total);
      ArraySetAsSeries(m_low,   false);
     }

   if(m_is_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open, rates_total);
         ArraySetAsSeries(m_ha_open, false);
        }

      // In-place HA calculation: writes directly into m_high, m_low, m_price (close)
      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_high, m_low, m_price);
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         m_high[i]  = high[i];
         m_low[i]   = low[i];
         m_price[i] = close[i];
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation (Standard - No Volume)              |
//+------------------------------------------------------------------+
void CDSSBressertCalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &dss_buffer[], double &signal_buffer[])
  {
   int warmup = GetWarmupBars();
   if(rates_total <= warmup)
      return;

// Safe allocation of internal state buffers
   if(ArraySize(m_fast_k1) != rates_total)
     {
      ArrayResize(m_fast_k1,  rates_total);
      ArraySetAsSeries(m_fast_k1,  false);
      ArrayResize(m_smooth_y, rates_total);
      ArraySetAsSeries(m_smooth_y, false);
      ArrayResize(m_fast_k2,  rates_total);
      ArraySetAsSeries(m_fast_k2,  false);
      ArrayResize(m_dss,      rates_total);
      ArraySetAsSeries(m_dss,      false);
      ArrayResize(m_signal,   rates_total);
      ArraySetAsSeries(m_signal,   false);
     }

// Safe allocation of output destination buffers
   if(ArraySize(dss_buffer) != rates_total)
     {
      ArrayResize(dss_buffer, rates_total);
      ArraySetAsSeries(dss_buffer, false);
      ArrayInitialize(dss_buffer, EMPTY_VALUE);
     }
   if(ArraySize(signal_buffer) != rates_total)
     {
      ArrayResize(signal_buffer, rates_total);
      ArraySetAsSeries(signal_buffer, false);
      ArrayInitialize(signal_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- STEP 1: First Stochastic (FastK1 on Price)
   int loop_start1 = MathMax(m_stoch_period - 1, start_index);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start1; i++)
         m_fast_k1[i] = 50.0;
     }

   for(int i = loop_start1; i < rates_total; i++)
     {
      double hh = m_high[i];
      double ll = m_low[i];

      for(int j = 1; j < m_stoch_period; j++)
        {
         double h_val = m_high[i - j];
         double l_val = m_low[i - j];
         if(h_val > hh)
            hh = h_val;
         if(l_val < ll)
            ll = l_val;
        }

      double range = hh - ll;
      if(range > 1.0e-9)
         m_fast_k1[i] = ((m_price[i] - ll) / range) * 100.0;
      else
         m_fast_k1[i] = (i > 0) ? m_fast_k1[i - 1] : 50.0;
     }

//--- STEP 2: Stage 1 Smoothing (FastK1 -> Y)
   int offset1 = m_stoch_period - 1;
   m_smooth1_engine.CalculateOnArray(rates_total, prev_calculated, m_fast_k1, m_smooth_y, offset1);

//--- STEP 3: Second Stochastic (FastK2 on Y)
   int step2_start = offset1 + m_smooth_p1 - 1 + m_stoch_period - 1;
   int loop_start2 = MathMax(step2_start, start_index);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start2; i++)
         m_fast_k2[i] = 50.0;
     }

   for(int i = loop_start2; i < rates_total; i++)
     {
      double max_y = m_smooth_y[i];
      double min_y = m_smooth_y[i];

      for(int j = 1; j < m_stoch_period; j++)
        {
         double y_val = m_smooth_y[i - j];
         if(y_val > max_y)
            max_y = y_val;
         if(y_val < min_y)
            min_y = y_val;
        }

      double range_y = max_y - min_y;
      if(range_y > 1.0e-9)
         m_fast_k2[i] = ((m_smooth_y[i] - min_y) / range_y) * 100.0;
      else
         m_fast_k2[i] = (i > 0) ? m_fast_k2[i - 1] : 50.0;
     }

//--- STEP 4: Stage 2 Smoothing (FastK2 -> DSS Line)
   int offset2 = step2_start;
   m_smooth2_engine.CalculateOnArray(rates_total, prev_calculated, m_fast_k2, m_dss, offset2);

// Numerical bounds clamp
   for(int i = loop_start2; i < rates_total; i++)
     {
      if(m_dss[i] < 0.0)
         m_dss[i] = 0.0;
      else
         if(m_dss[i] > 100.0)
            m_dss[i] = 100.0;
     }

//--- STEP 5: Signal Line Smoothing (DSS -> Signal)
   int sig_offset = offset2 + m_smooth_p2 - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_dss, m_signal, sig_offset);

// Output mapping
   for(int i = MathMax(sig_offset, start_index); i < rates_total; i++)
     {
      dss_buffer[i]    = m_dss[i];
      signal_buffer[i] = m_signal[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Persistent Volume for VWMA)         |
//+------------------------------------------------------------------+
void CDSSBressertCalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &dss_buffer[], double &signal_buffer[])
  {
   int warmup = GetWarmupBars();
   if(rates_total <= warmup)
      return;

// Safe allocation of persistent volume buffer
   if(ArraySize(m_vol_double) != rates_total)
     {
      ArrayResize(m_vol_double, rates_total);
      ArraySetAsSeries(m_vol_double, false);
     }

   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_sync; i < rates_total; i++)
      m_vol_double[i] = (double)volume[i];

// Safe allocation of internal state buffers
   if(ArraySize(m_fast_k1) != rates_total)
     {
      ArrayResize(m_fast_k1,  rates_total);
      ArraySetAsSeries(m_fast_k1,  false);
      ArrayResize(m_smooth_y, rates_total);
      ArraySetAsSeries(m_smooth_y, false);
      ArrayResize(m_fast_k2,  rates_total);
      ArraySetAsSeries(m_fast_k2,  false);
      ArrayResize(m_dss,      rates_total);
      ArraySetAsSeries(m_dss,      false);
      ArrayResize(m_signal,   rates_total);
      ArraySetAsSeries(m_signal,   false);
     }

   if(ArraySize(dss_buffer) != rates_total)
     {
      ArrayResize(dss_buffer, rates_total);
      ArraySetAsSeries(dss_buffer, false);
      ArrayInitialize(dss_buffer, EMPTY_VALUE);
     }
   if(ArraySize(signal_buffer) != rates_total)
     {
      ArrayResize(signal_buffer, rates_total);
      ArraySetAsSeries(signal_buffer, false);
      ArrayInitialize(signal_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. First Stochastic (FastK1)
   int loop_start1 = MathMax(m_stoch_period - 1, start_index);
   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start1; i++)
        {
         m_fast_k1[i]  = 50.0;
         m_smooth_y[i] = 50.0;
        }
     }

   for(int i = loop_start1; i < rates_total; i++)
     {
      double hh = m_high[i];
      double ll = m_low[i];

      for(int j = 1; j < m_stoch_period; j++)
        {
         double h_val = m_high[i - j];
         double l_val = m_low[i - j];
         if(h_val > hh)
            hh = h_val;
         if(l_val < ll)
            ll = l_val;
        }

      double range = hh - ll;
      if(range > 1.0e-9)
         m_fast_k1[i] = ((m_price[i] - ll) / range) * 100.0;
      else
         m_fast_k1[i] = (i > 0) ? m_fast_k1[i - 1] : 50.0;
     }

// 2. Stage 1 Smoothing (With Persistent Volume)
   int offset1 = m_stoch_period - 1;
   m_smooth1_engine.CalculateOnArray(rates_total, prev_calculated, m_fast_k1, m_vol_double, m_smooth_y, offset1);

// 3. Second Stochastic (FastK2 on Y)
   int step2_start = offset1 + m_smooth_p1 - 1 + m_stoch_period - 1;
   int loop_start2 = MathMax(step2_start, start_index);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start2; i++)
        {
         m_fast_k2[i] = 50.0;
         m_dss[i]     = 50.0;
        }
     }

   for(int i = loop_start2; i < rates_total; i++)
     {
      double max_y = m_smooth_y[i];
      double min_y = m_smooth_y[i];

      for(int j = 1; j < m_stoch_period; j++)
        {
         double y_val = m_smooth_y[i - j];
         if(y_val > max_y)
            max_y = y_val;
         if(y_val < min_y)
            min_y = y_val;
        }

      double range_y = max_y - min_y;
      if(range_y > 1.0e-9)
         m_fast_k2[i] = ((m_smooth_y[i] - min_y) / range_y) * 100.0;
      else
         m_fast_k2[i] = (i > 0) ? m_fast_k2[i - 1] : 50.0;
     }

// 4. Stage 2 Smoothing (With Persistent Volume)
   int offset2 = step2_start;
   m_smooth2_engine.CalculateOnArray(rates_total, prev_calculated, m_fast_k2, m_vol_double, m_dss, offset2);

// Numerical bounds clamp
   for(int i = loop_start2; i < rates_total; i++)
     {
      if(m_dss[i] < 0.0)
         m_dss[i] = 0.0;
      else
         if(m_dss[i] > 100.0)
            m_dss[i] = 100.0;
     }

// 5. Signal Line Smoothing (With Persistent Volume)
   int sig_offset = offset2 + m_smooth_p2 - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_dss, m_vol_double, m_signal, sig_offset);

// Output mapping
   for(int i = MathMax(sig_offset, start_index); i < rates_total; i++)
     {
      dss_buffer[i]    = m_dss[i];
      signal_buffer[i] = m_signal[i];
     }
  }

#endif // DSS_BRESSERT_CALCULATOR_MQH
//+------------------------------------------------------------------+
