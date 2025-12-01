//+------------------------------------------------------------------+
//|                                               MACD_Calculator.mqh|
//|      VERSION 2.10: Reverted Signal Line to local calculation.    |
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

   //--- Parameters for Signal Line
   int               m_signal_period;
   ENUM_MA_METHOD    m_signal_ma_type;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_fast_ma[];
   double            m_slow_ma[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

   //--- Local Helper for Signal Line (Handles offset data correctly)
   void              CalculateSignalMA(const double &source[], double &dest[], int rates_total, int start_index, int period, ENUM_MA_METHOD method, int data_start_pos);

public:
                     CMACDCalculator(void);
   virtual          ~CMACDCalculator(void);

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma);

   //--- Updated: Accepts prev_calculated
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
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma)
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

   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = sig_ma;

// Initialize Engines
   if(!m_fast_ma_engine.Init(f_p, (ENUM_MA_TYPE)src_ma))
      return false;
   if(!m_slow_ma_engine.Init(s_p, (ENUM_MA_TYPE)src_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
   if(rates_total < 2)
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
// We pass PRICE_CLOSE because we already prepared m_price array with the correct price type!
// The engine will copy m_price to its internal buffer.
   m_fast_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_fast_ma);
   m_slow_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_slow_ma);

//--- 5. Calculate MACD Line
   int slow_period = m_slow_ma_engine.GetPeriod();
   int loop_start_macd = MathMax(slow_period - 1, start_index);

// Initialize buffer on full recalc
   if(prev_calculated == 0)
      ArrayInitialize(macd_line, EMPTY_VALUE);

   for(int i = loop_start_macd; i < rates_total; i++)
     {
      if(m_fast_ma[i] != EMPTY_VALUE && m_slow_ma[i] != EMPTY_VALUE)
         macd_line[i] = m_fast_ma[i] - m_slow_ma[i];
      else
         macd_line[i] = EMPTY_VALUE;
     }

//--- 6. Calculate Signal Line (Using Local Helper)
// The MACD line starts being valid at 'slow_period - 1'.
   if(prev_calculated == 0)
      ArrayInitialize(signal_line, EMPTY_VALUE);

   CalculateSignalMA(macd_line, signal_line, rates_total, start_index, m_signal_period, m_signal_ma_type, slow_period - 1);

//--- 7. Calculate Histogram
   int signal_start = slow_period - 1 + m_signal_period - 1;
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
//| Local Helper for Signal Line Calculation                         |
//+------------------------------------------------------------------+
void CMACDCalculator::CalculateSignalMA(const double &source[], double &dest[], int rates_total, int start_index, int period, ENUM_MA_METHOD method, int data_start_pos)
  {
// The actual calculation starts 'period' bars after the data starts
   int calc_start_pos = data_start_pos + period - 1;
   int i = MathMax(calc_start_pos, start_index);

   if(i >= rates_total)
      return;

   for(; i < rates_total; i++)
     {
      switch(method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == calc_start_pos)
              {
               double sum=0;
               for(int j=0; j<period; j++)
                  sum+=source[i-j];
               dest[i]=sum/period;
              }
            else
              {
               if(method==MODE_EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest[i]=source[i]*pr+dest[i-1]*(1.0-pr);
                 }
               else
                  dest[i]=(dest[i-1]*(period-1)+source[i])/period;
              }
            break;
         case MODE_LWMA:
           {
            double sum=0,w_sum=0;
            for(int j=0; j<period; j++)
              {
               int w=period-j;
               sum+=source[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            for(int j=0; j<period; j++)
               sum+=source[i-j];
            dest[i]=sum/period;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CMACDCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
// Optimized copy loop
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
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CMACDCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
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
