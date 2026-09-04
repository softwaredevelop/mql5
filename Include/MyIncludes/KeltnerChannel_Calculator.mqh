//+------------------------------------------------------------------+
//|                                     KeltnerChannel_Calculator.mqh|
//|      Engine for Classic Keltner Channels (MA + ATR Envelope)     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00" // Leak-free pointer lifecycle, bounds protection & full VWMA routing

#ifndef KELTNER_CHANNEL_CALCULATOR_MQH
#define KELTNER_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\ATR_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CKeltnerChannelCalculator (Base Class)        |
//+==================================================================+
class CKeltnerChannelCalculator
  {
protected:
   double                    m_multiplier;
   int                       m_ma_period;
   int                       m_atr_period;
   ENUM_MA_TYPE              m_ma_type;
   ENUM_ATR_SOURCE           m_atr_source;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Composition Engines
   CMovingAverageCalculator *m_ma_calc;
   CATRCalculator           *m_atr_calc;

   //--- Persistent State Buffers
   double                    m_atr_buffer[];

   virtual void              CreateCalculators(void);

public:
                     CKeltnerChannelCalculator(void);
   virtual                  ~CKeltnerChannelCalculator(void);

   //--- Enhanced Pro Init (6 Parameters)
   bool                      Init(const int ma_p, const ENUM_MA_TYPE ma_m, const int atr_p, const double mult,
                                  const ENUM_ATR_SOURCE atr_src, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (5 Parameters)
   bool                      Init(const int ma_p, const ENUM_MA_TYPE ma_m, const int atr_p, const double mult, const ENUM_ATR_SOURCE atr_src)
     {
      return Init(ma_p, ma_m, atr_p, mult, atr_src, PRICE_TYPICAL_STD);
     }

   //--- Standard Calculate (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   //--- Overloaded Calculate with Long Volume (For VWMA Support)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       const long &volume[],
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   //--- Overloaded Calculate with Double Volume (For MTF VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &volume[],
                                       double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

   int                       GetRequiredWarmup(void) const { return MathMax(m_ma_period, m_atr_period); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKeltnerChannelCalculator::CKeltnerChannelCalculator(void) : m_multiplier(2.0),
   m_ma_period(20),
   m_atr_period(10),
   m_ma_type(EMA),
   m_atr_source(ATR_SOURCE_STANDARD),
   m_source_price(PRICE_TYPICAL_STD),
   m_ma_calc(NULL),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_atr_buffer, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CKeltnerChannelCalculator::~CKeltnerChannelCalculator(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
     {
      delete m_ma_calc;
      m_ma_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method (Virtual)                                         |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::CreateCalculators(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
     {
      delete m_ma_calc;
      m_ma_calc = NULL;
     }
   m_ma_calc = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator::Init(const int ma_p, const ENUM_MA_TYPE ma_m, const int atr_p, const double mult,
                                     const ENUM_ATR_SOURCE atr_src, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_ma_period    = (ma_p < 1) ? 1 : ma_p;
   m_ma_type      = ma_m;
   m_atr_period   = (atr_p < 1) ? 1 : atr_p;
   m_multiplier   = (mult <= 0.0) ? 2.0 : mult;
   m_atr_source   = atr_src;
   m_source_price = price_source;

// 1. Initialize MA Calculator (Virtual Factory handles HA subclass)
   CreateCalculators();
   if(CheckPointer(m_ma_calc) == POINTER_INVALID || !m_ma_calc.Init(m_ma_period, m_ma_type))
      return false;

// 2. Initialize ATR Calculator
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_atr_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_ma_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(middle_buffer) != rates_total)
     {
      ArrayResize(middle_buffer, rates_total);
      ArraySetAsSeries(middle_buffer, false);
      ArrayInitialize(middle_buffer, EMPTY_VALUE);
     }
   if(ArraySize(upper_buffer) != rates_total)
     {
      ArrayResize(upper_buffer, rates_total);
      ArraySetAsSeries(upper_buffer, false);
      ArrayInitialize(upper_buffer, EMPTY_VALUE);
     }
   if(ArraySize(lower_buffer) != rates_total)
     {
      ArrayResize(lower_buffer, rates_total);
      ArraySetAsSeries(lower_buffer, false);
      ArrayInitialize(lower_buffer, EMPTY_VALUE);
     }

// Resize internal ATR buffer
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total);
      ArraySetAsSeries(m_atr_buffer, false);
     }

// 1. Calculate Middle Line (MA) - Incremental
   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

// 2. Calculate ATR - Incremental
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

// 3. Clean invalid warmup range on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
        {
         middle_buffer[i] = EMPTY_VALUE;
         upper_buffer[i]  = EMPTY_VALUE;
         lower_buffer[i]  = EMPTY_VALUE;
        }
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
   if(start_index < warmup)
      start_index = warmup;

// 4. Calculate Bands
   for(int i = start_index; i < rates_total; i++)
     {
      if(middle_buffer[i] != EMPTY_VALUE && middle_buffer[i] > 0.0 &&
         m_atr_buffer[i] != EMPTY_VALUE && m_atr_buffer[i] > 0.0)
        {
         double channel_width = m_atr_buffer[i] * m_multiplier;
         upper_buffer[i] = middle_buffer[i] + channel_width;
         lower_buffer[i] = middle_buffer[i] - channel_width;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Long Volume for VWMA)               |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const ENUM_APPLIED_PRICE price_type,
      const long &volume[],
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_ma_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

   if(ArraySize(middle_buffer) != rates_total)
     {
      ArrayResize(middle_buffer, rates_total);
      ArraySetAsSeries(middle_buffer, false);
      ArrayInitialize(middle_buffer, EMPTY_VALUE);
     }
   if(ArraySize(upper_buffer) != rates_total)
     {
      ArrayResize(upper_buffer, rates_total);
      ArraySetAsSeries(upper_buffer, false);
      ArrayInitialize(upper_buffer, EMPTY_VALUE);
     }
   if(ArraySize(lower_buffer) != rates_total)
     {
      ArrayResize(lower_buffer, rates_total);
      ArraySetAsSeries(lower_buffer, false);
      ArrayInitialize(lower_buffer, EMPTY_VALUE);
     }

   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total);
      ArraySetAsSeries(m_atr_buffer, false);
     }

// 1. Calculate Middle Line with Volume
   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, middle_buffer);

// 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
        {
         middle_buffer[i] = EMPTY_VALUE;
         upper_buffer[i]  = EMPTY_VALUE;
         lower_buffer[i]  = EMPTY_VALUE;
        }
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
   if(start_index < warmup)
      start_index = warmup;

// 3. Calculate Bands
   for(int i = start_index; i < rates_total; i++)
     {
      if(middle_buffer[i] != EMPTY_VALUE && middle_buffer[i] > 0.0 &&
         m_atr_buffer[i] != EMPTY_VALUE && m_atr_buffer[i] > 0.0)
        {
         double channel_width = m_atr_buffer[i] * m_multiplier;
         upper_buffer[i] = middle_buffer[i] + channel_width;
         lower_buffer[i] = middle_buffer[i] - channel_width;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Double Volume for MTF VWMA)         |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const ENUM_APPLIED_PRICE price_type,
      const double &volume[],
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_ma_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

   if(ArraySize(middle_buffer) != rates_total)
     {
      ArrayResize(middle_buffer, rates_total);
      ArraySetAsSeries(middle_buffer, false);
      ArrayInitialize(middle_buffer, EMPTY_VALUE);
     }
   if(ArraySize(upper_buffer) != rates_total)
     {
      ArrayResize(upper_buffer, rates_total);
      ArraySetAsSeries(upper_buffer, false);
      ArrayInitialize(upper_buffer, EMPTY_VALUE);
     }
   if(ArraySize(lower_buffer) != rates_total)
     {
      ArrayResize(lower_buffer, rates_total);
      ArraySetAsSeries(lower_buffer, false);
      ArrayInitialize(lower_buffer, EMPTY_VALUE);
     }

   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total);
      ArraySetAsSeries(m_atr_buffer, false);
     }

// 1. Calculate Middle Line with Double Volume Array
   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, middle_buffer);

