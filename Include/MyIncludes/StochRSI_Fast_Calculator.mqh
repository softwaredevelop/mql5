//+------------------------------------------------------------------+
//|                                      StochRSI_Fast_Calculator.mqh|
//|  VERSION 2.10: Fixed Enum Type Mismatch.                         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Pro_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|           CLASS: CStochRSI_Fast_Calculator                       |
//+==================================================================+
class CStochRSI_Fast_Calculator
  {
protected:
   int               m_rsi_period, m_k_period;

   //--- Composition: RSI Engine + MA Engine
   CRSIProCalculator *m_rsi_calculator;
   CMovingAverageCalculator m_ma_engine; // For %D smoothing

   //--- Persistent Buffers
   double            m_rsi_buffer[];

   double            Highest(const double &array[], int period, int current_pos);
   double            Lowest(const double &array[], int period, int current_pos);

public:
                     CStochRSI_Fast_Calculator(void);
   virtual          ~CStochRSI_Fast_Calculator(void);

   //--- Init now takes ENUM_MA_TYPE for %D
   bool              Init(int rsi_p, int k_p, int d_p, ENUM_MA_TYPE d_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::CStochRSI_Fast_Calculator(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator::~CStochRSI_Fast_Calculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochRSI_Fast_Calculator::Init(int rsi_p, int k_p, int d_p, ENUM_MA_TYPE d_ma)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_k_period   = (k_p < 1) ? 1 : k_p;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return false;

// Init RSI calculator (MA params for RSI bands are dummy here as we only need RSI line)
// FIX: Use 'SMA' (from ENUM_MA_TYPE) instead of 'MODE_SMA'
   if(!m_rsi_calculator.Init(m_rsi_period, 1, SMA, 2.0))
      return false;

// Init MA Engine for %D
   return m_ma_engine.Init(d_p, d_ma);
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochRSI_Fast_Calculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
// Minimum bars check
   int min_bars = m_rsi_period + m_k_period + m_ma_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_rsi_buffer) != rates_total)
      ArrayResize(m_rsi_buffer, rates_total);

//--- 1. Calculate RSI (Incremental)
   double dummy1[], dummy2[], dummy3[];
// Note: RSI Calculator handles its own incremental logic
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                              m_rsi_buffer, dummy1, dummy2, dummy3);

//--- 2. Calculate %K (StochRSI)
// RSI is valid from index: m_rsi_period
// StochRSI needs 'm_k_period' of RSI data.
// So StochRSI starts at: m_rsi_period + m_k_period - 1
   int k_start_offset = m_rsi_period + m_k_period - 1;
   int loop_start_k = MathMax(k_start_offset, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      double highest_rsi = Highest(m_rsi_buffer, m_k_period, i);
      double lowest_rsi  = Lowest(m_rsi_buffer, m_k_period, i);
      double range = highest_rsi - lowest_rsi;

      if(range > 0.00001)
         k_buffer[i] = (m_rsi_buffer[i] - lowest_rsi) / range * 100.0;
      else
         k_buffer[i] = (i > 0) ? k_buffer[i-1] : 50.0;
     }

//--- 3. Calculate %D (Signal Line) using MA Engine
// Pass the correct offset to avoid smoothing invalid data
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, k_start_offset);
  }

//+------------------------------------------------------------------+
//| Highest                                                          |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Highest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res < array[index])
         res = array[index];
     }
   return(res);
  }

//+------------------------------------------------------------------+
//| Lowest                                                           |
//+------------------------------------------------------------------+
double CStochRSI_Fast_Calculator::Lowest(const double &array[], int period, int current_pos)
  {
   double res = array[current_pos];
   for(int i = 1; i < period; i++)
     {
      int index = current_pos - i;
      if(index < 0)
         break;
      if(res > array[index])
         res = array[index];
     }
   return(res);
  }

//+==================================================================+
//|         CLASS 2: CStochRSI_Fast_Calculator_HA (Heikin Ashi)      |
//+==================================================================+
class CStochRSI_Fast_Calculator_HA : public CStochRSI_Fast_Calculator
  {
public:
                     CStochRSI_Fast_Calculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CStochRSI_Fast_Calculator_HA::CStochRSI_Fast_Calculator_HA(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
// Use HA version of RSI calculator
   m_rsi_calculator = new CRSIProCalculator_HA();
  }
//+------------------------------------------------------------------+
