//+------------------------------------------------------------------+
//|                                               TSI_Calculator.mqh |
//|      Engine for William Blau's True Strength Index (TSI)         |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "6.10" // Full VWMA Support across Slow, Fast and Signal smoothing engines

#ifndef TSI_CALCULATOR_MQH
#define TSI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CTSICalculator (Base Class)                 |
//+==================================================================+
class CTSICalculator
  {
protected:
   int                       m_slow_p;
   int                       m_fast_p;
   int                       m_signal_p;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Double Smoothing Engines
   CMovingAverageCalculator  m_slow_mtm_engine;
   CMovingAverageCalculator  m_fast_mtm_engine;
   CMovingAverageCalculator  m_slow_abs_engine;
   CMovingAverageCalculator  m_fast_abs_engine;
   CMovingAverageCalculator  m_signal_ma_engine;

   //--- Composition Engine
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_vol_buf[];
   double                    m_mtm[], m_abs_mtm[];
   double                    m_ema1_mtm[], m_ema1_abs[];
   double                    m_ema2_mtm[], m_ema2_abs[];
   double                    m_tsi_internal[];
   double                    m_signal_internal[];
   double                    m_osc_internal[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

   void                      ExecuteCalculation(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         const bool use_volume,
         double &tsi_out[], double &signal_out[], double &osc_out[]);

public:
                     CTSICalculator(void);
   virtual                  ~CTSICalculator(void) {};

   //--- Enhanced Pro Init (7 Parameters)
   bool                      Init(const int slow_p, const ENUM_MA_TYPE slow_ma,
                                  const int fast_p, const ENUM_MA_TYPE fast_ma,
                                  const int signal_p, const ENUM_MA_TYPE signal_ma,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (6 Parameters)
   bool                      Init(const int slow_p, const ENUM_MA_TYPE slow_ma,
                                  const int fast_p, const ENUM_MA_TYPE fast_ma,
                                  const int signal_p, const ENUM_MA_TYPE signal_ma)
     {
      return Init(slow_p, slow_ma, fast_p, fast_ma, signal_p, signal_ma, PRICE_CLOSE_STD);
     }

   //--- Calculation Without Volume
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &tsi_out[], double &signal_out[], double &osc_out[])
     {
      ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, false, tsi_out, signal_out, osc_out);
     }

   //--- Calculation With Long Volume Array (Supports VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &tsi_out[], double &signal_out[], double &osc_out[]);

   //--- Calculation With Double Volume Array (Supports VWMA in MTF)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const double &volume[],
                                       double &tsi_out[], double &signal_out[], double &osc_out[]);

   //--- Legacy Overload with price_type parameter
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &tsi_out[], double &signal_out[], double &osc_out[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, tsi_out, signal_out, osc_out);
     }

   void                      CalculateOscillatorOnly(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &osc_out[]);

   int                       GetPeriodSlow(void) const   { return m_slow_p; }
   int                       GetPeriodFast(void) const   { return m_fast_p; }
   int                       GetPeriodSignal(void) const { return m_signal_p; }
   int                       GetRequiredWarmup(void) const { return m_slow_p + m_fast_p + m_signal_p; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTSICalculator::CTSICalculator(void) : m_slow_p(25),
   m_fast_p(13),
   m_signal_p(13),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,           false);
   ArraySetAsSeries(m_vol_buf,         false);
   ArraySetAsSeries(m_mtm,             false);
   ArraySetAsSeries(m_abs_mtm,         false);
   ArraySetAsSeries(m_ema1_mtm,        false);
   ArraySetAsSeries(m_ema1_abs,        false);
   ArraySetAsSeries(m_ema2_mtm,        false);
   ArraySetAsSeries(m_ema2_abs,        false);
   ArraySetAsSeries(m_tsi_internal,    false);
   ArraySetAsSeries(m_signal_internal, false);
   ArraySetAsSeries(m_osc_internal,    false);
   ArraySetAsSeries(m_ha_open,         false);
   ArraySetAsSeries(m_ha_high,         false);
   ArraySetAsSeries(m_ha_low,          false);
   ArraySetAsSeries(m_ha_close,        false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CTSICalculator::Init(const int slow_p, const ENUM_MA_TYPE slow_ma,
                          const int fast_p, const ENUM_MA_TYPE fast_ma,
                          const int signal_p, const ENUM_MA_TYPE signal_ma,
                          const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_slow_p       = (slow_p < 1) ? 1 : slow_p;
   m_fast_p       = (fast_p < 1) ? 1 : fast_p;
   m_signal_p     = (signal_p < 1) ? 1 : signal_p;
   m_source_price = price_source;

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
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CTSICalculator::PreparePriceSeries(const int rates_total, const int start_index,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);

         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_HA_OPEN:
               m_price[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price[i] = m_ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_OPEN_STD:
               m_price[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price[i] = close[i];
               break;
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate with Long Volume Overload                              |
//+------------------------------------------------------------------+
void CTSICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const long &volume[],
                               double &tsi_out[], double &signal_out[], double &osc_out[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int j = start_index; j < rates_total; j++)
      m_vol_buf[j] = (volume[j] < 1) ? 1.0 : (double)volume[j];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, true, tsi_out, signal_out, osc_out);
  }

//+------------------------------------------------------------------+
//| Calculate with Double Volume Overload (For MTF)                  |
//+------------------------------------------------------------------+
void CTSICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const double &volume[],
                               double &tsi_out[], double &signal_out[], double &osc_out[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int j = start_index; j < rates_total; j++)
      m_vol_buf[j] = (volume[j] < 1.0) ? 1.0 : volume[j];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, true, tsi_out, signal_out, osc_out);
  }

