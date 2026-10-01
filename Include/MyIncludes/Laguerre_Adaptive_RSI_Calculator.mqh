//+------------------------------------------------------------------+
//|                                Laguerre_Adaptive_RSI_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.10" // Enterprise Refactor: Embedded Member Engines, Direct Squaring & Precomputed Gamma
#property description "Stateful calculator implementing John Ehlers' Laguerre RSI with adaptive Gamma scaling."

#ifndef LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH

#include <MyIncludes\EfficiencyRatio_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

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
//|             CLASS: CLaguerreAdaptiveRSICalculator                |
//+==================================================================+
class CLaguerreAdaptiveRSICalculator
  {
protected:
   ENUM_ADAPTIVE_METHOD        m_method;
   int                         m_adaptive_period;
   double                      m_gamma_min;
   double                      m_gamma_max;
   double                      m_gamma_range; // Precalculated (gamma_max - gamma_min)
   bool                        m_is_ha;

   int                         m_signal_period;
   ENUM_MA_TYPE                m_signal_ma_type;

   CEfficiencyRatioCalculator *m_er_calc;
   CATRCalculator             *m_atr_calc;
   CMovingAverageCalculator    m_ma_calc;   // Embedded member object (Zero pointer overhead!)
   CHeikinAshi_Calculator      m_ha_engine;

   //--- Persistent State Registers (Strict Instance Isolation - Zero Static Sharing!)
   double                      m_price[];
   double                      m_L0[], m_L1[], m_L2[], m_L3[];
   double                      m_adaptive_metric[];
   double                      m_temp_atr[];
   double                      m_temp_stdev[];
   double                      m_d_vol[];
   double                      m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                        PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);
   void                        NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[]);

