//+------------------------------------------------------------------+
//|                                     KeltnerChannel_Calculator.mqh|
//|      VERSION 3.00: Uses MovingAverage_Engine & ATR Engine.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//--- Define the Enum here, BEFORE the class uses it ---
enum ENUM_ATR_SOURCE
  {
   ATR_SOURCE_STANDARD,    // Calculate ATR from standard candles
   ATR_SOURCE_HEIKIN_ASHI  // Calculate ATR from Heikin Ashi candles
  };

//+==================================================================+
//|           CLASS 1: CKeltnerChannelCalculator (Base Class)        |
//+==================================================================+
class CKeltnerChannelCalculator
  {
protected:
   double            m_multiplier;

   //--- Composition: Use dedicated engines
   CMovingAverageCalculator *m_ma_calc;
   CATRCalculator           *m_atr_calc;

   //--- Internal Buffers for intermediate results
   double            m_atr_buffer[];

   virtual void      CreateCalculators(void);

public:
                     CKeltnerChannelCalculator(void);
   virtual          ~CKeltnerChannelCalculator(void);

   //--- Init now takes ENUM_MA_TYPE
   bool              Init(int ma_p, ENUM_MA_TYPE ma_m, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKeltnerChannelCalculator::CKeltnerChannelCalculator(void)
  {
   m_ma_calc = NULL;
   m_atr_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CKeltnerChannelCalculator::~CKeltnerChannelCalculator(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method (Virtual)                                         |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::CreateCalculators(void)
  {
   m_ma_calc = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator::Init(int ma_p, ENUM_MA_TYPE ma_m, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_multiplier = (mult <= 0) ? 2.0 : mult;

// Create MA Calculator (Virtual call handles HA override)
   CreateCalculators();

// Create ATR Calculator based on source selection
   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_ma_calc) == POINTER_INVALID || !m_ma_calc.Init(ma_p, ma_m))
      return false;

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(atr_p, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(CheckPointer(m_ma_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

//--- Resize internal ATR buffer
   if(ArraySize(m_atr_buffer) != rates_total)
      ArrayResize(m_atr_buffer, rates_total);

//--- 1. Calculate Middle Line (MA) - Incremental
   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate ATR - Incremental
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

//--- 3. Calculate Bands - Incremental Loop
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int ma_period = m_ma_calc.GetPeriod();
   int atr_period = m_atr_calc.GetPeriod();
   int start_pos = MathMax(ma_period, atr_period);

   int loop_start = MathMax(start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Ensure both components are valid
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
//|             CLASS 2: CKeltnerChannelCalculator_HA                |
//+==================================================================+
class CKeltnerChannelCalculator_HA : public CKeltnerChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
void CKeltnerChannelCalculator_HA::CreateCalculators(void)
  {
// Override to create HA version of MA calculator
   m_ma_calc = new CMovingAverageCalculator_HA();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
