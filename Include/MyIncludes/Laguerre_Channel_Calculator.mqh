//+------------------------------------------------------------------+
//|                                  Laguerre_Channel_Calculator.mqh |
//|      Laguerre Filter Middle Line + ATR Bands (Keltner Concept).  |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CLaguerreChannelCalculator (Base)             |
//+==================================================================+
class CLaguerreChannelCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition
   CLaguerreEngine   *m_laguerre_engine;
   CATRCalculator    *m_atr_calc;

   //--- Internal Buffer
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CLaguerreChannelCalculator(void);
   virtual          ~CLaguerreChannelCalculator(void);

   bool              Init(double gamma, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreChannelCalculator::CLaguerreChannelCalculator(void)
  {
   m_laguerre_engine = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreChannelCalculator::~CLaguerreChannelCalculator(void)
  {
   if(CheckPointer(m_laguerre_engine) != POINTER_INVALID)
      delete m_laguerre_engine;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreChannelCalculator::CreateCalculators(void)
  {
   m_laguerre_engine = new CLaguerreEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreChannelCalculator::Init(double gamma, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

   CreateCalculators(); // Creates Laguerre Engine

// Create ATR Calculator
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_laguerre_engine) == POINTER_INVALID || !m_laguerre_engine.Init(gamma, SOURCE_PRICE))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreChannelCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 2)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_atr_buffer) != rates_total)
      ArrayResize(m_atr_buffer, rates_total);

//--- 1. Calculate Middle Line (Laguerre)
   m_laguerre_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int atr_period = m_atr_calc.GetPeriod();
   int loop_start = MathMax(atr_period, start_index);

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
//|           CLASS 2: CLaguerreChannelCalculator_HA                 |
//+==================================================================+
class CLaguerreChannelCalculator_HA : public CLaguerreChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
void CLaguerreChannelCalculator_HA::CreateCalculators(void)
  {
   m_laguerre_engine = new CLaguerreEngine_HA();
  }
//+------------------------------------------------------------------+