//+------------------------------------------------------------------+
//| Internal Calculation Engine (Handles Standard & VWMA Smoothing)  |
//+------------------------------------------------------------------+
void CTSICalculator::ExecuteCalculation(const int rates_total, const int prev_calculated,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        const bool use_volume,
                                        double &tsi_out[], double &signal_out[], double &osc_out[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup)
      return;

// Safe allocation of destination arrays
   if(ArraySize(tsi_out) != rates_total)
     {
      ArrayResize(tsi_out, rates_total);
      ArraySetAsSeries(tsi_out, false);
      ArrayInitialize(tsi_out, EMPTY_VALUE);
     }
   if(ArraySize(signal_out) != rates_total)
     {
      ArrayResize(signal_out, rates_total);
      ArraySetAsSeries(signal_out, false);
      ArrayInitialize(signal_out, EMPTY_VALUE);
     }
   if(ArraySize(osc_out) != rates_total)
     {
      ArrayResize(osc_out, rates_total);
      ArraySetAsSeries(osc_out, false);
      ArrayInitialize(osc_out, 0.0);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArraySetAsSeries(m_price,           false);
      ArrayResize(m_mtm,             rates_total);
      ArraySetAsSeries(m_mtm,             false);
      ArrayResize(m_abs_mtm,         rates_total);
      ArraySetAsSeries(m_abs_mtm,         false);
      ArrayResize(m_ema1_mtm,        rates_total);
      ArraySetAsSeries(m_ema1_mtm,        false);
      ArrayResize(m_ema1_abs,        rates_total);
      ArraySetAsSeries(m_ema1_abs,        false);
      ArrayResize(m_ema2_mtm,        rates_total);
      ArraySetAsSeries(m_ema2_mtm,        false);
      ArrayResize(m_ema2_abs,        rates_total);
      ArraySetAsSeries(m_ema2_abs,        false);
      ArrayResize(m_tsi_internal,    rates_total);
      ArraySetAsSeries(m_tsi_internal,    false);
      ArrayResize(m_signal_internal, rates_total);
      ArraySetAsSeries(m_signal_internal, false);
      ArrayResize(m_osc_internal,    rates_total);
      ArraySetAsSeries(m_osc_internal,    false);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Raw Momentum
   int loop_start = MathMax(1, start_index);
   if(prev_calculated == 0)
     {
      m_mtm[0]     = 0.0;
      m_abs_mtm[0] = 0.0;
      loop_start   = 1;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i - 1];
      m_mtm[i]     = diff;
      m_abs_mtm[i] = MathAbs(diff);
     }

// 2. First Smoothing (Slow MA on Momentum) - Supports VWMA
   if(use_volume)
     {
      m_slow_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_mtm, m_vol_buf, m_ema1_mtm, 1);
      m_slow_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_abs_mtm, m_vol_buf, m_ema1_abs, 1);
     }
   else
     {
      m_slow_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_mtm, m_ema1_mtm, 1);
      m_slow_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_abs_mtm, m_ema1_abs, 1);
     }

// 3. Second Smoothing (Fast MA on Smoothed Momentum) - Supports VWMA
   int offset2 = m_slow_p;
   if(use_volume)
     {
      m_fast_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_mtm, m_vol_buf, m_ema2_mtm, offset2);
      m_fast_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_abs, m_vol_buf, m_ema2_abs, offset2);
     }
   else
     {
      m_fast_mtm_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_mtm, m_ema2_mtm, offset2);
      m_fast_abs_engine.CalculateOnArray(rates_total, prev_calculated, m_ema1_abs, m_ema2_abs, offset2);
     }

// 4. Calculate True Strength Index (TSI)
   int tsi_start = m_slow_p + m_fast_p - 1;
   int loop_start_tsi = MathMax(tsi_start, start_index);

   for(int i = loop_start_tsi; i < rates_total; i++)
     {
      if(m_ema2_abs[i] > 1.0e-9)
         m_tsi_internal[i] = (m_ema2_mtm[i] / m_ema2_abs[i]) * 100.0;
      else
         m_tsi_internal[i] = 0.0;
     }

// 5. Calculate Signal Line - Supports VWMA
   if(use_volume)
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_tsi_internal, m_vol_buf, m_signal_internal, tsi_start);
   else
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_tsi_internal, m_signal_internal, tsi_start);

// 6. Calculate Oscillator Difference & Output
   int osc_start = tsi_start + m_signal_p - 1;
   int loop_start_osc = MathMax(osc_start, start_index);

   for(int i = loop_start_osc; i < rates_total; i++)
     {
      m_osc_internal[i] = m_tsi_internal[i] - m_signal_internal[i];

      tsi_out[i]    = m_tsi_internal[i];
      signal_out[i] = m_signal_internal[i];
      osc_out[i]    = m_osc_internal[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate Oscillator Only                                        |
//+------------------------------------------------------------------+
void CTSICalculator::CalculateOscillatorOnly(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &osc_out[])
  {
   double dummy_tsi[], dummy_signal[];
   Calculate(rates_total, prev_calculated, open, high, low, close, dummy_tsi, dummy_signal, osc_out);
  }

//+==================================================================+
//|             CLASS 2: CTSICalculator_HA (Legacy Wrapper)          |
//+==================================================================+
class CTSICalculator_HA : public CTSICalculator
  {
public:
                     CTSICalculator_HA(void)
     {
      m_source_price = PRICE_HA_CLOSE;
     }
  };

#endif // TSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
