//+------------------------------------------------------------------+
//|                                     Laguerre_RSI_Calculator.mqh  |
//|      Engine for John Ehlers' Laguerre Relative Strength Index    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Leak-free pointer management, bounds protection & VWMA support

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
   double                    m_L0[], m_L1[], m_L2[], m_L3[];

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
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &lrsi_buffer[], double &signal_buffer[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, lrsi_buffer, signal_buffer);
     }

   //--- Legacy Overload with price_type parameter (With Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
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
CLaguerreRSICalculator::CLaguerreRSICalculator(void) : m_engine(NULL),
   m_ma_calculator(NULL),
   m_gamma(0.5),
   m_signal_period(3),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_dummy_filt, false);
   ArraySetAsSeries(m_L0,         false);
   ArraySetAsSeries(m_L1,         false);
   ArraySetAsSeries(m_L2,         false);
   ArraySetAsSeries(m_L3,         false);
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
//| Calculate (Standard - No Volume)                                 |
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

// 1. Calculate Laguerre Components
   m_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_dummy_filt);

// 2. Retrieve L0..L3 state buffers
   m_engine.GetLBuffers(m_L0, m_L1, m_L2, m_L3);

// 3. Calculate LRSI (Incremental Loop)
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      lrsi_buffer[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;

      if(m_L0[i] >= m_L1[i])
         cu += m_L0[i] - m_L1[i];
      else
         cd += m_L1[i] - m_L0[i];
      if(m_L1[i] >= m_L2[i])
         cu += m_L1[i] - m_L2[i];
      else
         cd += m_L2[i] - m_L1[i];
      if(m_L2[i] >= m_L3[i])
         cu += m_L2[i] - m_L3[i];
      else
         cd += m_L3[i] - m_L2[i];

      double lrsi_val = 50.0;
      if(cu + cd > 1.0e-9)
         lrsi_val = (cu / (cu + cd)) * 100.0;
      else
         lrsi_val = (i > 0) ? lrsi_buffer[i - 1] : 50.0;

      if(lrsi_val > 100.0)
         lrsi_val = 100.0;
      if(lrsi_val < 0.0)
         lrsi_val = 0.0;

      lrsi_buffer[i] = lrsi_val;
     }

// 4. Calculate Signal Line (Without Volume)
   m_ma_calculator.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, signal_buffer, 1);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CLaguerreRSICalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
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

// 1. Calculate Laguerre Components
   m_engine.CalculateFilter(rates_total, prev_calculated, open, high, low, close, m_dummy_filt);

// 2. Retrieve L0..L3 state buffers
   m_engine.GetLBuffers(m_L0, m_L1, m_L2, m_L3);

// 3. Calculate LRSI
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

   if(prev_calculated == 0)
     {
      lrsi_buffer[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double cu = 0.0, cd = 0.0;

      if(m_L0[i] >= m_L1[i])
         cu += m_L0[i] - m_L1[i];
      else
         cd += m_L1[i] - m_L0[i];
      if(m_L1[i] >= m_L2[i])
         cu += m_L1[i] - m_L2[i];
      else
         cd += m_L2[i] - m_L1[i];
      if(m_L2[i] >= m_L3[i])
         cu += m_L2[i] - m_L3[i];
      else
         cd += m_L3[i] - m_L2[i];

      double lrsi_val = 50.0;
      if(cu + cd > 1.0e-9)
         lrsi_val = (cu / (cu + cd)) * 100.0;
      else
         lrsi_val = (i > 0) ? lrsi_buffer[i - 1] : 50.0;

      if(lrsi_val > 100.0)
         lrsi_val = 100.0;
      if(lrsi_val < 0.0)
         lrsi_val = 0.0;

      lrsi_buffer[i] = lrsi_val;
     }

// 4. Convert volume to double array for VWMA support
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);

   for(int j = start_index; j < rates_total; j++)
      vol_double[j] = (double)volume[j];

// 5. Calculate Signal Line (With Volume)
   m_ma_calculator.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, vol_double, signal_buffer, 1);
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