public:
                     CLaguerreAdaptiveRSICalculator(void);
   virtual                    ~CLaguerreAdaptiveRSICalculator(void);

   bool                        Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, int signal_p, ENUM_MA_TYPE signal_ma, bool is_ha);

   //--- Standard Calculate (Without volume data)
   void                        Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                         const double &open[], const double &high[], const double &low[], const double &close[],
                                         double &lrsi_buffer[], double &signal_buffer[]);

   //--- Overloaded Calculate (With Persistent Volume for VWMA support)
   void                        Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                         const double &open[], const double &high[], const double &low[], const double &close[],
                                         const long &volume[],
                                         double &lrsi_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveRSICalculator::CLaguerreAdaptiveRSICalculator(void) :
   m_method(METHOD_EFFICIENCY_RATIO),
   m_adaptive_period(10),
   m_gamma_min(0.136),
   m_gamma_max(0.882),
   m_gamma_range(0.746),
   m_is_ha(false),
   m_signal_period(3),
   m_signal_ma_type(EMA),
   m_er_calc(NULL),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_price,           false);
   ArraySetAsSeries(m_L0,              false);
   ArraySetAsSeries(m_L1,              false);
   ArraySetAsSeries(m_L2,              false);
   ArraySetAsSeries(m_L3,              false);
   ArraySetAsSeries(m_adaptive_metric, false);
   ArraySetAsSeries(m_temp_atr,        false);
   ArraySetAsSeries(m_temp_stdev,      false);
   ArraySetAsSeries(m_d_vol,           false);
   ArraySetAsSeries(m_ha_open,         false);
   ArraySetAsSeries(m_ha_high,         false);
   ArraySetAsSeries(m_ha_low,          false);
   ArraySetAsSeries(m_ha_close,        false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveRSICalculator::~CLaguerreAdaptiveRSICalculator(void)
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
//| Init                                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveRSICalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max, int signal_p, ENUM_MA_TYPE signal_ma, bool is_ha)
  {
   m_method          = method;
   m_adaptive_period = (adaptive_period < 2) ? 2 : adaptive_period;
   m_gamma_min       = fmax(0.0, fmin(1.0, gamma_min));
   m_gamma_max       = fmax(0.0, fmin(1.0, gamma_max));

   if(m_gamma_min > m_gamma_max)
     {
      double tmp = m_gamma_min;
      m_gamma_min = m_gamma_max;
      m_gamma_max = tmp;
     }

   m_gamma_range     = m_gamma_max - m_gamma_min; // Precalculated differential constant
   m_is_ha           = is_ha;
   m_signal_period   = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type  = signal_ma;

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

   if(!m_ma_calc.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &lrsi_buffer[], double &signal_buffer[])
  {
   int required_bars = m_adaptive_period * 2 + 5;
   if(rates_total < required_bars)
      return;

// Safe allocation of internal state arrays
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArraySetAsSeries(m_price,           false);
      ArrayResize(m_L0,              rates_total);
      ArraySetAsSeries(m_L0,              false);
      ArrayResize(m_L1,              rates_total);
      ArraySetAsSeries(m_L1,              false);
      ArrayResize(m_L2,              rates_total);
      ArraySetAsSeries(m_L2,              false);
      ArrayResize(m_L3,              rates_total);
      ArraySetAsSeries(m_L3,              false);
      ArrayResize(m_adaptive_metric, rates_total);
      ArraySetAsSeries(m_adaptive_metric, false);
     }

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 1. Calculate Adaptive Metric [0.0 to 1.0]
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

            // Fast scalar multiplication instead of slow pow()
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

// 2. Stateful Adaptive Laguerre RSI States
   int i = start_index;

   if(i == 0)
     {
      double p0 = m_price[0];
      m_L0[0] = p0;
      m_L1[0] = p0;
      m_L2[0] = p0;
      m_L3[0] = p0;
      lrsi_buffer[0] = 50.0;
      i = 1;
     }

   for(; i < rates_total; i++)
     {
      double metric = m_adaptive_metric[i];
      if(metric < 0.0)
         metric = 0.0;
      else
         if(metric > 1.0)
            metric = 1.0;

      double gamma = m_gamma_max - metric * m_gamma_range;
      if(gamma < 0.0)
         gamma = 0.0;
      else
         if(gamma > 1.0)
            gamma = 1.0;

      double one_minus_gamma = 1.0 - gamma;
      double neg_gamma       = -gamma;

      double L0_prev = m_L0[i - 1];
      double L1_prev = m_L1[i - 1];
      double L2_prev = m_L2[i - 1];
      double L3_prev = m_L3[i - 1];

      m_L0[i] = one_minus_gamma * m_price[i] + gamma * L0_prev;
      m_L1[i] = neg_gamma * m_L0[i] + L0_prev + gamma * L1_prev;
      m_L2[i] = neg_gamma * m_L1[i] + L1_prev + gamma * L2_prev;
      m_L3[i] = neg_gamma * m_L2[i] + L2_prev + gamma * L3_prev;

      // LRSI Difference components
      double cu = 0.0, cd = 0.0;
      if(m_L0[i] >= m_L1[i])
         cu += m_L0[i] - m_L1[i];
      else
         cd += m_L1[i] - m_L0[i];
      if(m_L1[i] >= m_L2[i])
         cu += m_L1[i] - m_L2[i];
      else
         cd += m_L2[i] - m_L1[i];
      if(m_L2[i] >= m_L3[i])
         cu += m_L2[i] - m_L3[i];
      else
         cd += m_L3[i] - m_L2[i];

      double sum_c = cu + cd;
      double lrsi_value = (sum_c > 1.0e-9) ? (100.0 * cu / sum_c) : ((i > 0) ? lrsi_buffer[i - 1] : 50.0);

      lrsi_buffer[i] = fmax(0.0, fmin(100.0, lrsi_value));
     }

// 3. Calculate Signal Line (Incremental O(1))
   m_ma_calc.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, signal_buffer, m_adaptive_period);
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Persistent Volume for VWMA)         |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveRSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &lrsi_buffer[], double &signal_buffer[])
  {
   int required_bars = m_adaptive_period * 2 + 5;
   if(rates_total < required_bars)
      return;

// Safe allocation of persistent volume buffer (Zero dynamic heap reallocations!)
   if(ArraySize(m_d_vol) != rates_total)
     {
      ArrayResize(m_d_vol, rates_total);
      ArraySetAsSeries(m_d_vol, false);
     }

   int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start_sync; i < rates_total; i++)
      m_d_vol[i] = (double)volume[i];

// 1. Run Standard Calculation to obtain base lrsi_buffer
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, lrsi_buffer, signal_buffer);

// 2. Overwrite Signal Line calculation using Persistent Volume
   m_ma_calc.CalculateOnArray(rates_total, prev_calculated, lrsi_buffer, m_d_vol, signal_buffer, m_adaptive_period);
  }

//+------------------------------------------------------------------+
//| Sliding Min-Max Normalization (DRY Helper)                       |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveRSICalculator::NormalizeMetric(int rates_total, int prev_calculated, const double &src_array[])
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
bool CLaguerreAdaptiveRSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
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
         switch(price_type)
           {
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
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
               break;
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
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
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
//|             CLASS 2: CLaguerreAdaptiveRSICalculator_HA           |
//+==================================================================+
class CLaguerreAdaptiveRSICalculator_HA : public CLaguerreAdaptiveRSICalculator
  {
public:
                     CLaguerreAdaptiveRSICalculator_HA(void)
     {
      m_is_ha = true;
     };
  };

#endif // LAGUERRE_ADAPTIVE_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
