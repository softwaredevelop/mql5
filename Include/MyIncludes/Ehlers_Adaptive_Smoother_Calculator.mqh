//+------------------------------------------------------------------+
//|                             Ehlers_Adaptive_Smoother_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.00" // Adaptive SuperSmoother & UltimateSmoother Engine via ER/ATR/StDev
#property description "Stateful calculator implementing adaptive Ehlers smoothing via dynamic cutoff period scaling."

#ifndef EHLERS_ADAPTIVE_SMOOTHER_CALCULATOR_MQH
#define EHLERS_ADAPTIVE_SMOOTHER_CALCULATOR_MQH

#include <MyIncludes\EfficiencyRatio_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\Ehlers_Smoother_Calculator.mqh> // Share smoother enums

#ifndef ENUM_ADAPTIVE_METHOD_DEFINED
#define ENUM_ADAPTIVE_METHOD_DEFINED
enum ENUM_ADAPTIVE_METHOD
  {
   METHOD_EFFICIENCY_RATIO, // Kaufman's Efficiency Ratio (ER)
   METHOD_ATR,              // Average True Range (ATR Volatility)
   METHOD_STAND_DEV         // Standard Deviation (StDev Volatility)
  };
#endif

//+==================================================================+
//|             CLASS: CEhlersAdaptiveSmootherCalculator             |
//+==================================================================+
class CEhlersAdaptiveSmootherCalculator
  {
private:
   ENUM_SMOOTHER_TYPE          m_smoother_type;
   ENUM_ADAPTIVE_METHOD        m_method;
   int                         m_adaptive_period;
   int                         m_period_min;
   int                         m_period_max;
   int                         m_period_range; // Precalculated (period_max - period_min)
   ENUM_APPLIED_PRICE_HA_ALL   m_source_price;
   bool                        m_is_ha;

   CEfficiencyRatioCalculator *m_er_calc;
   CATRCalculator             *m_atr_calc;
   CHeikinAshi_Calculator      m_ha_engine;

   //--- Persistent State Registers (Strict Instance Isolation)
   double                      m_price[];
   double                      m_adaptive_metric[];
   double                      m_temp_atr[];
   double                      m_temp_stdev[];
   double                      m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                        PreparePriceSeries(int rates_total, int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

   void                        NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[]);

public:
                     CEhlersAdaptiveSmootherCalculator(void);
                    ~CEhlersAdaptiveSmootherCalculator(void);

   bool                        Init(const ENUM_SMOOTHER_TYPE smoother_type,
                                    const ENUM_ADAPTIVE_METHOD method,
                                    const int adaptive_period,
                                    const int period_min,
                                    const int period_max,
                                    const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                        Calculate(const int rates_total, const int prev_calculated,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[],
                                         double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersAdaptiveSmootherCalculator::CEhlersAdaptiveSmootherCalculator(void) :
   m_smoother_type(SUPERSMOOTHER),
   m_method(METHOD_EFFICIENCY_RATIO),
   m_adaptive_period(10),
   m_period_min(5),
   m_period_max(30),
   m_period_range(25),
   m_source_price(PRICE_CLOSE_STD),
   m_is_ha(false),
   m_er_calc(NULL),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_price,           false);
   ArraySetAsSeries(m_adaptive_metric, false);
   ArraySetAsSeries(m_temp_atr,        false);
   ArraySetAsSeries(m_temp_stdev,      false);
   ArraySetAsSeries(m_ha_open,         false);
   ArraySetAsSeries(m_ha_high,         false);
   ArraySetAsSeries(m_ha_low,          false);
   ArraySetAsSeries(m_ha_close,        false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEhlersAdaptiveSmootherCalculator::~CEhlersAdaptiveSmootherCalculator(void)
  {
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
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CEhlersAdaptiveSmootherCalculator::Init(const ENUM_SMOOTHER_TYPE smoother_type,
      const ENUM_ADAPTIVE_METHOD method,
      const int adaptive_period,
      const int period_min,
      const int period_max,
      const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_smoother_type   = smoother_type;
   m_method          = method;
   m_adaptive_period = (adaptive_period < 2) ? 2 : adaptive_period;
   m_period_min      = (period_min < 2) ? 2 : period_min;
   m_period_max      = (period_max < m_period_min) ? (m_period_min + 1) : period_max;
   m_period_range    = m_period_max - m_period_min;
   m_source_price    = price_source;
   m_is_ha           = (m_source_price <= PRICE_HA_CLOSE);

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

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Loop (Incremental O(1))                         |
//+------------------------------------------------------------------+
void CEhlersAdaptiveSmootherCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &filter_buffer[])
  {
   int required_bars = m_adaptive_period * 2 + 5;
   if(rates_total < required_bars)
      return;

// Safe array sizing
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArraySetAsSeries(m_price,           false);
      ArrayResize(m_adaptive_metric, rates_total);
      ArraySetAsSeries(m_adaptive_metric, false);
     }
   if(ArraySize(filter_buffer) != rates_total)
     {
      ArrayResize(filter_buffer, rates_total);
      ArraySetAsSeries(filter_buffer, false);
     }

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Adaptive Metric [0.0 to 1.0]
   if(m_method == METHOD_EFFICIENCY_RATIO)
     {
      ENUM_APPLIED_PRICE p_type = (m_source_price <= PRICE_HA_CLOSE) ? PRICE_CLOSE : (ENUM_APPLIED_PRICE)m_source_price;
      m_er_calc.Calculate(rates_total, prev_calculated, p_type, open, high, low, close, m_adaptive_metric);
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
      else // METHOD_STAND_DEV (MathPow-Free Accelerated StDev)
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

         double inv_p = 1.0 / (double)m_adaptive_period;

         for(int i = loop_start; i < rates_total; i++)
           {
            double sum = 0.0;
            for(int j = 0; j < m_adaptive_period; j++)
               sum += m_price[i - j];
            double mean = sum * inv_p;

            double sum_sq = 0.0;
            for(int j = 0; j < m_adaptive_period; j++)
              {
               double diff = m_price[i - j] - mean;
               sum_sq += diff * diff;
              }

            m_temp_stdev[i] = MathSqrt(sum_sq * inv_p);
           }
         NormalizeMetric(rates_total, prev_calculated, m_temp_stdev);
        }

// 2. Deterministic Seeding on Initial Pass
   int loop_start_filter = MathMax(3, start_index);

   if(prev_calculated == 0)
     {
      filter_buffer[0] = m_price[0];
      filter_buffer[1] = m_price[1];
      filter_buffer[2] = m_price[2];
      loop_start_filter = 3;
     }

// 3. Dynamic Adaptive 2-Pole Difference Equation
   for(int i = loop_start_filter; i < rates_total; i++)
     {
      double metric = m_adaptive_metric[i];
      if(metric < 0.0)
         metric = 0.0;
      else
         if(metric > 1.0)
            metric = 1.0;

      // Higher metric (high efficiency/volatility) -> shorter period (faster tracking)
      double dyn_period = (double)m_period_max - (metric * (double)m_period_range);
      if(dyn_period < (double)m_period_min)
         dyn_period = (double)m_period_min;
      if(dyn_period > (double)m_period_max)
         dyn_period = (double)m_period_max;

      // Solve 2-Pole Butterworth Transfer Function for the dynamic period
      double omega = M_SQRT2 * M_PI / dyn_period;
      double a1    = MathExp(-omega);
      double b1    = 2.0 * a1 * MathCos(omega);
      double c2    = b1;
      double c3    = -a1 * a1;

      double f1 = filter_buffer[i - 1];
      double f2 = filter_buffer[i - 2];

      if(m_smoother_type == SUPERSMOOTHER)
        {
         double c1_half = (1.0 - c2 - c3) * 0.5;
         filter_buffer[i] = c1_half * (m_price[i] + m_price[i - 1]) + c2 * f1 + c3 * f2;
        }
      else // ULTIMATESMOOTHER
        {
         double c1 = (1.0 + c2 - c3) * 0.25;
         double u0 = 1.0 - c1;
         double u1 = 2.0 * c1 - c2;
         double u2 = -(c1 + c3);

         filter_buffer[i] = u0 * m_price[i] + u1 * m_price[i - 1] + u2 * m_price[i - 2] + c2 * f1 + c3 * f2;
        }
     }
  }

//+------------------------------------------------------------------+
//| Sliding Min-Max Normalization (DRY Helper)                       |
//+------------------------------------------------------------------+
void CEhlersAdaptiveSmootherCalculator::NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[])
  {
   int start_sync   = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   int min_lookback = m_adaptive_period;
   int loop_start   = MathMax(min_lookback * 2, start_sync);

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
//| Prepare Price Series (Instance Isolated Caches - Zero Static!)   |
//+------------------------------------------------------------------+
bool CEhlersAdaptiveSmootherCalculator::PreparePriceSeries(int rates_total, int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(m_is_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArraySetAsSeries(m_ha_open,  false);
         ArrayResize(m_ha_high,  rates_total);
         ArraySetAsSeries(m_ha_high,  false);
         ArrayResize(m_ha_low,   rates_total);
         ArraySetAsSeries(m_ha_low,   false);
         ArrayResize(m_ha_close, rates_total);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_HA_OPEN:
               m_price[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price[i] = m_ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_OPEN_STD:
               m_price[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price[i] = (high[i] + low[i]) * 0.5;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price[i] = close[i];
               break;
           }
        }
     }

   return true;
  }

#endif // EHLERS_ADAPTIVE_SMOOTHER_CALCULATOR_MQH
//+------------------------------------------------------------------+
