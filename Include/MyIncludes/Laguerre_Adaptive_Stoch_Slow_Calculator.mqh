//+------------------------------------------------------------------+
//|                         Laguerre_Adaptive_Stoch_Slow_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Adaptive Laguerre Stochastic Slow calculation engine
#property description "Stateful calculator implementing Laguerre Stochastic Slow with adaptive Gamma scaling."

#ifndef LAGUERRE_ADAPTIVE_STOCH_SLOW_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_STOCH_SLOW_CALCULATOR_MQH

#include <MyIncludes\EfficiencyRatio_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\Laguerre_Adaptive_Filter_Calculator.mqh> // Share adaptive enums

//+==================================================================+
//|             CLASS: CLaguerreAdaptiveStochSlowCalculator          |
//+==================================================================+
class CLaguerreAdaptiveStochSlowCalculator
  {
protected:
   ENUM_ADAPTIVE_METHOD        m_method;
   int                         m_adaptive_period;
   double                      m_gamma_min;
   double                      m_gamma_max;
   bool                        m_is_ha;

   int                         m_slowing_period;
   ENUM_MA_TYPE                m_slowing_method;
   int                         m_signal_period;
   ENUM_MA_TYPE                m_signal_method;

   CEfficiencyRatioCalculator *m_er_calc;
   CATRCalculator             *m_atr_calc;
   CMovingAverageCalculator   *m_slowing_engine;
   CMovingAverageCalculator   *m_signal_engine;

   //--- Persistent State Registers
   double                      m_price[];
   double                      m_L0[], m_L1[], m_L2[], m_L3[];
   double                      m_raw_k[];
   double                      m_adaptive_metric[];
   double                      m_temp_atr[];
   double                      m_temp_stdev[];

   bool                        PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);
   void                        NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[]);

