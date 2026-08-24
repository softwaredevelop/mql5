//+------------------------------------------------------------------+
//|                                      KAMA_Channel_Calculator.mqh |
//|      KAMA Middle Line + ATR Bands (Keltner Volatility Channel)   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Performance-optimized unified composition engine

#ifndef KAMA_CHANNEL_CALCULATOR_MQH
#define KAMA_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\KAMA_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|             CLASS: CKamaChannelCalculator                        |
//+==================================================================+
class CKamaChannelCalculator
  {
private:
   double            m_multiplier;
   int               m_er_period;
   int               m_atr_period;

   //--- Composition Engines
   CKamaCalculator   m_kama_calc;
   CATRCalculator    *m_atr_calc;

   //--- Internal State Buffers
   double            m_atr_buffer[];

public:
                     CKamaChannelCalculator(void);
                    ~CKamaChannelCalculator(void);

   bool              Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL kama_price,
                          const int atr_p, const double multiplier, const ENUM_ATR_SOURCE atr_source);

   void              Calculate(const int rates_total,
                               const int prev_calculated,
                               const double &open[],
                               const double &high[],
                               const double &low[],
                               const double &close[],
                               double &middle_buffer[],
                               double &upper_buffer[],
                               double &lower_buffer[]);

   int               GetRequiredWarmup(void) const { return MathMax(m_er_period, m_atr_period); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaChannelCalculator::CKamaChannelCalculator(void) : m_multiplier(2.0),
   m_er_period(10),
   m_atr_period(14),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_atr_buffer, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CKamaChannelCalculator::~CKamaChannelCalculator(void)
  {
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CKamaChannelCalculator::Init(const int er_p, const int fast_p, const int slow_p, const ENUM_APPLIED_PRICE_HA_ALL kama_price,
                                  const int atr_p, const double multiplier, const ENUM_ATR_SOURCE atr_source)
  {
   m_er_period  = (er_p < 1) ? 1 : er_p;
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_multiplier = (multiplier <= 0.0) ? 2.0 : multiplier;

// 1. Initialize KAMA Engine
   if(!m_kama_calc.Init(m_er_period, fast_p, slow_p, kama_price))
      return false;

// 2. Initialize ATR Engine (Clean memory rebuild)
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(atr_source == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_atr_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Channel Calculation                             |
//+------------------------------------------------------------------+
void CKamaChannelCalculator::Calculate(const int rates_total,
                                       const int prev_calculated,
                                       const double &open[],
                                       const double &high[],
                                       const double &low[],
                                       const double &close[],
                                       double &middle_buffer[],
                                       double &upper_buffer[],
                                       double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

// Resize internal ATR buffer
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total);
      ArraySetAsSeries(m_atr_buffer, false);
     }

// 1. Compute KAMA Middle Line
   m_kama_calc.Calculate(rates_total, prev_calculated, open, high, low, close, middle_buffer);

// 2. Compute ATR Volatility Range
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

// 3. Clean invalid initial range on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
        {
         middle_buffer[i] = EMPTY_VALUE;
         upper_buffer[i]  = EMPTY_VALUE;
         lower_buffer[i]  = EMPTY_VALUE;
        }
     }

   int start_index = (prev_calculated == 0) ? warmup : (prev_calculated - 1);
   if(start_index < warmup)
      start_index = warmup;

// 4. Construct Upper and Lower Keltner Bands
   for(int i = start_index; i < rates_total; i++)
     {
      if(middle_buffer[i] != EMPTY_VALUE && middle_buffer[i] > 0.0 &&
         m_atr_buffer[i] != EMPTY_VALUE && m_atr_buffer[i] > 0.0)
        {
         double channel_width = m_atr_buffer[i] * m_multiplier;
         upper_buffer[i] = middle_buffer[i] + channel_width;
         lower_buffer[i] = middle_buffer[i] - channel_width;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

#endif // KAMA_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
