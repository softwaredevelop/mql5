//+------------------------------------------------------------------+
//|                                Laguerre_Adaptive_Score_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Refactored class names to eliminate redundant LScore references
#property description "Stateful calculator implementing Statistical Laguerre Z-Score with adaptive Gamma scaling."

#ifndef LAGUERRE_ADAPTIVE_SCORE_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_SCORE_CALCULATOR_MQH

#include <MyIncludes\EfficiencyRatio_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\Laguerre_Adaptive_Filter_Calculator.mqh> // Share adaptive enums

//+==================================================================+
//|             CLASS: CLaguerreAdaptiveScoreCalculator              |
//+==================================================================+
class CLaguerreAdaptiveScoreCalculator
  {
protected:
   ENUM_ADAPTIVE_METHOD        m_method;
   int                         m_adaptive_period;
   double                      m_gamma_min;
   double                      m_gamma_max;
   int                         m_sigma_period; // Volatility lookback period (N)
   bool                        m_is_ha;

   CEfficiencyRatioCalculator *m_er_calc;
   CATRCalculator             *m_atr_calc;

   //--- Persistent State Registers
   double                      m_price[];
   double                      m_L0[], m_L1[], m_L2[], m_L3[];
   double                      m_filter[];
   double                      m_adaptive_metric[];
   double                      m_temp_atr[];
   double                      m_temp_stdev[];

   bool                        PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);
   void                        NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[]);

public:
                     CLaguerreAdaptiveScoreCalculator(void);
   virtual                    ~CLaguerreAdaptiveScoreCalculator(void);

   bool                        Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, int sigma_period, bool is_ha);
   void                        Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                         const double &open[], const double &high[], const double &low[], const double &close[],
                                         double &score_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveScoreCalculator::CLaguerreAdaptiveScoreCalculator(void)
   : m_er_calc(NULL),
     m_atr_calc(NULL),
     m_is_ha(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveScoreCalculator::~CLaguerreAdaptiveScoreCalculator(void)
  {
   if(CheckPointer(m_er_calc) != POINTER_INVALID)
      delete m_er_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveScoreCalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, int sigma_period, bool is_ha)
  {
   m_method          = method;
   m_adaptive_period = (adaptive_period < 2) ? 2 : adaptive_period;
   m_gamma_min       = fmax(0.0, fmin(1.0, gamma_min));
   m_gamma_max       = fmax(0.0, fmin(1.0, gamma_max));
   m_sigma_period    = (sigma_period < 2) ? 2 : sigma_period;
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

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Stateful O(1) Z-Score calculation)                    |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveScoreCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &score_buffer[])
  {
   int min_warmup = MathMax(m_adaptive_period * 2, m_sigma_period) + 5;
   if(rates_total < min_warmup)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArrayResize(m_L0,              rates_total);
      ArrayResize(m_L1,              rates_total);
      ArrayResize(m_L2,              rates_total);
      ArrayResize(m_L3,              rates_total);
      ArrayResize(m_filter,          rates_total);
      ArrayResize(m_adaptive_metric, rates_total);

      ArraySetAsSeries(m_price,           false);
      ArraySetAsSeries(m_L0,              false);
      ArraySetAsSeries(m_L1,              false);
      ArraySetAsSeries(m_L2,              false);
      ArraySetAsSeries(m_L3,              false);
      ArraySetAsSeries(m_filter,          false);
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

//--- Stateful Adaptive Laguerre Baseline (Mean)
   if(start_index == 0)
     {
      m_L0[0] = m_price[0];
      m_L1[0] = m_price[0];
      m_L2[0] = m_price[0];
      m_L3[0] = m_price[0];
      m_filter[0] = m_price[0];
      score_buffer[0] = 0.0;
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

      m_filter[i] = (m_L0[i] + 2.0 * m_L1[i] + 2.0 * m_L2[i] + m_L3[i]) / 6.0;
     }

//--- Calculate Volatility Distance in Sigma Units (Adaptive Score)
   int sigma_start = (prev_calculated > 0) ? prev_calculated - 1 : m_sigma_period - 1;
   if(sigma_start < m_sigma_period - 1)
     {
      for(int i = 0; i < m_sigma_period - 1; i++)
         score_buffer[i] = 0.0;
      sigma_start = m_sigma_period - 1;
     }

   for(int i = sigma_start; i < rates_total; i++)
     {
      double sum_sq = 0.0;
      double current_mean = m_filter[i];

      // Standard deviation over N period relative to the dynamic adaptive mean
      for(int k = 0; k < m_sigma_period; k++)
        {
         double diff = m_price[i - k] - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev = sqrt(sum_sq / m_sigma_period);

      if(std_dev > 1.0e-9) // Protection against flat-market division-by-zero
         score_buffer[i] = (m_price[i] - current_mean) / std_dev;
      else
         score_buffer[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Sliding Min-Max Normalization (DRY Helper)                       |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveScoreCalculator::NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[])
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
bool CLaguerreAdaptiveScoreCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
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
//|             CLASS 2: CLaguerreAdaptiveScoreCalculator_HA        |
//+==================================================================+
class CLaguerreAdaptiveScoreCalculator_HA : public CLaguerreAdaptiveScoreCalculator
  {
public:
                     CLaguerreAdaptiveScoreCalculator_HA(void)
     {
      m_is_ha = true;
     };
  };

#endif // LAGUERRE_ADAPTIVE_SCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
