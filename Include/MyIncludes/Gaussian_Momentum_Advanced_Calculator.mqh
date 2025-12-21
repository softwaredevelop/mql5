//+------------------------------------------------------------------+
//|                        Gaussian_Momentum_Advanced_Calculator.mqh |
//|      Advanced Engine: Gaussian Momentum + Signal Line.           |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Gaussian_Filter_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS: CGaussianMomentumAdvancedCalculator           |
//+==================================================================+
class CGaussianMomentumAdvancedCalculator
  {
protected:
   //--- Composition
   CGaussianFilterCalculator *m_mom_calc;
   CMovingAverageCalculator   m_sig_calc;

public:
                     CGaussianMomentumAdvancedCalculator(void);
   virtual          ~CGaussianMomentumAdvancedCalculator(void);

   bool              Init(int mom_period, int sig_period, ENUM_MA_TYPE sig_type, bool use_ha);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &mom_buffer[], double &sig_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGaussianMomentumAdvancedCalculator::CGaussianMomentumAdvancedCalculator(void) : m_mom_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGaussianMomentumAdvancedCalculator::~CGaussianMomentumAdvancedCalculator(void)
  {
   if(CheckPointer(m_mom_calc) != POINTER_INVALID)
      delete m_mom_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CGaussianMomentumAdvancedCalculator::Init(int mom_period, int sig_period, ENUM_MA_TYPE sig_type, bool use_ha)
  {
// Instantiate correct momentum calculator
   if(use_ha)
      m_mom_calc = new CGaussianFilterCalculator_HA();
   else
      m_mom_calc = new CGaussianFilterCalculator();

// Init Momentum (SOURCE_MOMENTUM mode)
   if(!m_mom_calc.Init(mom_period, SOURCE_MOMENTUM))
      return false;

// Init Signal
   if(!m_sig_calc.Init(sig_period, sig_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CGaussianMomentumAdvancedCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &mom_buffer[], double &sig_buffer[])
  {
   if(CheckPointer(m_mom_calc) == POINTER_INVALID)
      return;

// 1. Calculate Momentum
   m_mom_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, mom_buffer);

// 2. Calculate Signal Line
// Offset: 2 (Gaussian Filter warmup)
   m_sig_calc.CalculateOnArray(rates_total, prev_calculated, mom_buffer, sig_buffer, 2);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