public:
                     CLaguerreAdaptiveStochSlowCalculator(void);
   virtual                    ~CLaguerreAdaptiveStochSlowCalculator(void);

   bool                        Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
                                    int slowing_p, ENUM_MA_TYPE slowing_m, int signal_p, ENUM_MA_TYPE signal_m, bool is_ha);

   //--- Standard Calculate (Without volume data)
   void                        Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                         const double &open[], const double &high[], const double &low[], const double &close[],
                                         double &slow_k_buffer[], double &signal_d_buffer[]);

   //--- Overloaded Calculate (With Volume for VWMA support)
   void                        Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                         const double &open[], const double &high[], const double &low[], const double &close[],
                                         const long &volume[],
                                         double &slow_k_buffer[], double &signal_d_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveStochSlowCalculator::CLaguerreAdaptiveStochSlowCalculator(void)
   : m_er_calc(NULL),
     m_atr_calc(NULL),
     m_slowing_engine(NULL),
     m_signal_engine(NULL),
     m_is_ha(false)
  {
   m_slowing_engine = new CMovingAverageCalculator();
   m_signal_engine  = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveStochSlowCalculator::~CLaguerreAdaptiveStochSlowCalculator(void)
  {
   if(CheckPointer(m_er_calc) != POINTER_INVALID)
      delete m_er_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
   if(CheckPointer(m_slowing_engine) != POINTER_INVALID)
      delete m_slowing_engine;
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveStochSlowCalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
      int slowing_p, ENUM_MA_TYPE slowing_m, int signal_p, ENUM_MA_TYPE signal_m, bool is_ha)
  {
   m_method          = method;
   m_adaptive_period = (adaptive_period < 2) ? 2 : adaptive_period;
   m_gamma_min       = fmax(0.0, fmin(1.0, gamma_min));
   m_gamma_max       = fmax(0.0, fmin(1.0, gamma_max));
   m_slowing_period  = (slowing_p < 1) ? 1 : slowing_p;
   m_slowing_method  = slowing_m;
   m_signal_period   = (signal_p < 1) ? 1 : signal_p;
   m_signal_method   = signal_m;
   m_is_ha           = is_ha;

   if(CheckPointer(m_er_calc) != POINTER_INVALID)
     {
      delete m_er_calc;
      m_er_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(m_method == METHOD_EFFICIENCY_RATIO)
     {
      m_er_calc = new CEfficiencyRatioCalculator();
      if(CheckPointer(m_er_calc) == POINTER_INVALID || !m_er_calc.Init(m_adaptive_period))
         return false;
     }
   else
      if(m_method == METHOD_ATR)
        {
         if(m_is_ha)
            m_atr_calc = new CATRCalculator_HA();
         else
            m_atr_calc = new CATRCalculator();

         if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_adaptive_period, ATR_POINTS))
            return false;
        }

   if(!m_slowing_engine.Init(m_slowing_period, m_slowing_method))
      return false;

   if(!m_signal_engine.Init(m_signal_period, m_signal_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveStochSlowCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   int required_bars = m_adaptive_period * 2 + m_slowing_period + m_signal_period + 5;
   if(rates_total < required_bars)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArrayResize(m_L0,              rates_total);
      ArrayResize(m_L1,              rates_total);
      ArrayResize(m_L2,              rates_total);
      ArrayResize(m_L3,              rates_total);
      ArrayResize(m_raw_k,           rates_total);
      ArrayResize(m_adaptive_metric, rates_total);

      ArraySetAsSeries(m_price,           false);
      ArraySetAsSeries(m_L0,              false);
      ArraySetAsSeries(m_L1,              false);
      ArraySetAsSeries(m_L2,              false);
      ArraySetAsSeries(m_L3,              false);
      ArraySetAsSeries(m_raw_k,           false);
      ArraySetAsSeries(m_adaptive_metric, false);
     }

//--- Prepare prices and calculate metrics
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   if(m_method == METHOD_EFFICIENCY_RATIO)
     {
      m_er_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_adaptive_metric);
     }
   else
      if(m_method == METHOD_ATR)
        {
         if(ArraySize(m_temp_atr) != rates_total)
           {
            ArrayResize(m_temp_atr, rates_total);
            ArraySetAsSeries(m_temp_atr, false);
           }
         m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_temp_atr);
         NormalizeMetric(rates_total, prev_calculated, m_temp_atr);
        }
      else // METHOD_STAND_DEV
        {
         if(ArraySize(m_temp_stdev) != rates_total)
           {
            ArrayResize(m_temp_stdev, rates_total);
            ArraySetAsSeries(m_temp_stdev, false);
           }

         int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
         int loop_start = MathMax(m_adaptive_period - 1, start_sync);

         if(loop_start == m_adaptive_period - 1)
           {
            for(int i = 0; i < loop_start; i++)
               m_temp_stdev[i] = 0.0;
           }

         for(int i = loop_start; i < rates_total; i++)
           {
            double sum = 0.0;
            for(int j = 0; j < m_adaptive_period; j++)
               sum += m_price[i - j];
            double mean = sum / m_adaptive_period;

            double sum_sq = 0.0;
            for(int j = 0; j < m_adaptive_period; j++)
               sum_sq += pow(m_price[i - j] - mean, 2);

            m_temp_stdev[i] = sqrt(sum_sq / m_adaptive_period);
           }
         NormalizeMetric(rates_total, prev_calculated, m_temp_stdev);
        }

//--- Stateful Adaptive Laguerre States
   if(start_index == 0)
     {
      m_L0[0] = m_price[0];
      m_L1[0] = m_price[0];
      m_L2[0] = m_price[0];
      m_L3[0] = m_price[0];
      m_raw_k[0] = 50.0;
      start_index = 1;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      double metric = m_adaptive_metric[i];
      metric = fmax(0.0, fmin(1.0, metric));

      double gamma = m_gamma_max - metric * (m_gamma_max - m_gamma_min);
      gamma = fmax(0.0, fmin(1.0, gamma));

      m_L0[i] = (1.0 - gamma) * m_price[i] + gamma * m_L0[i - 1];
      m_L1[i] = -gamma * m_L0[i] + m_L0[i - 1] + gamma * m_L1[i - 1];
      m_L2[i] = -gamma * m_L1[i] + m_L1[i - 1] + gamma * m_L2[i - 1];
      m_L3[i] = -gamma * m_L2[i] + m_L2[i - 1] + gamma * m_L3[i - 1];

      // Calculate Stochastic raw %K based on adaptive registers
      double hh = MathMax(MathMax(m_L0[i], m_L1[i]), MathMax(m_L2[i], m_L3[i]));
      double ll = MathMin(MathMin(m_L0[i], m_L1[i]), MathMin(m_L2[i], m_L3[i]));

      double diff = hh - ll;
      if(diff > 0.0)
         m_raw_k[i] = ((m_L0[i] - ll) / diff) * 100.0;
      else
         m_raw_k[i] = (i > 0) ? m_raw_k[i - 1] : 50.0;
     }

