//+------------------------------------------------------------------+
//|                             Ehlers_Adaptive_Channel_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.00" // Adaptive Ehlers Smoother Channel Engine via ATR/StDev
#property description "Stateful calculator implementing volatility channels around Adaptive Ehlers Smoother baseline."

#ifndef EHLERS_ADAPTIVE_CHANNEL_CALCULATOR_MQH
#define EHLERS_ADAPTIVE_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Adaptive_Smoother_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Dedicated Channel Volatility Width enum
#ifndef ENUM_CHANNEL_WIDTH_METHOD_DEFINED
#define ENUM_CHANNEL_WIDTH_METHOD_DEFINED
enum ENUM_CHANNEL_WIDTH_METHOD
  {
   WIDTH_METHOD_ATR,              // Average True Range (ATR Keltner-style)
   WIDTH_METHOD_STAND_DEV         // Standard Deviation (StDev Bollinger-style)
  };
#endif

//+==================================================================+
//|             CLASS: CEhlersAdaptiveChannelCalculator              |
//+==================================================================+
class CEhlersAdaptiveChannelCalculator
  {
private:
   ENUM_CHANNEL_WIDTH_METHOD          m_width_method;
   int                                m_width_period;
   double                             m_inv_width_period; // Precalculated 1.0 / width_period
   double                             m_multiplier;
   bool                               m_is_ha;

   CEhlersAdaptiveSmootherCalculator *m_baseline_calc;
   CATRCalculator                    *m_atr_calc;
   CHeikinAshi_Calculator             m_ha_engine;

   //--- Persistent State Registers (Strict Instance Isolation)
   double                             m_baseline_buffer[];
   double                             m_vol_buffer[];
   double                             m_price[];
   double                             m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                               PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEhlersAdaptiveChannelCalculator(void);
                    ~CEhlersAdaptiveChannelCalculator(void);

   bool                               Init(const ENUM_SMOOTHER_TYPE smoother_type,
                                           const ENUM_ADAPTIVE_METHOD method,
                                           const int adaptive_period,
                                           const int period_min,
                                           const int period_max,
                                           const ENUM_CHANNEL_WIDTH_METHOD width_method,
                                           const int width_period,
                                           const double multiplier,
                                           const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                               Calculate(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &baseline_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersAdaptiveChannelCalculator::CEhlersAdaptiveChannelCalculator(void) :
   m_width_method(WIDTH_METHOD_ATR),
   m_width_period(10),
   m_inv_width_period(0.1),
   m_multiplier(2.0),
   m_is_ha(false),
   m_baseline_calc(NULL),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_baseline_buffer, false);
   ArraySetAsSeries(m_vol_buffer,      false);
   ArraySetAsSeries(m_price,           false);
   ArraySetAsSeries(m_ha_open,         false);
   ArraySetAsSeries(m_ha_high,         false);
   ArraySetAsSeries(m_ha_low,          false);
   ArraySetAsSeries(m_ha_close,        false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEhlersAdaptiveChannelCalculator::~CEhlersAdaptiveChannelCalculator(void)
  {
   if(CheckPointer(m_baseline_calc) != POINTER_INVALID)
     {
      delete m_baseline_calc;
      m_baseline_calc = NULL;
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
bool CEhlersAdaptiveChannelCalculator::Init(const ENUM_SMOOTHER_TYPE smoother_type,
      const ENUM_ADAPTIVE_METHOD method,
      const int adaptive_period,
      const int period_min,
      const int period_max,
      const ENUM_CHANNEL_WIDTH_METHOD width_method,
      const int width_period,
      const double multiplier,
      const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_width_method     = width_method;
   m_width_period     = (width_period < 2) ? 2 : width_period;
   m_inv_width_period = 1.0 / (double)m_width_period;
   m_multiplier       = (multiplier <= 0.0) ? 1.0 : multiplier;
   m_is_ha            = (price_source <= PRICE_HA_CLOSE);

   if(CheckPointer(m_baseline_calc) != POINTER_INVALID)
     {
      delete m_baseline_calc;
      m_baseline_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

// 1. Instantiate Adaptive Ehlers Baseline Engine
   m_baseline_calc = new CEhlersAdaptiveSmootherCalculator();
   if(CheckPointer(m_baseline_calc) == POINTER_INVALID ||
      !m_baseline_calc.Init(smoother_type, method, adaptive_period, period_min, period_max, price_source))
      return false;

// 2. Instantiate ATR Engine if selected
   if(m_width_method == WIDTH_METHOD_ATR)
     {
      if(m_is_ha)
         m_atr_calc = new CATRCalculator_HA();
      else
         m_atr_calc = new CATRCalculator();

      if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_width_period, ATR_POINTS))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate Channel Envelopes                                      |
//+------------------------------------------------------------------+
void CEhlersAdaptiveChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &baseline_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int required_bars = MathMax(m_width_period * 2, 20) + 5;
   if(rates_total < required_bars || CheckPointer(m_baseline_calc) == POINTER_INVALID)
      return;

// Safe allocation of internal state buffers
   if(ArraySize(m_baseline_buffer) != rates_total)
     {
      ArrayResize(m_baseline_buffer, rates_total);
      ArraySetAsSeries(m_baseline_buffer, false);
      ArrayResize(m_vol_buffer,      rates_total);
      ArraySetAsSeries(m_vol_buffer,      false);
      ArrayResize(m_price,           rates_total);
      ArraySetAsSeries(m_price,           false);
     }

// 1. Calculate Adaptive Ehlers Baseline Centerline in O(1)
   m_baseline_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_baseline_buffer);

// 2. Calculate Channel Volatility Width (ATR or Accelerated Standard Deviation)
   if(m_width_method == WIDTH_METHOD_ATR)
     {
      if(CheckPointer(m_atr_calc) != POINTER_INVALID)
         m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_vol_buffer);
     }
   else // WIDTH_METHOD_STAND_DEV (MathPow-Free Accelerated StDev)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      ENUM_APPLIED_PRICE p_type = (m_is_ha) ? PRICE_CLOSE : PRICE_CLOSE;
      if(!PreparePriceSeries(rates_total, start_index, p_type, open, high, low, close))
         return;

      int loop_start = MathMax(m_width_period - 1, start_index);
      if(loop_start == m_width_period - 1)
        {
         for(int i = 0; i < loop_start; i++)
            m_vol_buffer[i] = 0.0;
        }

      for(int i = loop_start; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_width_period; j++)
            sum += m_price[i - j];
         double mean = sum * m_inv_width_period;

         // Fast scalar multiplication instead of slow pow()
         double sum_sq = 0.0;
         for(int j = 0; j < m_width_period; j++)
           {
            double diff = m_price[i - j] - mean;
            sum_sq += diff * diff;
           }

         m_vol_buffer[i] = MathSqrt(sum_sq * m_inv_width_period);
        }
     }

// 3. Fused Pipelined Band Projection around Baseline
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
     {
      double base  = m_baseline_buffer[i];
      double width = m_multiplier * m_vol_buffer[i];

      baseline_buffer[i] = base;
      upper_buffer[i]    = base + width;
      lower_buffer[i]    = base - width;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Instance Isolated Caches - Zero Static!)   |
//+------------------------------------------------------------------+
bool CEhlersAdaptiveChannelCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
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

#endif // EHLERS_ADAPTIVE_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
