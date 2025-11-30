//+------------------------------------------------------------------+
//|                       Laguerre_Filter_Volatility_Calculator.mqh  |
//|    Calculation engine for Volatility-Adaptive Laguerre Filter.   |
//|    Based on MotiveWave documentation logic.                      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CLaguerreFilterVolatilityCalculator
  {
protected:
   int               m_period1; // Lookback for High/Low of Diff
   int               m_period2; // Lookback for Median of Alpha

   //--- Persistent Buffers
   double            m_price[];
   double            m_diff_buf[]; // Stores abs(price - prev_filter)
   double            m_mid_buf[];  // Stores normalized mid values

   //--- Laguerre State
   double            m_L0_buf[], m_L1_buf[], m_L2_buf[], m_L3_buf[];
   double            m_filter_buf[]; // Stores the final filter output

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Helpers
   double            GetHighest(const double &arr[], int start_idx, int len);
   double            GetLowest(const double &arr[], int start_idx, int len);
   double            GetMedian(const double &arr[], int start_idx, int len);

public:
                     CLaguerreFilterVolatilityCalculator(void) {};
   virtual          ~CLaguerreFilterVolatilityCalculator(void) {};

   bool              Init(int p1, int p2);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[]);
  };

//+------------------------------------------------------------------+
bool CLaguerreFilterVolatilityCalculator::Init(int p1, int p2)
  {
   m_period1 = (p1 < 1) ? 1 : p1;
   m_period2 = (p2 < 1) ? 1 : p2;
   return true;
  }

//+------------------------------------------------------------------+
void CLaguerreFilterVolatilityCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[])
  {
   int needed_history = MathMax(m_period1, m_period2) + 1;
   if(rates_total < needed_history)
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
      ArrayResize(m_diff_buf, rates_total);
      ArrayResize(m_mid_buf, rates_total);
      ArrayResize(m_L0_buf, rates_total);
      ArrayResize(m_L1_buf, rates_total);
      ArrayResize(m_L2_buf, rates_total);
      ArrayResize(m_L3_buf, rates_total);
      ArrayResize(m_filter_buf, rates_total);
     }

//--- 3. Prepare Price
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Main Loop
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
      m_filter_buf[0] = m_price[0];
      output_buffer[0] = m_price[0];
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      // --- Step A: Calculate Diff ---
      // diff = abs(price - prev_filter)
      double prev_F = m_filter_buf[i-1];
      m_diff_buf[i] = MathAbs(m_price[i] - prev_F);

      // --- Step B: Calculate Alpha (Gamma) ---
      double alpha = 0.5; // Default fallback

      if(i >= m_period1)
        {
         double hh = GetHighest(m_diff_buf, i, m_period1);
         double ll = GetLowest(m_diff_buf, i, m_period1);

         double mid = 0;
         if(hh - ll != 0)
            mid = (m_diff_buf[i] - ll) / (hh - ll);

         m_mid_buf[i] = mid;

         if(i >= m_period2)
           {
            alpha = GetMedian(m_mid_buf, i, m_period2);
           }
        }
      else
        {
         m_mid_buf[i] = 0;
        }

      // --- Step C: Laguerre Filter with dynamic Alpha ---
      double L0_prev = m_L0_buf[i-1];
      double L1_prev = m_L1_buf[i-1];
      double L2_prev = m_L2_buf[i-1];
      double L3_prev = m_L3_buf[i-1];

      m_L0_buf[i] = alpha * m_price[i] + (1 - alpha) * L0_prev;
      m_L1_buf[i] = -(1 - alpha) * m_L0_buf[i] + L0_prev + (1 - alpha) * L1_prev;
      m_L2_buf[i] = -(1 - alpha) * m_L1_buf[i] + L1_prev + (1 - alpha) * L2_prev;
      m_L3_buf[i] = -(1 - alpha) * m_L2_buf[i] + L2_prev + (1 - alpha) * L3_prev;

      double filt = (m_L0_buf[i] + 2.0 * m_L1_buf[i] + 2.0 * m_L2_buf[i] + m_L3_buf[i]) / 6.0;

      m_filter_buf[i] = filt;
      output_buffer[i] = filt;
     }
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double CLaguerreFilterVolatilityCalculator::GetHighest(const double &arr[], int start_idx, int len)
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
double CLaguerreFilterVolatilityCalculator::GetLowest(const double &arr[], int start_idx, int len)
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
double CLaguerreFilterVolatilityCalculator::GetMedian(const double &arr[], int start_idx, int len)
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
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CLaguerreFilterVolatilityCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
class CLaguerreFilterVolatilityCalculator_HA : public CLaguerreFilterVolatilityCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CLaguerreFilterVolatilityCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
