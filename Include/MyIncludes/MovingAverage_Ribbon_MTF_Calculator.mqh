//+------------------------------------------------------------------+
//|                           MovingAverage_Ribbon_MTF_Calculator.mqh|
//|      Engine for the fully customizable MTF MA Ribbon.            |
//|      Contains both the Line Helper and the Ribbon Manager.       |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//| HELPER CLASS: CSingleMAMTFCalculator                             |
//| Handles the logic, state, and buffers for ONE MTF line.          |
//+==================================================================+
class CSingleMAMTFCalculator
  {
private:
   CMovingAverageCalculator *m_calculator;

   //--- MTF Settings
   ENUM_TIMEFRAMES   m_timeframe;
   bool              m_is_mtf;

   //--- Persistent State for MTF Calculation
   double            m_htf_buffer[];      // Stores HTF MA values between ticks
   int               m_htf_prev_calc;     // Tracks how many HTF bars are already calculated

public:
                     CSingleMAMTFCalculator(void);
                    ~CSingleMAMTFCalculator(void);

   bool              Init(ENUM_TIMEFRAMES tf, int period, ENUM_MA_TYPE type, bool is_ha);

   void              Calculate(int rates_total, int prev_calculated, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &output_buffer[]);
  };

//+------------------------------------------------------------------+
//| CSingleMAMTFCalculator Implementation                            |
//+------------------------------------------------------------------+
CSingleMAMTFCalculator::CSingleMAMTFCalculator(void) : m_calculator(NULL), m_htf_prev_calc(0) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSingleMAMTFCalculator::~CSingleMAMTFCalculator(void)
  {
   if(CheckPointer(m_calculator) != POINTER_INVALID)
      delete m_calculator;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSingleMAMTFCalculator::Init(ENUM_TIMEFRAMES tf, int period, ENUM_MA_TYPE type, bool is_ha)
  {
   m_timeframe = (tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : tf;
   m_is_mtf = (m_timeframe > Period());

   if(m_timeframe < Period())
      return false;

   if(is_ha)
      m_calculator = new CMovingAverageCalculator_HA();
   else
      m_calculator = new CMovingAverageCalculator();

   if(CheckPointer(m_calculator) == POINTER_INVALID || !m_calculator.Init(period, type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSingleMAMTFCalculator::Calculate(int rates_total, int prev_calculated, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &output_buffer[])
  {
   if(CheckPointer(m_calculator) == POINTER_INVALID)
      return;

   if(prev_calculated == 0)
      m_htf_prev_calc = 0;

//--- MTF MODE ---
   if(m_is_mtf)
     {
      int htf_rates = (int)SeriesInfoInteger(_Symbol, m_timeframe, SERIES_BARS_COUNT);
      if(htf_rates < m_calculator.GetPeriod())
         return;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];

      // Fetch Data (Full history copy for safety, optimized math follows)
      if(CopyTime(_Symbol, m_timeframe, 0, htf_rates, htf_time) <= 0 ||
         CopyOpen(_Symbol, m_timeframe, 0, htf_rates, htf_open) <= 0 ||
         CopyHigh(_Symbol, m_timeframe, 0, htf_rates, htf_high) <= 0 ||
         CopyLow(_Symbol, m_timeframe, 0, htf_rates, htf_low) <= 0 ||
         CopyClose(_Symbol, m_timeframe, 0, htf_rates, htf_close) <= 0)
         return;

      if(ArraySize(m_htf_buffer) != htf_rates)
         ArrayResize(m_htf_buffer, htf_rates);

      // Incremental HTF Calculation
      // Step back 1 bar to ensure open candle updates
      int htf_calc_start = (m_htf_prev_calc > 0) ? m_htf_prev_calc - 1 : 0;

      m_calculator.Calculate(htf_rates, htf_calc_start, price_type, htf_open, htf_high, htf_low, htf_close, m_htf_buffer);
      m_htf_prev_calc = htf_rates;

      // Mapping Logic (The Staircase)
      // CRITICAL: Set HTF buffer as SERIES to match iBarShift (0 = Newest)
      ArraySetAsSeries(htf_time, true);
      ArraySetAsSeries(m_htf_buffer, true);
      ArraySetAsSeries(time, false);          // Ensure standard indexing
      ArraySetAsSeries(output_buffer, false); // Ensure standard indexing

      int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;

      for(int i = limit; i < rates_total; i++)
        {
         int htf_shift = iBarShift(_Symbol, m_timeframe, time[i], false);

         if(htf_shift >= 0 && htf_shift < htf_rates)
            output_buffer[i] = m_htf_buffer[htf_shift];
         else
            output_buffer[i] = EMPTY_VALUE;
        }

      // Restore HTF buffer to non-series for next calculation cycle
      ArraySetAsSeries(m_htf_buffer, false);
      ArraySetAsSeries(htf_time, false);
     }
//--- CURRENT TF MODE ---
   else
     {
      m_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, output_buffer);
     }
  }


//+==================================================================+
//| MAIN CLASS: CMovingAverageRibbonMTFCalculator                    |
//| Manages the 4 instances of the helper class.                     |
//+==================================================================+
class CMovingAverageRibbonMTFCalculator
  {
protected:
   // Composition: 4 independent instances
   CSingleMAMTFCalculator *m_ma1, *m_ma2, *m_ma3, *m_ma4;

public:
                     CMovingAverageRibbonMTFCalculator(void);
   virtual          ~CMovingAverageRibbonMTFCalculator(void);

   bool              Init(ENUM_TIMEFRAMES tf1, int p1, ENUM_MA_TYPE t1,
                          ENUM_TIMEFRAMES tf2, int p2, ENUM_MA_TYPE t2,
                          ENUM_TIMEFRAMES tf3, int p3, ENUM_MA_TYPE t3,
                          ENUM_TIMEFRAMES tf4, int p4, ENUM_MA_TYPE t4,
                          bool is_ha);

   void              Calculate(int rates_total, int prev_calculated, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[]);
  };

//+------------------------------------------------------------------+
//| CMovingAverageRibbonMTFCalculator Implementation                 |
//+------------------------------------------------------------------+
CMovingAverageRibbonMTFCalculator::CMovingAverageRibbonMTFCalculator(void)
  {
   m_ma1 = NULL;
   m_ma2 = NULL;
   m_ma3 = NULL;
   m_ma4 = NULL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageRibbonMTFCalculator::~CMovingAverageRibbonMTFCalculator(void)
  {
   if(CheckPointer(m_ma1) != POINTER_INVALID)
      delete m_ma1;
   if(CheckPointer(m_ma2) != POINTER_INVALID)
      delete m_ma2;
   if(CheckPointer(m_ma3) != POINTER_INVALID)
      delete m_ma3;
   if(CheckPointer(m_ma4) != POINTER_INVALID)
      delete m_ma4;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMovingAverageRibbonMTFCalculator::Init(ENUM_TIMEFRAMES tf1, int p1, ENUM_MA_TYPE t1,
      ENUM_TIMEFRAMES tf2, int p2, ENUM_MA_TYPE t2,
      ENUM_TIMEFRAMES tf3, int p3, ENUM_MA_TYPE t3,
      ENUM_TIMEFRAMES tf4, int p4, ENUM_MA_TYPE t4,
      bool is_ha)
  {
   m_ma1 = new CSingleMAMTFCalculator();
   m_ma2 = new CSingleMAMTFCalculator();
   m_ma3 = new CSingleMAMTFCalculator();
   m_ma4 = new CSingleMAMTFCalculator();

   if(CheckPointer(m_ma1) == POINTER_INVALID || !m_ma1.Init(tf1, p1, t1, is_ha) ||
      CheckPointer(m_ma2) == POINTER_INVALID || !m_ma2.Init(tf2, p2, t2, is_ha) ||
      CheckPointer(m_ma3) == POINTER_INVALID || !m_ma3.Init(tf3, p3, t3, is_ha) ||
      CheckPointer(m_ma4) == POINTER_INVALID || !m_ma4.Init(tf4, p4, t4, is_ha))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMovingAverageRibbonMTFCalculator::Calculate(int rates_total, int prev_calculated, const datetime &time[], ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma1_buffer[], double &ma2_buffer[], double &ma3_buffer[], double &ma4_buffer[])
  {
   if(CheckPointer(m_ma1) == POINTER_INVALID)
      return;

// Delegate with prev_calculated
   m_ma1.Calculate(rates_total, prev_calculated, time, price_type, open, high, low, close, ma1_buffer);
   m_ma2.Calculate(rates_total, prev_calculated, time, price_type, open, high, low, close, ma2_buffer);
   m_ma3.Calculate(rates_total, prev_calculated, time, price_type, open, high, low, close, ma3_buffer);
   m_ma4.Calculate(rates_total, prev_calculated, time, price_type, open, high, low, close, ma4_buffer);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
