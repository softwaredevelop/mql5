//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|      VERSION 1.20: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CLaguerreRSICalculator
  {
protected:
   CLaguerreEngine   *m_engine;
   int               m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;

   //--- Internal MA Calculator for Signal Line (Optimization)
   CMovingAverageCalculator *m_ma_calculator;

public:
                     CLaguerreRSICalculator(void);
   virtual          ~CLaguerreRSICalculator(void);

   bool              Init(double gamma, int signal_p, ENUM_MA_TYPE signal_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreRSICalculator::CLaguerreRSICalculator(void)
  {
   m_engine = new CLaguerreEngine();
   m_ma_calculator = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreRSICalculator::~CLaguerreRSICalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
      delete m_engine;
   if(CheckPointer(m_ma_calculator) != POINTER_INVALID)
      delete m_ma_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreRSICalculator::Init(double gamma, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;

   if(!m_engine.Init(gamma, SOURCE_PRICE))
      return false;
   if(!m_ma_calculator.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2)
      return;

//--- 1. Calculate Laguerre Components (Incremental)
   double dummy_filt[]; // We don't use the filter output here, just internal state
   m_engine.CalculateFilter(rates_total, prev_calculated, price_type, open, high, low, close, dummy_filt);

//--- 2. Retrieve L0..L3 buffers
   double L0[], L1[], L2[], L3[];
   m_engine.GetLBuffers(L0, L1, L2, L3);

//--- 3. Calculate LRSI (Incremental Loop)
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 1;
   if(start_index < 1)
      start_index = 1;

   for(int i = start_index; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;

      if(L0[i] >= L1[i])
         cu = L0[i] - L1[i];
      else
         cd = L1[i] - L0[i];

      if(L1[i] >= L2[i])
         cu += L1[i] - L2[i];
      else
         cd += L2[i] - L1[i];

      if(L2[i] >= L3[i])
         cu += L2[i] - L3[i];
      else
         cd += L3[i] - L2[i];

      double lrsi_value;
      if(cu + cd > 0.0)
         lrsi_value = 100.0 * cu / (cu + cd);
      else
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0; // Fallback to previous or neutral

      // Clamp
      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;

      lrsi_buffer[i] = lrsi_value;
     }

//--- 4. Calculate Signal Line (Using Optimized Engine)
// We pass lrsi_buffer as the 'close' price for the MA calculator.
// The other arrays (open, high, low) are dummy, but we pass lrsi_buffer to be safe.
   m_ma_calculator.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                             lrsi_buffer, lrsi_buffer, lrsi_buffer, lrsi_buffer,
                             signal_buffer);
  }

//+==================================================================+
//|             CLASS 2: CLaguerreRSICalculator_HA                   |
//+==================================================================+
class CLaguerreRSICalculator_HA : public CLaguerreRSICalculator
  {
public:
                     CLaguerreRSICalculator_HA(void)
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
         delete m_engine;
      m_engine = new CLaguerreEngine_HA();

      // m_ma_calculator is already created in base constructor
     };
  };
//+------------------------------------------------------------------+