// 2. Calculate ATR
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
        {
         middle_buffer[i] = EMPTY_VALUE;
         upper_buffer[i]  = EMPTY_VALUE;
         lower_buffer[i]  = EMPTY_VALUE;
        }
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
   if(start_index < warmup)
      start_index = warmup;

// 3. Calculate Bands
   for(int i = start_index; i < rates_total; i++)
     {
      if(middle_buffer[i] != EMPTY_VALUE && middle_buffer[i] > 0.0 &&
         m_atr_buffer[i] != EMPTY_VALUE && m_atr_buffer[i] > 0.0)
        {
         double channel_width = m_atr_buffer[i] * m_multiplier;
         upper_buffer[i] = middle_buffer[i] + channel_width;
         lower_buffer[i] = middle_buffer[i] - channel_width;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+==================================================================+
//|             CLASS 2: CKeltnerChannelCalculator_HA (Legacy)       |
//+==================================================================+
class CKeltnerChannelCalculator_HA : public CKeltnerChannelCalculator
  {
protected:
   virtual void      CreateCalculators(void) override;
  };

//+------------------------------------------------------------------+
void CKeltnerChannelCalculator_HA::CreateCalculators(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
     {
      delete m_ma_calc;
      m_ma_calc = NULL;
     }
   m_ma_calc = new CMovingAverageCalculator_HA();
  }

#endif // KELTNER_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
