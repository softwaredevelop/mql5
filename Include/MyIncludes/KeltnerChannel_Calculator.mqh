//+------------------------------------------------------------------+
//|                                     KeltnerChannel_Calculator.mqh|
//|      Engine for Classic Keltner Channels (MA + ATR Envelope)     |
//|      VERSION 5.00: 2026 Enterprise Edition with Capacity Memory, |
//|                    DRY Band Kernel & Strict 64-Bit Pointer Guard |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "5.00"

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
   bool                      EnsureBufferSizes(const int rates_total, double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
   void                      ComputeBands(const int rates_total, const int prev_calculated,
                                          double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);

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

   int                       GetMAPeriod(void)       const { return m_ma_period; }
   int                       GetATRPeriod(void)      const { return m_atr_period; }
   double                    GetMultiplier(void)     const { return m_multiplier; }
   ENUM_MA_TYPE              GetMAType(void)         const { return m_ma_type; }
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
   if(CheckPointer(m_ma_calc) != POINTER_INVALID && m_ma_calc != NULL)
     {
      delete m_ma_calc;
      m_ma_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID && m_atr_calc != NULL)
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
   if(CheckPointer(m_ma_calc) != POINTER_INVALID && m_ma_calc != NULL)
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
   if(CheckPointer(m_ma_calc) == POINTER_INVALID || m_ma_calc == NULL || !m_ma_calc.Init(m_ma_period, m_ma_type))
      return false;

// 2. Initialize ATR Calculator
   if(CheckPointer(m_atr_calc) != POINTER_INVALID && m_atr_calc != NULL)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || m_atr_calc == NULL || !m_atr_calc.Init(m_atr_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Ensure Destination & Internal Buffers (With 2048 Reserve)|
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator::EnsureBufferSizes(const int rates_total, double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_ma_calc) == POINTER_INVALID || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return false;

   if(ArraySize(middle_buffer) != rates_total)
     {
      ArrayResize(middle_buffer, rates_total, 2048);
      ArraySetAsSeries(middle_buffer, false);
     }
   if(ArraySize(upper_buffer) != rates_total)
     {
      ArrayResize(upper_buffer, rates_total, 2048);
      ArraySetAsSeries(upper_buffer, false);
     }
   if(ArraySize(lower_buffer) != rates_total)
     {
      ArrayResize(lower_buffer, rates_total, 2048);
      ArraySetAsSeries(lower_buffer, false);
     }
   if(ArraySize(m_atr_buffer) != rates_total)
     {
      ArrayResize(m_atr_buffer, rates_total, 2048);
      ArraySetAsSeries(m_atr_buffer, false);
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Helper: Shared DRY Band Computation & Warmup Cleanup             |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::ComputeBands(const int rates_total, const int prev_calculated,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int warmup = GetRequiredWarmup();

   if(prev_calculated == 0)
     {
      int clear_limit = MathMin(warmup, rates_total);
      for(int i = 0; i < clear_limit; i++)
        {
         middle_buffer[i] = EMPTY_VALUE;
         upper_buffer[i]  = EMPTY_VALUE;
         lower_buffer[i]  = EMPTY_VALUE;
        }
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : warmup;
   if(start_index < warmup)
      start_index = warmup;

   for(int i = start_index; i < rates_total; i++)
     {
      double mid = middle_buffer[i];
      double atr = m_atr_buffer[i];

      if(mid != EMPTY_VALUE && mid > 0.0 && atr != EMPTY_VALUE && atr > 0.0)
        {
         double channel_width = atr * m_multiplier;
         upper_buffer[i] = mid + channel_width;
         lower_buffer[i] = mid - channel_width;
        }
      else
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(!EnsureBufferSizes(rates_total, middle_buffer, upper_buffer, lower_buffer))
      return;

   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   ComputeBands(rates_total, prev_calculated, middle_buffer, upper_buffer, lower_buffer);
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
   if(!EnsureBufferSizes(rates_total, middle_buffer, upper_buffer, lower_buffer))
      return;

   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, middle_buffer);
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   ComputeBands(rates_total, prev_calculated, middle_buffer, upper_buffer, lower_buffer);
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
   if(!EnsureBufferSizes(rates_total, middle_buffer, upper_buffer, lower_buffer))
      return;

   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, middle_buffer);
   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buffer);

   ComputeBands(rates_total, prev_calculated, middle_buffer, upper_buffer, lower_buffer);
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
   if(CheckPointer(m_ma_calc) != POINTER_INVALID && m_ma_calc != NULL)
     {
      delete m_ma_calc;
      m_ma_calc = NULL;
     }
   m_ma_calc = new CMovingAverageCalculator_HA();
  }

#endif // KELTNER_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
