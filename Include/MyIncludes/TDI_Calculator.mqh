//+------------------------------------------------------------------+
//|                                               TDI_Calculator.mqh |
//|      VERSION 3.10: Refactored to use RSI_Engine.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTDICalculator
  {
protected:
   CRSIEngine        *m_rsi_engine;
   CMovingAverageCalculator m_price_line_engine;
   CMovingAverageCalculator m_signal_line_engine;
   CMovingAverageCalculator m_base_line_engine;

   int               m_rsi_period, m_price_period, m_signal_period, m_base_period;
   double            m_std_dev;

   double            m_rsi_buffer[];
   double            m_price_line[];
   double            m_base_line[];

   virtual void      CreateRSIEngine(void);

public:
                     CTDICalculator(void);
   virtual          ~CTDICalculator(void);

   bool              Init(int rsi_p, int price_p, int signal_p, int base_p, double dev);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTDICalculator::CTDICalculator(void) { m_rsi_engine = NULL; }
CTDICalculator::~CTDICalculator(void) { if(CheckPointer(m_rsi_engine) != POINTER_INVALID) delete m_rsi_engine; }

void CTDICalculator::CreateRSIEngine(void) { m_rsi_engine = new CRSIEngine(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTDICalculator::Init(int rsi_p, int price_p, int signal_p, int base_p, double dev)
  {
   m_rsi_period = rsi_p;
   m_price_period = price_p;
   m_signal_period = signal_p;
   m_base_period = base_p;
   m_std_dev = dev;
   CreateRSIEngine();
   if(!m_rsi_engine.Init(m_rsi_period))
      return false;
   if(!m_price_line_engine.Init(m_price_period, SMA))
      return false;
   if(!m_signal_line_engine.Init(m_signal_period, SMA))
      return false;
   if(!m_base_line_engine.Init(m_base_period, SMA))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTDICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total <= m_rsi_period + m_base_period)
      return;

   if(ArraySize(m_rsi_buffer) != rates_total)
     {
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_price_line, rates_total);
      ArrayResize(m_base_line, rates_total);
     }

// 1. Calculate RSI
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

// 2. Calculate Price Line
   m_price_line_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, m_price_line, m_rsi_period);
   ArrayCopy(price_line_out, m_price_line, 0, 0, rates_total);

// 3. Calculate Signal Line
   int signal_start = m_rsi_period + m_price_period - 1;
   m_signal_line_engine.CalculateOnArray(rates_total, prev_calculated, m_price_line, signal_line_out, signal_start);

// 4. Calculate Base Line
   m_base_line_engine.CalculateOnArray(rates_total, prev_calculated, m_rsi_buffer, m_base_line, m_rsi_period);
   ArrayCopy(base_line_out, m_base_line, 0, 0, rates_total);

// 5. Calculate Bands
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int loop_start = MathMax(m_rsi_period + m_base_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;
      for(int j = 0; j < m_base_period; j++)
         sum_sq += pow(m_rsi_buffer[i-j] - m_base_line[i], 2);
      double std_dev = sqrt(sum_sq / m_base_period);

      upper_band_out[i] = m_base_line[i] + m_std_dev * std_dev;
      lower_band_out[i] = m_base_line[i] - m_std_dev * std_dev;
     }
  }

//--- HA Subclass
class CTDICalculator_HA : public CTDICalculator
  {
protected:
   virtual void      CreateRSIEngine(void) override { m_rsi_engine = new CRSIEngine_HA(); }
  };
//+------------------------------------------------------------------+
