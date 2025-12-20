//+------------------------------------------------------------------+
//|                                               MACD_Calculator.mqh|
//|      VERSION 3.00: Uses MovingAverage_Engine for all lines.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CMACDCalculator (Base Class)                |
//+==================================================================+
class CMACDCalculator
  {
protected:
   //--- Engines for MACD Line
   CMovingAverageCalculator *m_fast_ma_engine;
   CMovingAverageCalculator *m_slow_ma_engine;
   //--- Engine for Signal Line
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_fast_ma[];
   double            m_slow_ma[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CMACDCalculator(void);
   virtual          ~CMACDCalculator(void);

   //--- Init now takes ENUM_MA_TYPE for all MAs
   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_MA_TYPE src_ma, ENUM_MA_TYPE sig_ma);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDCalculator::CMACDCalculator(void)
  {
   m_fast_ma_engine = new CMovingAverageCalculator();
   m_slow_ma_engine = new CMovingAverageCalculator();
   m_signal_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDCalculator::~CMACDCalculator(void)
  {
   if(CheckPointer(m_fast_ma_engine) != POINTER_INVALID)
      delete m_fast_ma_engine;
   if(CheckPointer(m_slow_ma_engine) != POINTER_INVALID)
      delete m_slow_ma_engine;
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_MA_TYPE src_ma, ENUM_MA_TYPE sig_ma)
  {
// Ensure fast < slow
   int f_p = (fast_p < 1) ? 1 : fast_p;
   int s_p = (slow_p < 1) ? 1 : slow_p;
   if(f_p > s_p)
     {
      int temp=f_p;
      f_p=s_p;
      s_p=temp;
     }

   int sig_p = (signal_p < 1) ? 1 : signal_p;

// Initialize Engines
   if(!m_fast_ma_engine.Init(f_p, src_ma))
      return false;
   if(!m_slow_ma_engine.Init(s_p, src_ma))
      return false;
   if(!m_signal_ma_engine.Init(sig_p, sig_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
// Minimum bars check
   int min_bars = m_slow_ma_engine.GetPeriod() + m_signal_ma_engine.GetPeriod();
   if(rates_total <= min_bars)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_fast_ma, rates_total);
      ArrayResize(m_slow_ma, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close, price_type))
      return;

//--- 4. Calculate Fast & Slow MAs (Delegated to Engine)
   m_fast_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_fast_ma);
   m_slow_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_slow_ma);

//--- 5. Calculate MACD Line
   int slow_period = m_slow_ma_engine.GetPeriod();
   int loop_start_macd = MathMax(slow_period - 1, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(macd_line, EMPTY_VALUE);

   for(int i = loop_start_macd; i < rates_total; i++)
     {
      if(m_fast_ma[i] != EMPTY_VALUE && m_slow_ma[i] != EMPTY_VALUE)
         macd_line[i] = m_fast_ma[i] - m_slow_ma[i];
      else
         macd_line[i] = EMPTY_VALUE;
     }

//--- 6. Calculate Signal Line (Using MA Engine)
// The MACD line starts being valid at 'slow_period - 1'.
// This is the offset we pass to the Signal Engine.
   int macd_offset = slow_period - 1;

   if(prev_calculated == 0)
      ArrayInitialize(signal_line, EMPTY_VALUE);

   m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, macd_line, signal_line, macd_offset);

//--- 7. Calculate Histogram
   int signal_period = m_signal_ma_engine.GetPeriod();
   int signal_start = macd_offset + signal_period - 1;
   int loop_start_hist = MathMax(signal_start, start_index);

   if(prev_calculated == 0)
      ArrayInitialize(histogram, EMPTY_VALUE);

   for(int i = loop_start_hist; i < rates_total; i++)
     {
      if(macd_line[i] != EMPTY_VALUE && signal_line[i] != EMPTY_VALUE)
         histogram[i] = macd_line[i] - signal_line[i];
      else
         histogram[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CMACDCalculator_HA (Heikin Ashi)            |
//+==================================================================+
class CMACDCalculator_HA : public CMACDCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMACDCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
