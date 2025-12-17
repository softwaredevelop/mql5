//+------------------------------------------------------------------+
//|                                               TSI_Calculator.mqh |
//|      VERSION 2.10: Fixed initialization bug (zero fill).         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CTSICalculator (Base Class)                 |
//+==================================================================+
class CTSICalculator
  {
protected:
   int               m_slow_p, m_fast_p, m_signal_p;
   ENUM_MA_METHOD    m_signal_ma_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_ema1_mtm[], m_ema1_abs[];
   double            m_ema2_mtm[], m_ema2_abs[];

   //--- Engine for Signal Line
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTSICalculator(void);
   virtual          ~CTSICalculator(void);

   bool              Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[]);

   int               GetPeriodSlow() const { return m_slow_p; }
   int               GetPeriodFast() const { return m_fast_p; }
   int               GetPeriodSignal() const { return m_signal_p; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTSICalculator::CTSICalculator(void)
  {
   m_signal_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTSICalculator::~CTSICalculator(void)
  {
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTSICalculator::Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma)
  {
   m_slow_p         = (slow_p < 1) ? 1 : slow_p;
   m_fast_p         = (fast_p < 1) ? 1 : fast_p;
   m_signal_p       = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;

   if(!m_signal_ma_engine.Init(m_signal_p, (ENUM_MA_TYPE)m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CTSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[])
  {
   if(rates_total <= m_slow_p + m_fast_p + m_signal_p)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ema1_mtm, rates_total);
      ArrayResize(m_ema1_abs, rates_total);
      ArrayResize(m_ema2_mtm, rates_total);
      ArrayResize(m_ema2_abs, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate First Smoothing (Slow EMA)
   double pr_slow = 2.0 / (m_slow_p + 1.0);
   int loop_start_1 = MathMax(1, start_index); // Momentum needs i-1

// Initialization for first bar
   if(loop_start_1 == 1)
     {
      m_ema1_mtm[0] = 0;
      m_ema1_abs[0] = 0;
     }

   for(int i = loop_start_1; i < rates_total; i++)
     {
      double momentum = m_price[i] - m_price[i-1];
      double abs_momentum = MathAbs(momentum);

      m_ema1_mtm[i] = momentum * pr_slow + m_ema1_mtm[i-1] * (1.0 - pr_slow);
      m_ema1_abs[i] = abs_momentum * pr_slow + m_ema1_abs[i-1] * (1.0 - pr_slow);
     }

//--- 5. Calculate Second Smoothing (Fast EMA)
   double pr_fast = 2.0 / (m_fast_p + 1.0);

   if(loop_start_1 == 1)
     {
      m_ema2_mtm[0] = 0;
      m_ema2_abs[0] = 0;
     }

   for(int i = loop_start_1; i < rates_total; i++)
     {
      m_ema2_mtm[i] = m_ema1_mtm[i] * pr_fast + m_ema2_mtm[i-1] * (1.0 - pr_fast);
      m_ema2_abs[i] = m_ema1_abs[i] * pr_fast + m_ema2_abs[i-1] * (1.0 - pr_fast);
     }

//--- 6. Calculate TSI
   int tsi_start = m_slow_p + m_fast_p - 2; // Warmup period
   int loop_start_tsi = MathMax(tsi_start, start_index);

// FIX: Initialize buffer with 0.0 on full recalc to avoid garbage in Signal Line input
   if(prev_calculated == 0)
      ArrayInitialize(tsi_buffer, 0.0);

   for(int i = loop_start_tsi; i < rates_total; i++)
     {
      if(m_ema2_abs[i] > 0)
         tsi_buffer[i] = 100 * (m_ema2_mtm[i] / m_ema2_abs[i]);
      else
         tsi_buffer[i] = 0;
     }

//--- 7. Calculate Signal Line (Using Engine)
// We pass tsi_buffer as 'close' price.
   m_signal_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                tsi_buffer, tsi_buffer, tsi_buffer, tsi_buffer,
                                signal_buffer);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CTSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
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
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
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
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CTSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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

//--- Copy to m_price (Optimized loop)
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
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
