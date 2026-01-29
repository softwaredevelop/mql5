//+------------------------------------------------------------------+
//|                                    Ehlers_Channel_Calculator.mqh |
//|      Ehlers Smoother Middle Line + ATR Bands (Keltner Concept).  |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CEhlersChannelCalculator (Base)               |
//+==================================================================+
class CEhlersChannelCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition
   CEhlersSmootherCalculator *m_smoother_calc;
   CATRCalculator            *m_atr_calc;

   //--- Internal Buffer
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CEhlersChannelCalculator(void);
   virtual          ~CEhlersChannelCalculator(void);

   bool              Init(int period, ENUM_SMOOTHER_TYPE type, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersChannelCalculator::CEhlersChannelCalculator(void)
  {
   m_smoother_calc = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEhlersChannelCalculator::~CEhlersChannelCalculator(void)
  {
   if(CheckPointer(m_smoother_calc) != POINTER_INVALID)
      delete m_smoother_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CEhlersChannelCalculator::CreateCalculators(void)
  {
   m_smoother_calc = new CEhlersSmootherCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CEhlersChannelCalculator::Init(int period, ENUM_SMOOTHER_TYPE type, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

   CreateCalculators(); // Creates Smoother Calculator

// Create ATR Calculator
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

// Initialize Smoother (SOURCE_PRICE is standard for channel middle line)
   if(CheckPointer(m_smoother_calc) == POINTER_INVALID || !m_smoother_calc.Init(period, type, SOURCE_PRICE))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CEhlersChannelCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 2)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_atr_buffer) != rates_total)
      ArrayResize(m_atr_buffer, rates_total);

//--- 1. Calculate Middle Line (Smoother)
   m_smoother_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int atr_period = m_atr_calc.GetPeriod();
   int smoother_period = m_smoother_calc.GetPeriod();
   int loop_start = MathMax(MathMax(atr_period, smoother_period), start_index);

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
//|           CLASS 2: CEhlersChannelCalculator_HA                   |
//+==================================================================+
class CEhlersChannelCalculator_HA : public CEhlersChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CEhlersChannelCalculator_HA::CreateCalculators(void)
  {
   m_smoother_calc = new CEhlersSmootherCalculator_HA();
  }
//+------------------------------------------------------------------+
