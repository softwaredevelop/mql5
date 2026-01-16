//+------------------------------------------------------------------+
//|                          Laguerre_Channel_Adaptive_Calculator.mqh|
//|      Adaptive Laguerre Filter Middle Line + ATR Bands.           |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Laguerre_Filter_Adaptive_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|       CLASS 1: CLaguerreChannelAdaptiveCalculator (Base)         |
//+==================================================================+
class CLaguerreChannelAdaptiveCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition
   // We use the Adaptive Filter Calculator as the "Engine" for the middle line
   CLaguerreFilterAdaptiveCalculator *m_adaptive_engine;
   CATRCalculator                    *m_atr_calc;

   //--- Internal Buffer
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CLaguerreChannelAdaptiveCalculator(void);
   virtual          ~CLaguerreChannelAdaptiveCalculator(void);

   bool              Init(int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreChannelAdaptiveCalculator::CLaguerreChannelAdaptiveCalculator(void)
  {
   m_adaptive_engine = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreChannelAdaptiveCalculator::~CLaguerreChannelAdaptiveCalculator(void)
  {
   if(CheckPointer(m_adaptive_engine) != POINTER_INVALID)
      delete m_adaptive_engine;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreChannelAdaptiveCalculator::CreateCalculators(void)
  {
   m_adaptive_engine = new CLaguerreFilterAdaptiveCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreChannelAdaptiveCalculator::Init(int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

   CreateCalculators(); // Creates Adaptive Engine

// Create ATR Calculator
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_adaptive_engine) == POINTER_INVALID || !m_adaptive_engine.Init())
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CLaguerreChannelAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < 10)
      return;

//--- Resize Internal Buffer
   if(ArraySize(m_atr_buffer) != rates_total)
      ArrayResize(m_atr_buffer, rates_total);

//--- 1. Calculate Middle Line (Adaptive Laguerre)
   m_adaptive_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int atr_period = m_atr_calc.GetPeriod();
   int loop_start = MathMax(MathMax(atr_period, 10), start_index);

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
//|       CLASS 2: CLaguerreChannelAdaptiveCalculator_HA             |
//+==================================================================+
class CLaguerreChannelAdaptiveCalculator_HA : public CLaguerreChannelAdaptiveCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
void CLaguerreChannelAdaptiveCalculator_HA::CreateCalculators(void)
  {
   m_adaptive_engine = new CLaguerreFilterAdaptiveCalculator_HA();
  }
//+------------------------------------------------------------------+
