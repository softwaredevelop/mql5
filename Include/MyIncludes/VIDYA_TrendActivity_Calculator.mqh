//+------------------------------------------------------------------+
//|                                 VIDYA_TrendActivity_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi VIDYA Activity.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\VIDYA_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh> // CORRECTED: Include the ATR calculator to get the enum and class

//+==================================================================+
//|                                                                  |
//|         CLASS 1: CVIDYATrendActivityCalculator (Base Class)      |
//|                                                                  |
//+==================================================================+
class CVIDYATrendActivityCalculator
  {
protected:
   int               m_smoothing_period;
   double            m_pi_div_2;
   CVIDYACalculator  *m_vidya_calculator;
   CATRCalculator    *m_atr_calculator;

public:
                     CVIDYATrendActivityCalculator(void);
   virtual          ~CVIDYATrendActivityCalculator(void);

   bool              Init(int cmo_p, int ema_p, int atr_p, ENUM_ATR_SOURCE atr_src, int smooth_p);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &activity_buffer[]);
  };

//+------------------------------------------------------------------+
//| CVIDYATrendActivityCalculator: Constructor                       |
//+------------------------------------------------------------------+
CVIDYATrendActivityCalculator::CVIDYATrendActivityCalculator(void)
  {
   m_vidya_calculator = new CVIDYACalculator();
   m_atr_calculator = NULL; // Will be created in Init
  }

//+------------------------------------------------------------------+
//| CVIDYATrendActivityCalculator: Destructor                        |
//+------------------------------------------------------------------+
CVIDYATrendActivityCalculator::~CVIDYATrendActivityCalculator(void)
  {
   if(CheckPointer(m_vidya_calculator) != POINTER_INVALID)
      delete m_vidya_calculator;
   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;
  }

//+------------------------------------------------------------------+
//| CVIDYATrendActivityCalculator: Initialization                    |
//+------------------------------------------------------------------+
bool CVIDYATrendActivityCalculator::Init(int cmo_p, int ema_p, int atr_p, ENUM_ATR_SOURCE atr_src, int smooth_p)
  {
   m_smoothing_period = (smooth_p < 1) ? 1 : smooth_p;
   m_pi_div_2 = M_PI / 2.0;

   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;

   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calculator = new CATRCalculator_HA();
   else
      m_atr_calculator = new CATRCalculator();

   if(CheckPointer(m_vidya_calculator) == POINTER_INVALID || CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return false;

   return(m_vidya_calculator.Init(cmo_p, ema_p) && m_atr_calculator.Init(atr_p));
  }

//+------------------------------------------------------------------+
//| CVIDYATrendActivityCalculator: Main Calculation Method           |
//+------------------------------------------------------------------+
void CVIDYATrendActivityCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &activity_buffer[])
  {
   if(CheckPointer(m_vidya_calculator) == POINTER_INVALID || CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return;

   double vidya_buffer[], atr_buffer[];
   ArrayResize(vidya_buffer, rates_total);
   ArrayResize(atr_buffer, rates_total);

   m_vidya_calculator.Calculate(rates_total, price_type, open, high, low, close, vidya_buffer);
   m_atr_calculator.Calculate(rates_total, open, high, low, close, atr_buffer);

   double scaled_activity[];
   ArrayResize(scaled_activity, rates_total);
   for(int i = 1; i < rates_total; i++)
     {
      if(atr_buffer[i] > 0)
        {
         double raw_activity = MathAbs(vidya_buffer[i] - vidya_buffer[i-1]) / atr_buffer[i];
         scaled_activity[i] = MathArctan(raw_activity) / m_pi_div_2;
        }
     }

   for(int i = m_smoothing_period - 1; i < rates_total; i++)
     {
      double sum = 0;
      for(int j=0; j<m_smoothing_period; j++)
         sum += scaled_activity[i-j];
      if(m_smoothing_period > 0)
         activity_buffer[i] = sum / m_smoothing_period;
     }
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CVIDYATrendActivityCalculator_HA (Heikin Ashi)    |
//|                                                                  |
//+==================================================================+
class CVIDYATrendActivityCalculator_HA : public CVIDYATrendActivityCalculator
  {
public:
                     CVIDYATrendActivityCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//| CVIDYATrendActivityCalculator_HA: Constructor                    |
//+------------------------------------------------------------------+
CVIDYATrendActivityCalculator_HA::CVIDYATrendActivityCalculator_HA(void)
  {
   if(CheckPointer(m_vidya_calculator) != POINTER_INVALID)
      delete m_vidya_calculator;
   m_vidya_calculator = new CVIDYACalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
