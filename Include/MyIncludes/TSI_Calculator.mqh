//+------------------------------------------------------------------+
//|                                               TSI_Calculator.mqh |
//|      VERSION 5.00: Unified calculator for TSI and Oscillator.    |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CTSICalculator (Base Class)                 |
//+==================================================================+
class CTSICalculator
  {
protected:
   int               m_slow_p, m_fast_p, m_signal_p;

   //--- Engines for Core Calculation (Double Smoothing)
   CMovingAverageCalculator m_slow_mtm_engine;
   CMovingAverageCalculator m_fast_mtm_engine;
   CMovingAverageCalculator m_slow_abs_engine;
   CMovingAverageCalculator m_fast_abs_engine;

   //--- Engine for Signal Line
   CMovingAverageCalculator m_signal_ma_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_mtm[], m_abs_mtm[]; // Raw Momentum
   double            m_ema1_mtm[], m_ema1_abs[]; // First Smoothing
   double            m_ema2_mtm[], m_ema2_abs[]; // Second Smoothing

   //--- Internal Result Buffers
   double            m_tsi_internal[];
   double            m_signal_internal[];
   double            m_osc_internal[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTSICalculator(void);
   virtual          ~CTSICalculator(void);

   bool              Init(int slow_p, ENUM_MA_TYPE slow_ma, int fast_p, ENUM_MA_TYPE fast_ma, int signal_p, ENUM_MA_TYPE signal_ma);

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_out[], double &signal_out[], double &osc_out[]);

   //--- Wrapper for Oscillator Only
   void              CalculateOscillatorOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
         double &osc_out[]);

   int               GetPeriodSlow() const { return m_slow_p; }
   int               GetPeriodFast() const { return m_fast_p; }
   int               GetPeriodSignal() const { return m_signal_p; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTSICalculator::CTSICalculator(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTSICalculator::~CTSICalculator(void)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTSICalculator::Init(int slow_p, ENUM_MA_TYPE slow_ma, int fast_p, ENUM_MA_TYPE fast_ma, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_slow_p   = (slow_p < 1) ? 1 : slow_p;
   m_fast_p   = (fast_p < 1) ? 1 : fast_p;
   m_signal_p = (signal_p < 1) ? 1 : signal_p;

   if(!m_slow_mtm_engine.Init(m_slow_p, slow_ma))
      return false;
   if(!m_fast_mtm_engine.Init(m_fast_p, fast_ma))
      return false;
   if(!m_slow_abs_engine.Init(m_slow_p, slow_ma))
      return false;
   if(!m_fast_abs_engine.Init(m_fast_p, fast_ma))
      return false;
   if(!m_signal_ma_engine.Init(m_signal_p, signal_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CTSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_out[], double &signal_out[], double &osc_out[])
  {
   if(rates_total <= m_slow_p + m_fast_p + m_signal_p)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_mtm, rates_total);
      ArrayResize(m_abs_mtm, rates_total);
      ArrayResize(m_ema1_mtm, rates_total);
      ArrayResize(m_ema1_abs, rates_total);
      ArrayResize(m_ema2_mtm, rates_total);
      ArrayResize(m_ema2_abs, rates_total);
      ArrayResize(m_tsi_internal, rates_total);
      ArrayResize(m_signal_internal, rates_total);
      ArrayResize(m_osc_internal, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 1. Calculate Momentum (Raw)
   int loop_start = MathMax(1, start_index);
   if(loop_start == 1)
     {
      m_mtm[0] = 0;
      m_abs_mtm[0] = 0;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      m_mtm[i] = diff;
      m_abs_mtm[i] = MathAbs(diff);
     }

// 2. First Smoothing (Slow MA)
   m_slow_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_mtm, m_ema1_mtm, 1);
   m_slow_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_abs_mtm, m_ema1_abs, 1);

// 3. Second Smoothing (Fast MA)
   int offset2 = m_slow_p;
   m_fast_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_mtm, m_ema2_mtm, offset2);
   m_fast_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_abs, m_ema2_abs, offset2);

// 4. Calculate TSI
   int tsi_start = m_slow_p + m_fast_p - 1;
   int loop_start_tsi = MathMax(tsi_start, start_index);

   for(int i = loop_start_tsi; i < rates_total; i++)
     {
      if(m_ema2_abs[i] > 0.0000001)
         m_tsi_internal[i] = 100.0 * (m_ema2_mtm[i] / m_ema2_abs[i]);
      else
         m_tsi_internal[i] = 0.0;
     }

// 5. Calculate Signal Line
   m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_tsi_internal, m_signal_internal, tsi_start);

// 6. Calculate Oscillator & Output
   int osc_start = tsi_start + m_signal_p - 1;
   int loop_start_osc = MathMax(osc_start, start_index);

   for(int i = loop_start_osc; i < rates_total; i++)
     {
      m_osc_internal[i] = m_tsi_internal[i] - m_signal_internal[i];

      if(ArraySize(tsi_out) == rates_total)
         tsi_out[i] = m_tsi_internal[i];
      if(ArraySize(signal_out) == rates_total)
         signal_out[i] = m_signal_internal[i];
      if(ArraySize(osc_out) == rates_total)
         osc_out[i] = m_osc_internal[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate Oscillator Only                                        |
//+------------------------------------------------------------------+
void CTSICalculator::CalculateOscillatorOnly(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_out[])
  {
   double dummy_tsi[], dummy_signal[];
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, dummy_tsi, dummy_signal, osc_out);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CTSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CTSICalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CTSICalculator_HA : public CTSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CTSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
