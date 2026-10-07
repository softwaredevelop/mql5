//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|      Engine for John Ehlers' Laguerre Relative Strength Index    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.10" // Enterprise Refactor: Zero-Copy L0..L3 Pipeline & Persistent Volume Buffers
#property description "High-performance calculation engine for Ehlers' Laguerre RSI."

#ifndef LAGUERRE_RSI_CALCULATOR_MQH
#define LAGUERRE_RSI_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS: CLaguerreRSICalculator                        |
//+==================================================================+
class CLaguerreRSICalculator
  {
protected:
   CLaguerreEngine          *m_engine;
   CMovingAverageCalculator *m_ma_calculator;

   double                    m_gamma;
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Persistent State Buffers
   double                    m_dummy_filt[];
   double                    m_vol_double[];

   virtual void              CreateEngines(void);

public:
                     CLaguerreRSICalculator(void);
   virtual                  ~CLaguerreRSICalculator(void);

   //--- Enhanced Pro Init (4 Parameters)
   bool                      Init(const double gamma, const int signal_p, const ENUM_MA_TYPE signal_ma, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (3 Parameters)
   bool                      Init(const double gamma, const int signal_p, const ENUM_MA_TYPE signal_ma)
     {
      return Init(gamma, signal_p, signal_ma, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculation Method (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[]);

   //--- Modern Unified Calculation Method (With Volume for VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &lrsi_buffer[], double &signal_buffer[]);

   //--- Legacy Overload with price_type parameter (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, lrsi_buffer, signal_buffer);
     }

   //--- Legacy Overload with price_type parameter (With Volume)
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &lrsi_buffer[], double &signal_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, volume, lrsi_buffer, signal_buffer);
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreRSICalculator::CLaguerreRSICalculator(void) :
   m_engine(NULL),
   m_ma_calculator(NULL),
   m_gamma(0.5),
   m_signal_period(3),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_dummy_filt, false);
   ArraySetAsSeries(m_vol_double, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreRSICalculator::~CLaguerreRSICalculator(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }
   if(CheckPointer(m_ma_calculator) != POINTER_INVALID)
     {
      delete m_ma_calculator;
      m_ma_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::CreateEngines(void)
  {
   if(CheckPointer(m_engine) != POINTER_INVALID)
     {
      delete m_engine;
      m_engine = NULL;
     }
   if(CheckPointer(m_ma_calculator) != POINTER_INVALID)
     {
      delete m_ma_calculator;
      m_ma_calculator = NULL;
     }

   m_engine        = new CLaguerreEngine();
   m_ma_calculator = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CLaguerreRSICalculator::Init(const double gamma, const int signal_p, const ENUM_MA_TYPE signal_ma, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_gamma          = fmax(0.0, fmin(1.0, gamma));
   m_signal_period  = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;
   m_source_price   = price_source;

   CreateEngines();

   if(CheckPointer(m_engine) == POINTER_INVALID || !m_engine.Init(m_gamma, SOURCE_PRICE, m_source_price))
      return false;

   if(CheckPointer(m_ma_calculator) == POINTER_INVALID || !m_ma_calculator.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume, Zero-Copy L0..L3 Access)        |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2 || CheckPointer(m_engine) == POINTER_INVALID || CheckPointer(m_ma_calculator) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(lrsi_buffer) != rates_total)
     {
      ArrayResize(lrsi_buffer, rates_total);
      ArraySetAsSeries(lrsi_buffer, false);
      ArrayInitialize(lrsi_buffer, EMPTY_VALUE);
     }
   if(ArraySize(signal_buffer) != rates_total)
     {
      ArrayResize(signal_buffer, rates_total);
      ArraySetAsSeries(signal_buffer, false);
      ArrayInitialize(signal_buffer, EMPTY_VALUE);
     }

// 1. Calculate Laguerre Components in O(1)
   m_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_dummy_filt);

// 2. Direct Inlined LRSI Loop (ELIMINATES 4 massive ArrayCopy calls!)
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      lrsi_buffer[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double l0 = m_engine.GetL0(i);
      double l1 = m_engine.GetL1(i);
      double l2 = m_engine.GetL2(i);
      double l3 = m_engine.GetL3(i);

      double cu = 0.0, cd = 0.0;

      if(l0 >= l1)
         cu += l0 - l1;
      else
         cd += l1 - l0;
      if(l1 >= l2)
         cu += l1 - l2;
      else
         cd += l2 - l1;
      if(l2 >= l3)
         cu += l2 - l3;
      else
         cd += l3 - l2;

      double sum_c = cu + cd;
      double lrsi_val = 50.0;

      if(sum_c > 1.0e-9)
         lrsi_val = (cu / sum_c) * 100.0;
      else
         lrsi_val = (i > 0) ? lrsi_buffer[i - 1] : 50.0;

      if(lrsi_val > 100.0)
         lrsi_val = 100.0;
      else
         if(lrsi_val < 0.0)
            lrsi_val = 0.0;

      lrsi_buffer[i] = lrsi_val;
     }

// 3. Calculate Signal Line in O(1)
   m_ma_calculator.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, signal_buffer, 1);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Persistent Volume for VWMA)         |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 2 || CheckPointer(m_engine) == POINTER_INVALID || CheckPointer(m_ma_calculator) == POINTER_INVALID)
      return;

// Safe allocation of persistent volume buffer (Zero dynamic heap reallocations!)
   if(ArraySize(m_vol_double) != rates_total)
     {
      ArrayResize(m_vol_double, rates_total);
      ArraySetAsSeries(m_vol_double, false);
     }

   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int j = start_sync; j < rates_total; j++)
      m_vol_double[j] = (double)volume[j];

// 1. Calculate base LRSI (Zero-Copy!)
   Calculate(rates_total, prev_calculated, open, high, low, close, lrsi_buffer, signal_buffer);

// 2. Overwrite Signal Line calculation using Persistent Volume
   m_ma_calculator.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, m_vol_double, signal_buffer, 1);
  }

//+==================================================================+
//|             CLASS 2: CLaguerreRSICalculator_HA (Legacy)          |
//+==================================================================+
class CLaguerreRSICalculator_HA : public CLaguerreRSICalculator
  {
protected:
   virtual void      CreateEngines(void) override
     {
      if(CheckPointer(m_engine) != POINTER_INVALID)
        {
         delete m_engine;
         m_engine = NULL;
        }
      if(CheckPointer(m_ma_calculator) != POINTER_INVALID)
        {
         delete m_ma_calculator;
         m_ma_calculator = NULL;
        }

      m_engine        = new CLaguerreEngine_HA();
      m_ma_calculator = new CMovingAverageCalculator();
     }
  };

#endif // LAGUERRE_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
