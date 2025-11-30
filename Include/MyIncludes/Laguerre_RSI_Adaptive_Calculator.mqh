//+------------------------------------------------------------------+
//|                         Laguerre_RSI_Adaptive_Calculator.mqh     |
//|    VERSION 1.20: Optimized for incremental calculation.          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
class CLaguerreRSIAdaptiveCalculator
  {
protected:
   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];

   //--- Internal State Buffers for Homodyne Discriminator
   double            m_filt_buf[];
   double            m_I1_buf[], m_Q1_buf[];
   double            m_I2_buf[], m_Q2_buf[];
   double            m_Re_buf[], m_Im_buf[];
   double            m_Period_buf[];
   double            m_DC_Period_buf[];

   //--- Internal State Buffers for Laguerre RSI
   double            m_L0_buf[], m_L1_buf[], m_L2_buf[], m_L3_buf[];

   int               m_signal_period;
   ENUM_MA_TYPE      m_signal_ma_type;

   //--- Engine for Signal Line
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreRSIAdaptiveCalculator(void);
   virtual          ~CLaguerreRSIAdaptiveCalculator(void);

   bool              Init(int signal_p, ENUM_MA_TYPE signal_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreRSIAdaptiveCalculator::CLaguerreRSIAdaptiveCalculator(void)
  {
   m_signal_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreRSIAdaptiveCalculator::~CLaguerreRSIAdaptiveCalculator(void)
  {
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
      delete m_signal_ma_engine;
// Arrays are freed automatically
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator::Init(int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;

   if(!m_signal_ma_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CLaguerreRSIAdaptiveCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &lrsi_buffer[], double &signal_buffer[])
  {
   if(rates_total < 10)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Internal Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_filt_buf, rates_total);
      ArrayResize(m_I1_buf, rates_total);
      ArrayResize(m_Q1_buf, rates_total);
      ArrayResize(m_I2_buf, rates_total);
      ArrayResize(m_Q2_buf, rates_total);
      ArrayResize(m_Re_buf, rates_total);
      ArrayResize(m_Im_buf, rates_total);
      ArrayResize(m_Period_buf, rates_total);
      ArrayResize(m_DC_Period_buf, rates_total);
      ArrayResize(m_L0_buf, rates_total);
      ArrayResize(m_L1_buf, rates_total);
      ArrayResize(m_L2_buf, rates_total);
      ArrayResize(m_L3_buf, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Constants
   double alpha1 = (cos(0.707 * 2 * M_PI / 48.0) + sin(0.707 * 2 * M_PI / 48.0) - 1.0) / cos(0.707 * 2 * M_PI / 48.0);
   double beta1 = 1.0 - alpha1 / 2.0;
   beta1 *= beta1;

//--- 4. Main Loop (Incremental)
   int i = start_index;

// Initialization
   if(i < 7)
     {
      for(int k=0; k<7; k++)
        {
         if(k >= rates_total)
            break;
         m_filt_buf[k] = 0;
         m_I1_buf[k] = 0;
         m_Q1_buf[k] = 0;
         m_I2_buf[k] = 0;
         m_Q2_buf[k] = 0;
         m_Re_buf[k] = 0;
         m_Im_buf[k] = 0;
         m_Period_buf[k] = 0;
         m_DC_Period_buf[k] = 0;
         m_L0_buf[k] = m_price[k];
         m_L1_buf[k] = m_price[k];
         m_L2_buf[k] = m_price[k];
         m_L3_buf[k] = m_price[k];
         lrsi_buffer[k] = 50.0;
        }
      i = 7;
     }

   for(; i < rates_total; i++)
     {
      // --- Homodyne Discriminator Logic ---
      m_filt_buf[i] = beta1 * (m_price[i] - 2 * m_price[i-1] + m_price[i-2]) +
                      (2 * (1 - alpha1 / 2.0)) * m_filt_buf[i-1] -
                      ((1 - alpha1 / 2.0) * (1 - alpha1 / 2.0)) * m_filt_buf[i-2];

      m_Q1_buf[i] = (0.0962 * m_filt_buf[i] + 0.5769 * m_filt_buf[i-2] - 0.5769 * m_filt_buf[i-4] - 0.0962 * m_filt_buf[i-6]) *
                    (0.5 + 0.08 * (m_I1_buf[i-1] + 50));
      m_I1_buf[i] = m_filt_buf[i-3];

      m_I2_buf[i] = m_I1_buf[i] - m_Q1_buf[i-1];
      m_Q2_buf[i] = m_Q1_buf[i] + m_I1_buf[i-1];

      m_Re_buf[i] = m_I2_buf[i] * m_I2_buf[i-1] + m_Q2_buf[i] * m_Q2_buf[i-1];
      m_Im_buf[i] = m_I2_buf[i] * m_Q2_buf[i-1] - m_Q2_buf[i] * m_I2_buf[i-1];

      m_Re_buf[i] = 0.2 * m_Re_buf[i] + 0.8 * m_Re_buf[i-1];
      m_Im_buf[i] = 0.2 * m_Im_buf[i] + 0.8 * m_Im_buf[i-1];

      double Period = 0;
      if(m_Im_buf[i] != 0.0 && m_Re_buf[i] != 0.0)
         Period = 2 * M_PI / atan(m_Im_buf[i] / m_Re_buf[i]);

      if(Period > 1.5 * m_Period_buf[i-1])
         Period = 1.5 * m_Period_buf[i-1];
      if(Period < 0.67 * m_Period_buf[i-1])
         Period = 0.67 * m_Period_buf[i-1];
      if(Period < 6)
         Period = 6;
      if(Period > 50)
         Period = 50;

      m_Period_buf[i] = 0.2 * Period + 0.8 * m_Period_buf[i-1];
      m_DC_Period_buf[i] = 0.33 * Period + 0.67 * m_DC_Period_buf[i-1];

      double gamma = 0.0;
      if(m_DC_Period_buf[i] > 0)
         gamma = 4.0 / m_DC_Period_buf[i];

      // --- Laguerre RSI Logic ---
      double L0_prev = m_L0_buf[i-1];
      double L1_prev = m_L1_buf[i-1];
      double L2_prev = m_L2_buf[i-1];
      double L3_prev = m_L3_buf[i-1];

      m_L0_buf[i] = (1.0 - gamma) * m_price[i] + gamma * L0_prev;
      m_L1_buf[i] = -gamma * m_L0_buf[i] + L0_prev + gamma * L1_prev;
      m_L2_buf[i] = -gamma * m_L1_buf[i] + L1_prev + gamma * L2_prev;
      m_L3_buf[i] = -gamma * m_L2_buf[i] + L2_prev + gamma * L3_prev;

      double cu = 0.0, cd = 0.0;
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

      double lrsi_value;
      if(cu + cd > 0.0)
         lrsi_value = 100.0 * cu / (cu + cd);
      else
         lrsi_value = (i > 0) ? lrsi_buffer[i-1] : 50.0;

      if(lrsi_value > 100.0)
         lrsi_value = 100.0;
      if(lrsi_value < 0.0)
         lrsi_value = 0.0;

      lrsi_buffer[i] = lrsi_value;
     }

//--- 5. Calculate Signal Line (Using Optimized Engine)
   m_signal_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                lrsi_buffer, lrsi_buffer, lrsi_buffer, lrsi_buffer,
                                signal_buffer);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CLaguerreRSIAdaptiveCalculator_HA           |
//+==================================================================+
class CLaguerreRSIAdaptiveCalculator_HA : public CLaguerreRSIAdaptiveCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CLaguerreRSIAdaptiveCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
