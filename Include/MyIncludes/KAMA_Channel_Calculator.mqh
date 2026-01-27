//+------------------------------------------------------------------+
//|                                      KAMA_Channel_Calculator.mqh |
//|      KAMA Middle Line + ATR Bands (Keltner Concept).             |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\KAMA_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CKamaChannelCalculator (Base)                 |
//+==================================================================+
class CKamaChannelCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition
   CKamaCalculator   *m_kama_calc;
   CATRCalculator    *m_atr_calc;

   //--- Internal Buffer
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CKamaChannelCalculator(void);
   virtual          ~CKamaChannelCalculator(void);

   bool              Init(int er_p, int fast_ema_p, int slow_ema_p, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKamaChannelCalculator::CKamaChannelCalculator(void)
  {
   m_kama_calc = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CKamaChannelCalculator::~CKamaChannelCalculator(void)
  {
   if(CheckPointer(m_kama_calc) != POINTER_INVALID)
      delete m_kama_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CKamaChannelCalculator::CreateCalculators(void)
  {
   m_kama_calc = new CKamaCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CKamaChannelCalculator::Init(int er_p, int fast_ema_p, int slow_ema_p, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

   CreateCalculators(); // Creates KAMA Calculator

// Create ATR Calculator
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_kama_calc) == POINTER_INVALID || !m_kama_calc.Init(er_p, fast_ema_p, slow_ema_p))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CKamaChannelCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 2)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_atr_buffer) != rates_total)
      ArrayResize(m_atr_buffer, rates_total);

//--- 1. Calculate Middle Line (KAMA)
   m_kama_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int atr_period = m_atr_calc.GetPeriod();
   int kama_period = m_kama_calc.GetPeriod(); // ER Period
   int loop_start = MathMax(MathMax(atr_period, kama_period), start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(middle_buffer[i] != 0.0 && middle_buffer[i] != EMPTY_VALUE &&
         m_atr_buffer[i] != 0.0 && m_atr_buffer[i] != EMPTY_VALUE)
        {
         upper_buffer[i] = middle_buffer[i] + (m_atr_buffer[i] * m_multiplier);
         lower_buffer[i] = middle_buffer[i] - (m_atr_buffer[i] * m_multiplier);
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+==================================================================+
//|           CLASS 2: CKamaChannelCalculator_HA                     |
//+==================================================================+
class CKamaChannelCalculator_HA : public CKamaChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CKamaChannelCalculator_HA::CreateCalculators(void)
  {
   m_kama_calc = new CKamaCalculator_HA();
  }
//+------------------------------------------------------------------+