//--- Calculate Slow %K (Slowing of Raw %K)
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, slow_k_buffer);

//--- Calculate Signal %D (Smoothing of Slow %K)
   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, signal_d_buffer, signal_offset);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Volume for VWMA)                    |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveStochSlowCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &slow_k_buffer[], double &signal_d_buffer[])
  {
   int required_bars = m_adaptive_period * 2 + m_slowing_period + m_signal_period + 5;
   if(rates_total < required_bars)
      return;

//--- Convert volume locally for VWMA
   double d_vol[];
   ArrayResize(d_vol, rates_total);
   ArraySetAsSeries(d_vol, false);
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_sync; i < rates_total; i++)
      d_vol[i] = (double)volume[i];

//--- Calculate standard to obtain internal raw K buffer
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, slow_k_buffer, signal_d_buffer);

//--- Overwrite Slow %K & Signal %D with Volume-weighted averages
   m_slowing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_k, d_vol, slow_k_buffer);

   int signal_offset = m_slowing_engine.GetPeriod();
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, slow_k_buffer, d_vol, signal_d_buffer, signal_offset);
  }

//+------------------------------------------------------------------+
//| Sliding Min-Max Normalization (DRY Helper)                       |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveStochSlowCalculator::NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[])
  {
   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int min_lookback = m_adaptive_period;
   int loop_start = MathMax(min_lookback * 2, start_sync);

   if(loop_start == min_lookback * 2)
     {
      for(int i = 0; i < loop_start; i++)
         m_adaptive_metric[i] = 0.0;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      double min_val = src_array[i];
      double max_val = src_array[i];
      for(int j = 1; j < m_adaptive_period; j++)
        {
         double val = src_array[i - j];
         if(val < min_val)
            min_val = val;
         if(val > max_val)
            max_val = val;
        }
      double diff = max_val - min_val;
      if(diff > 1.0e-9)
         m_adaptive_metric[i] = (src_array[i] - min_val) / diff;
      else
         m_adaptive_metric[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveStochSlowCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(m_is_ha)
     {
      static CHeikinAshi_Calculator ha_calc;
      static double ha_open[], ha_high[], ha_low[], ha_close[];
      if(ArraySize(ha_open) != rates_total)
        {
         ArrayResize(ha_open,  rates_total);
         ArrayResize(ha_high,  rates_total);
         ArrayResize(ha_low,   rates_total);
         ArrayResize(ha_close, rates_total);
         ArraySetAsSeries(ha_open,  false);
         ArraySetAsSeries(ha_high,  false);
         ArraySetAsSeries(ha_low,   false);
         ArraySetAsSeries(ha_close, false);
        }

      ha_calc.Calculate(rates_total, start_index, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(price_type)
           {
            case PRICE_OPEN:
               m_price[i] = ha_open[i];
               break;
            case PRICE_HIGH:
               m_price[i] = ha_high[i];
               break;
            case PRICE_LOW:
               m_price[i] = ha_low[i];
               break;
            case PRICE_MEDIAN:
               m_price[i] = (ha_high[i] + ha_low[i]) * 0.5;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i] * 2.0) * 0.25;
               break;
            default:
               m_price[i] = ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(price_type)
           {
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
               m_price[i] = (high[i] + low[i]) * 0.5;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (high[i] + low[i] + close[i] * 2.0) * 0.25;
               break;
            default:
               m_price[i] = close[i];
               break;
           }
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CLaguerreAdaptiveStochSlowCalculator_HA     |
//+==================================================================+
class CLaguerreAdaptiveStochSlowCalculator_HA : public CLaguerreAdaptiveStochSlowCalculator
  {
public:
                     CLaguerreAdaptiveStochSlowCalculator_HA(void)
     {
      m_is_ha = true;
     };
  };

#endif // LAGUERRE_ADAPTIVE_STOCH_SLOW_CALCULATOR_MQH
//+------------------------------------------------------------------+
