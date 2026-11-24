//+------------------------------------------------------------------+
//|                                    Ehlers_Channel_Calculator.mqh |
//|      DSP Engine for John Ehlers' ATR Channel (Keltner Concept)   |
//|      VERSION 2.00: 2026 Enterprise Edition with Fixed HA Centerline|
//|                    Routing & Capacity Memory Reservations        |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef EHLERS_CHANNEL_CALCULATOR_MQH
#define EHLERS_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CEhlersChannelCalculator (Base)               |
//+==================================================================+
class CEhlersChannelCalculator
  {
protected:
   int                       m_period;
   ENUM_SMOOTHER_TYPE        m_smoother_type;
   int                       m_atr_period;
   double                    m_multiplier;
   ENUM_ATR_SOURCE           m_atr_source;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Composition Engines
   CEhlersSmootherCalculator *m_smoother_calc;
   CATRCalculator            *m_atr_calc;

   //--- Internal Persistent Buffer
   double                    m_atr_buffer[];

   virtual void              CreateCalculators(void);

public:
                     CEhlersChannelCalculator(void);
   virtual                  ~CEhlersChannelCalculator(void);

   //--- Modern Unified Initialization (6 Parameters - Explicit Price Source)
   bool                      Init(const int period, const ENUM_SMOOTHER_TYPE type,
                                  const int atr_p, const double mult, const ENUM_ATR_SOURCE atr_src,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- 100% Backward Compatible Legacy Initialization (5 Parameters)
   bool                      Init(const int period, const ENUM_SMOOTHER_TYPE type,
                                  const int atr_p, const double mult, const ENUM_ATR_SOURCE atr_src)
     {
      return Init(period, type, atr_p, mult, atr_src, m_source_price);
     }

   //--- Modern Unified Calculation (Uses configured m_source_price)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   //--- Backward Compatible Overload (With explicit price_type parameter)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, middle_buffer, upper_buffer, lower_buffer);
     }

   int                       GetPeriod(void)       const { return m_period; }
   int                       GetATRPeriod(void)    const { return m_atr_period; }
   double                    GetMultiplier(void)   const { return m_multiplier; }
   int                       GetWarmupBars(void)   const { return MathMax(m_period, m_atr_period); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersChannelCalculator::CEhlersChannelCalculator(void) : m_period(20),
   m_smoother_type(SUPERSMOOTHER),
   m_atr_period(14),
   m_multiplier(2.0),
   m_atr_source(ATR_SOURCE_STANDARD),
   m_source_price(PRICE_CLOSE_STD),
   m_smoother_calc(NULL),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_atr_buffer, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEhlersChannelCalculator::~CEhlersChannelCalculator(void)
  {
   if(CheckPointer(m_smoother_calc) != POINTER_INVALID && m_smoother_calc != NULL)
     {
      delete m_smoother_calc;
      m_smoother_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID && m_atr_calc != NULL)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CEhlersChannelCalculator::CreateCalculators(void)
  {
   if(CheckPointer(m_smoother_calc) != POINTER_INVALID && m_smoother_calc != NULL)
     {
      delete m_smoother_calc;
      m_smoother_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID && m_atr_calc != NULL)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   m_smoother_calc = new CEhlersSmootherCalculator();

   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();
  }

//+------------------------------------------------------------------+
//| Modern Unified Initialization                                    |
//+------------------------------------------------------------------+
bool CEhlersChannelCalculator::Init(const int period, const ENUM_SMOOTHER_TYPE type,
                                    const int atr_p, const double mult, const ENUM_ATR_SOURCE atr_src,
                                    const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period        = MathMax(2, period);
   m_smoother_type = type;
   m_atr_period    = MathMax(1, atr_p);
   m_multiplier    = (mult <= 0.0) ? 2.0 : mult;
   m_atr_source    = atr_src;
   m_source_price  = price_source;

   CreateCalculators();

// Directly inject the exact price_source so HA mode never falls back to Standard prices!
   if(CheckPointer(m_smoother_calc) == POINTER_INVALID ||
      !m_smoother_calc.Init(m_period, m_smoother_type, SOURCE_PRICE, m_source_price))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID ||
      !m_atr_calc.Init(m_atr_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation                                     |
//+------------------------------------------------------------------+
void CEhlersChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 4 || CheckPointer(m_smoother_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

// Resize Internal ATR Buffer with capacity reservation
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total, 2048);
      ArraySetAsSeries(m_atr_buffer, false);
     }

// 1. Calculate Middle Line (Ehlers SuperSmoother or UltimateSmoother)
   m_smoother_calc.Calculate(rates_total, prev_calculated, open, high, low, close, middle_buffer);

// 2. Calculate ATR (Standard or Synthetic Heikin Ashi)
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   int warmup      = MathMax(m_atr_period, m_period);
   int loop_start  = MathMax(warmup, start_index);

// Clear pre-warmup zones cleanly on fresh start
   if(prev_calculated == 0)
     {
      int clear_limit = MathMin(loop_start, rates_total);
      for(int i = 0; i < clear_limit; i++)
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }

// 3. Calculate ATR Volatility Channel Envelopes
   for(int i = loop_start; i < rates_total; i++)
     {
      double mid = middle_buffer[i];
      double atr = m_atr_buffer[i];

      if(mid != 0.0 && mid != EMPTY_VALUE && atr != 0.0 && atr != EMPTY_VALUE)
        {
         double offset = atr * m_multiplier;
         upper_buffer[i] = mid + offset;
         lower_buffer[i] = mid - offset;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+==================================================================+
//|           CLASS 2: CEhlersChannelCalculator_HA (Legacy Wrapper)  |
//+==================================================================+
class CEhlersChannelCalculator_HA : public CEhlersChannelCalculator
  {
public:
                     CEhlersChannelCalculator_HA(void)
     {
      m_source_price = PRICE_HA_CLOSE;
     }
  };

#endif // EHLERS_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
