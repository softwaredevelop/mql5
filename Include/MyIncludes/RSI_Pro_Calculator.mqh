//+------------------------------------------------------------------+
//|                                           RSI_Pro_Calculator.mqh |
//|        VERSION 4.00: Refactored to use RSI_Engine.               |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CRSIProCalculator
  {
protected:
   CRSIEngine        *m_rsi_engine;
   CMovingAverageCalculator m_ma_engine;

   int               m_rsi_period, m_ma_period;
   double            m_deviation;

   //--- Internal Buffers
   double            m_rsi_buffer[];
   double            m_ma_buffer[];

   virtual void      CreateEngine(void);

public:
                     CRSIProCalculator(void);
   virtual          ~CRSIProCalculator(void);

   bool              Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, double dev);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRSIProCalculator::CRSIProCalculator(void) { m_rsi_engine = NULL; }
CRSIProCalculator::~CRSIProCalculator(void) { if(CheckPointer(m_rsi_engine) != POINTER_INVALID) delete m_rsi_engine; }

void CRSIProCalculator::CreateEngine(void) { m_rsi_engine = new CRSIEngine(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(int rsi_p, int ma_p, ENUM_MA_TYPE ma_m, double dev)
  {
   m_rsi_period = rsi_p;
   m_ma_period = ma_p;
   m_deviation = dev;
   CreateEngine();
   if(!m_rsi_engine.Init(m_rsi_period))
      return false;
   if(!m_ma_engine.Init(m_ma_period, ma_m))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CRSIProCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

// 1. Calculate RSI
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

// 2. Calculate MA
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, m_ma_buffer, m_rsi_period);

// 3. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_rsi_period + m_ma_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
         sum_sq += pow(m_rsi_buffer[i-j] - m_ma_buffer[i], 2);
      double std_dev = sqrt(sum_sq / m_ma_period);

      rsi_out[i] = m_rsi_buffer[i];
      ma_out[i] = m_ma_buffer[i];
      upper_out[i] = m_ma_buffer[i] + m_deviation * std_dev;
      lower_out[i] = m_ma_buffer[i] - m_deviation * std_dev;
     }
  }

//--- HA Subclass
class CRSIProCalculator_HA : public CRSIProCalculator
  {
protected:
   virtual void      CreateEngine(void) override { m_rsi_engine = new CRSIEngine_HA(); }
  };
//+------------------------------------------------------------------+
