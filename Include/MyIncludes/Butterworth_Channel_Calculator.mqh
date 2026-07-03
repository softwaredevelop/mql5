//+------------------------------------------------------------------+
//|                                  Butterworth_Channel_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // High-performance John Ehlers' Butterworth Channel calculator engine
#property description "Butterworth Filter Middle Line + ATR Bands (Keltner Concept)."

#ifndef BUTTERWORTH_CHANNEL_CALCULATOR_MQH
#define BUTTERWORTH_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\Butterworth_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CButterworthChannelCalculator (Base)          |
//+==================================================================+
class CButterworthChannelCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition
   CButterworthCalculator  *m_butter_calc;
   CATRCalculator          *m_atr_calc;

   //--- Internal Buffer
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CButterworthChannelCalculator(void);
   virtual          ~CButterworthChannelCalculator(void);

   bool              Init(int period, ENUM_BUTTERWORTH_POLES poles, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CButterworthChannelCalculator::CButterworthChannelCalculator(void)
  {
   m_butter_calc = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CButterworthChannelCalculator::~CButterworthChannelCalculator(void)
  {
   if(CheckPointer(m_butter_calc) != POINTER_INVALID)
      delete m_butter_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CButterworthChannelCalculator::CreateCalculators(void)
  {
   m_butter_calc = new CButterworthCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CButterworthChannelCalculator::Init(int period, ENUM_BUTTERWORTH_POLES poles, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

   CreateCalculators(); // Polymorphically instantiates the correct engine

// Create ATR Calculator
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

// Initialize Butterworth (SOURCE_PRICE is standard for channel middle line)
   if(CheckPointer(m_butter_calc) == POINTER_INVALID || !m_butter_calc.Init(period, poles, SOURCE_PRICE))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CButterworthChannelCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 2)
      return;

   if(CheckPointer(m_butter_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

//--- Resize Internal Buffer and force strict chronological sorting
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total);
      ArraySetAsSeries(m_atr_buffer, false); // Fixed: strict chronological safety on internal buffers
     }

//--- 1. Calculate Middle Line (Butterworth Filter)
   m_butter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int atr_period = m_atr_calc.GetPeriod();
   int butter_period = m_butter_calc.GetPeriod();
   int loop_start = MathMax(MathMax(atr_period, butter_period), start_index);

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
//|           CLASS 2: CButterworthChannelCalculator_HA              |
//+==================================================================+
class CButterworthChannelCalculator_HA : public CButterworthChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
void CButterworthChannelCalculator_HA::CreateCalculators(void)
  {
   m_butter_calc = new CButterworthCalculator_HA();
  }
#endif // BUTTERWORTH_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
