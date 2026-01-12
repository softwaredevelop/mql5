//+------------------------------------------------------------------+
//|                           Stochastic_Adaptive_RSI_Calculator.mqh |
//|      VERSION 4.00: Refactored to use RSI_Engine.                 |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for ER Source
enum ENUM_ADAPTIVE_SOURCE
  {
   ADAPTIVE_SOURCE_STANDARD,    // Calculate ER on Standard Price (Recommended)
   ADAPTIVE_SOURCE_HEIKIN_ASHI  // Calculate ER on Heikin Ashi Price
  };

//+==================================================================+
//|             CLASS 1: CStochasticAdaptiveRSICalculator            |
//+==================================================================+
class CStochasticAdaptiveRSICalculator
  {
protected:
   int               m_rsi_period, m_er_period, m_min_period, m_max_period;
   ENUM_ADAPTIVE_SOURCE m_adaptive_source;

   //--- Engines
   CRSIEngine        *m_rsi_engine;
   CMovingAverageCalculator m_slowing_engine;
   CMovingAverageCalculator m_signal_engine;

   //--- Persistent Buffers
   double            m_price[]; // Used for ER calculation
   double            m_rsi_buffer[];
   double            m_er_buffer[];
   double            m_nsp_buffer[];
   double            m_raw_k[];

   //--- Factory Method for RSI Engine
   virtual void      CreateRSIEngine(void);

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CStochasticAdaptiveRSICalculator(void);
   virtual          ~CStochasticAdaptiveRSICalculator(void);

   bool              Init(int rsi_p, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma, ENUM_ADAPTIVE_SOURCE adapt_src);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &k_buffer[], double &d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticAdaptiveRSICalculator::CStochasticAdaptiveRSICalculator(void)
  {
   m_rsi_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticAdaptiveRSICalculator::~CStochasticAdaptiveRSICalculator(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID)
      delete m_rsi_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CStochasticAdaptiveRSICalculator::CreateRSIEngine(void)
  {
   m_rsi_engine = new CRSIEngine();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveRSICalculator::Init(int rsi_p, int er_p, int min_p, int max_p, int slow_p, ENUM_MA_TYPE slow_ma, int d_p, ENUM_MA_TYPE d_ma, ENUM_ADAPTIVE_SOURCE adapt_src)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_er_period  = (er_p < 1) ? 1 : er_p;
   m_min_period = (min_p < 1) ? 1 : min_p;
   m_max_period = (max_p <= m_min_period) ? m_min_period + 1 : max_p;
   m_adaptive_source = adapt_src;

   CreateRSIEngine();

   if(CheckPointer(m_rsi_engine) == POINTER_INVALID)
      return false;

   if(!m_rsi_engine.Init(m_rsi_period))
      return false;

   if(!m_slowing_engine.Init(slow_p, slow_ma))
      return false;
   if(!m_signal_engine.Init(d_p, d_ma))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CStochasticAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &k_buffer[], double &d_buffer[])
  {
   if(rates_total <= m_rsi_period + m_er_period + m_max_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_rsi_buffer, rates_total);
      ArrayResize(m_er_buffer, rates_total);
      ArrayResize(m_nsp_buffer, rates_total);
      ArrayResize(m_raw_k, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate RSI (Using Engine)
// The engine handles its own data preparation internally!
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_rsi_buffer);

//--- 2. Calculate Efficiency Ratio (ER) on Price
   int loop_start_er = MathMax(m_er_period, start_index);

   for(int i = loop_start_er; i < rates_total; i++)
     {
      double direction = MathAbs(m_price[i] - m_price[i - m_er_period]);
      double volatility = 0;
      for(int j = 0; j < m_er_period; j++)
         volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);

      m_er_buffer[i] = (volatility > 0.000001) ? direction / volatility : 0;
     }

//--- 3. Calculate Adaptive Period (NSP)
   for(int i = loop_start_er; i < rates_total; i++)
     {
      m_nsp_buffer[i] = (int)(m_er_buffer[i] * (m_max_period - m_min_period) + m_min_period);
      if(m_nsp_buffer[i] < 1)
         m_nsp_buffer[i] = 1;
     }

//--- 4. Calculate Raw %K (Adaptive) on RSI
   int raw_k_start = MathMax(m_rsi_period, m_er_period) + m_max_period - 1;
   int loop_start_k = MathMax(raw_k_start, start_index);

   for(int i = loop_start_k; i < rates_total; i++)
     {
      int current_nsp = (int)m_nsp_buffer[i];
      double highest = m_rsi_buffer[i];
      double lowest = m_rsi_buffer[i];

      for(int j = 1; j < current_nsp; j++)
        {
         if(i-j < 0)
            break;
         highest = MathMax(highest, m_rsi_buffer[i-j]);
         lowest = MathMin(lowest, m_rsi_buffer[i-j]);
        }

      double range = highest - lowest;
      if(range > 0.00001)
         m_raw_k[i] = (m_rsi_buffer[i] - lowest) / range * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i-1] : 50.0;
     }

//--- 5. Calculate Slow %K (Main Line)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, k_buffer, raw_k_start);

//--- 6. Calculate %D (Signal Line)
   int d_offset = raw_k_start + m_slowing_engine.GetPeriod() - 1;
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, k_buffer, d_buffer, d_offset);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CStochasticAdaptiveRSICalculator_HA         |
//+==================================================================+
class CStochasticAdaptiveRSICalculator_HA : public CStochasticAdaptiveRSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual void      CreateRSIEngine(void) override;
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Factory Method (Heikin Ashi)                                     |
//+------------------------------------------------------------------+
void CStochasticAdaptiveRSICalculator_HA::CreateRSIEngine(void)
  {
   m_rsi_engine = new CRSIEngine_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CStochasticAdaptiveRSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

// We need HA candles for ER calculation if selected
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

   if(m_adaptive_source == ADAPTIVE_SOURCE_HEIKIN_ASHI)
     {
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
     }
   else // ADAPTIVE_SOURCE_STANDARD
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
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
