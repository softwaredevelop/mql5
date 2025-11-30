//+------------------------------------------------------------------+
//|                     Laguerre_RSI_Volatility_Calculator.mqh       |
//|    Calculation engine for Volatility-Adaptive Laguerre RSI.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CLaguerreRSIVolatilityCalculator
  {
protected:
   int               m_period1; // Lookback for High/Low of Diff
   int               m_period2; // Lookback for Median of Alpha

   int               m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Persistent Buffers for Volatility Logic
   double            m_price[];
   double            m_diff_buf[];
   double            m_mid_buf[];

   //--- Internal State Buffers for Laguerre RSI (L0..L3)
   // Note: We need separate buffers for the RSI calculation, distinct from the price filter
   double            m_L0_buf[], m_L1_buf[], m_L2_buf[], m_L3_buf[];

   //--- Helper buffer for previous filter value (needed for volatility calc)
   double            m_prev_filter_buf[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Helpers (Copied from Filter Calculator for independence)
   double            GetHighest(const double &arr[], int start_idx, int len);
   double            GetLowest(const double &arr[], int start_idx, int len);
   double            GetMedian(const double &arr[], int start_idx, int len);

public:
                     CLaguerreRSIVolatilityCalculator(void);
   virtual          ~CLaguerreRSIVolatilityCalculator(void);

   bool              Init(int p1, int p2, int sig_p, ENUM_MA_TYPE sig_type);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
CLaguerreRSIVolatilityCalculator::CLaguerreRSIVolatilityCalculator(void)
  {
   m_signal_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLaguerreRSIVolatilityCalculator::~CLaguerreRSIVolatilityCalculator(void)
  {
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLaguerreRSIVolatilityCalculator::Init(int p1, int p2, int sig_p, ENUM_MA_TYPE sig_type)
  {
   m_period1 = (p1 < 1) ? 1 : p1;
   m_period2 = (p2 < 1) ? 1 : p2;
   m_signal_period = (sig_p < 1) ? 1 : sig_p;
   m_signal_ma_type = sig_type;

   return m_signal_ma_engine.Init(m_signal_period, m_signal_ma_type);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLaguerreRSIVolatilityCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &lrsi_buffer[], double &signal_buffer[])
  {
   int needed_history = MathMax(m_period1, m_period2) + 1;
   if(rates_total < needed_history)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_diff_buf, rates_total);
      ArrayResize(m_mid_buf, rates_total);
      ArrayResize(m_L0_buf, rates_total);
      ArrayResize(m_L1_buf, rates_total);
      ArrayResize(m_L2_buf, rates_total);
      ArrayResize(m_L3_buf, rates_total);
      ArrayResize(m_prev_filter_buf, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int i = start_index;

// Initialization
   if(i == 0)
     {
      m_diff_buf[0] = 0;
      m_mid_buf[0] = 0;
      m_L0_buf[0] = m_price[0];
      m_L1_buf[0] = m_price[0];
      m_L2_buf[0] = m_price[0];
      m_L3_buf[0] = m_price[0];
      m_prev_filter_buf[0] = m_price[0]; // Used for volatility calc
      lrsi_buffer[0] = 50.0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      // --- 1. Calculate Volatility Alpha ---
      // We need a reference "filter" to calculate diff.
      // In the filter indicator, this is the filter itself.
      // Here, we maintain a parallel simple Laguerre filter just for alpha calculation.

      double prev_F = m_prev_filter_buf[i-1];
      m_diff_buf[i] = MathAbs(m_price[i] - prev_F);

      double alpha = 0.5;
      if(i >= m_period1)
        {
         double hh = GetHighest(m_diff_buf, i, m_period1);
         double ll = GetLowest(m_diff_buf, i, m_period1);
         double mid = (hh - ll != 0) ? (m_diff_buf[i] - ll) / (hh - ll) : 0;
         m_mid_buf[i] = mid;

         if(i >= m_period2)
            alpha = GetMedian(m_mid_buf, i, m_period2);
        }
      else
        {
         m_mid_buf[i] = 0;
        }

      // Update the reference filter for next bar's diff calculation
      // Using the calculated alpha
      // Simple 1-pole Laguerre for reference
      m_prev_filter_buf[i] = alpha * m_price[i] + (1 - alpha) * prev_F;


      // --- 2. Calculate Laguerre RSI Components ---
      double L0_prev = m_L0_buf[i-1];
      double L1_prev = m_L1_buf[i-1];
      double L2_prev = m_L2_buf[i-1];
      double L3_prev = m_L3_buf[i-1];

      m_L0_buf[i] = alpha * m_price[i] + (1 - alpha) * L0_prev;
      m_L1_buf[i] = -(1 - alpha) * m_L0_buf[i] + L0_prev + (1 - alpha) * L1_prev;
      m_L2_buf[i] = -(1 - alpha) * m_L1_buf[i] + L1_prev + (1 - alpha) * L2_prev;
      m_L3_buf[i] = -(1 - alpha) * m_L2_buf[i] + L2_prev + (1 - alpha) * L3_prev;

      // --- 3. Calculate RSI ---
      double cu = 0, cd = 0;
      if(m_L0_buf[i] >= m_L1_buf[i])
         cu = m_L0_buf[i] - m_L1_buf[i];
      else
         cd = m_L1_buf[i] - m_L0_buf[i];
      if(m_L1_buf[i] >= m_L2_buf[i])
         cu += m_L1_buf[i] - m_L2_buf[i];
      else
         cd += m_L2_buf[i] - m_L1_buf[i];
      if(m_L2_buf[i] >= m_L3_buf[i])
         cu += m_L2_buf[i] - m_L3_buf[i];
      else
         cd += m_L3_buf[i] - m_L2_buf[i];

      if(cu + cd > 0)
         lrsi_buffer[i] = 100.0 * cu / (cu + cd);
      else
         lrsi_buffer[i] = (i > 0) ? lrsi_buffer[i-1] : 50.0;
     }

// --- 4. Signal Line ---
   m_signal_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                lrsi_buffer, lrsi_buffer, lrsi_buffer, lrsi_buffer,
                                signal_buffer);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double CLaguerreRSIVolatilityCalculator::GetHighest(const double &arr[], int start_idx, int len)
  {
   double max_val = arr[start_idx];
   for(int k=1; k<len; k++)
      if(arr[start_idx-k] > max_val)
         max_val = arr[start_idx-k];
   return max_val;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLaguerreRSIVolatilityCalculator::GetLowest(const double &arr[], int start_idx, int len)
  {
   double min_val = arr[start_idx];
   for(int k=1; k<len; k++)
      if(arr[start_idx-k] < min_val)
         min_val = arr[start_idx-k];
   return min_val;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLaguerreRSIVolatilityCalculator::GetMedian(const double &arr[], int start_idx, int len)
  {
   double temp[];
   ArrayResize(temp, len);
   for(int k=0; k<len; k++)
      temp[k] = arr[start_idx-k];
   ArraySort(temp);
   if(len % 2 == 1)
      return temp[len/2];
   else
      return (temp[len/2 - 1] + temp[len/2]) / 2.0;
  }

//+------------------------------------------------------------------+
//| Prepare Price                                                    |
//+------------------------------------------------------------------+
bool CLaguerreRSIVolatilityCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: HA Version                                  |
//+==================================================================+
class CLaguerreRSIVolatilityCalculator_HA : public CLaguerreRSIVolatilityCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CLaguerreRSIVolatilityCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
