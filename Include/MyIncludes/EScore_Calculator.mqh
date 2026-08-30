//+------------------------------------------------------------------+
//|                                             EScore_Calculator.mqh|
//|      Engine for Statistical E-Score (Ehlers Smoother Z-Score)    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Fixed: Preserved Persistent Smoother History on Resize

#ifndef ESCORE_CALCULATOR_MQH
#define ESCORE_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
//|             CLASS: CEScoreCalculator                             |
//+==================================================================+
class CEScoreCalculator
  {
private:
   int                        m_period;
   ENUM_SMOOTHER_TYPE         m_type;
   ENUM_APPLIED_PRICE_HA_ALL  m_source_price;

   CEhlersSmootherCalculator *m_smoother_calc;
   CHeikinAshi_Calculator     m_ha_calc;

   double                     m_smooth_buf[];
   double                     m_price_buf[];
   double                     m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                       PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CEScoreCalculator(void);
                    ~CEScoreCalculator(void);

   //--- Legacy Compatible Init (3 Parameters)
   bool                       Init(const int period, const ENUM_SMOOTHER_TYPE type, const bool use_ha)
     {
      ENUM_APPLIED_PRICE_HA_ALL src = use_ha ? PRICE_HA_CLOSE : PRICE_CLOSE_STD;
      return Init(period, type, src);
     }

   //--- Enhanced Pro Init (3 Parameters with Full Price Enum)
   bool                       Init(const int period, const ENUM_SMOOTHER_TYPE type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                       Calculate(const int rates_total, const int prev_calculated,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &out_escore[]);

   //--- Legacy Overload with price_type parameter
   void                       Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &out_escore[])
     {
      Calculate(rates_total, prev_calculated, open, high, low, close, out_escore);
     }

   int                        GetRequiredWarmup(void) const { return m_period + 3; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEScoreCalculator::CEScoreCalculator(void) : m_period(20),
   m_type(SUPERSMOOTHER),
   m_source_price(PRICE_CLOSE_STD),
   m_smoother_calc(NULL)
  {
   ArraySetAsSeries(m_smooth_buf, false);
   ArraySetAsSeries(m_price_buf,  false);
   ArraySetAsSeries(m_ha_open,    false);
   ArraySetAsSeries(m_ha_high,    false);
   ArraySetAsSeries(m_ha_low,     false);
   ArraySetAsSeries(m_ha_close,   false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEScoreCalculator::~CEScoreCalculator(void)
  {
   if(CheckPointer(m_smoother_calc) != POINTER_INVALID)
     {
      delete m_smoother_calc;
      m_smoother_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CEScoreCalculator::Init(const int period, const ENUM_SMOOTHER_TYPE type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period       = (period < 2) ? 2 : period;
   m_type         = type;
   m_source_price = price_source;

   if(CheckPointer(m_smoother_calc) != POINTER_INVALID)
     {
      delete m_smoother_calc;
      m_smoother_calc = NULL;
     }

   m_smoother_calc = new CEhlersSmootherCalculator();
   if(CheckPointer(m_smoother_calc) == POINTER_INVALID)
      return false;

   return m_smoother_calc.Init(m_period, m_type, SOURCE_PRICE, m_source_price);
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CEScoreCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price_buf) != rates_total)
     {
      ArrayResize(m_price_buf, rates_total);
      ArraySetAsSeries(m_price_buf, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);

         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_calc.Calculate(rates_total, start_index, open, high, low, close,
                          m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_HA_OPEN:
               m_price_buf[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price_buf[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price_buf[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_HA_TYPICAL:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price_buf[i] = m_ha_close[i];
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
               m_price_buf[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price_buf[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price_buf[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price_buf[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL_STD:
               m_price_buf[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price_buf[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price_buf[i] = close[i];
               break;
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CEScoreCalculator::Calculate(const int rates_total, const int prev_calculated,
                                  const double &open[], const double &high[],
                                  const double &low[], const double &close[],
                                  double &out_escore[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_smoother_calc) == POINTER_INVALID)
      return;

// Safe allocation of destination array without wiping history
   if(ArraySize(out_escore) != rates_total)
     {
      ArrayResize(out_escore, rates_total);
      ArraySetAsSeries(out_escore, false);
     }

// Safe allocation of internal smoother buffer (Preserves historical elements)
   if(ArraySize(m_smooth_buf) != rates_total)
     {
      ArrayResize(m_smooth_buf, rates_total);
      ArraySetAsSeries(m_smooth_buf, false);
     }

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

// 1. Prepare Price Data
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 2. Compute Underlying Ehlers Smoother
   m_smoother_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_smooth_buf);

// 3. Clean invalid initial range strictly on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
         out_escore[i] = 0.0;
     }

   int start = (prev_calculated > warmup) ? (prev_calculated - 1) : warmup;
   if(start < warmup)
      start = warmup;

// 4. Compute Rolling Z-Score of difference (m_price_buf - m_smooth_buf)
   for(int i = start; i < rates_total; i++)
     {
      double current_smooth = m_smooth_buf[i];
      double p = m_price_buf[i];

      if(current_smooth == 0.0 || current_smooth == EMPTY_VALUE)
        {
         out_escore[i] = 0.0;
         continue;
        }

      double sum_sq_diff = 0.0;
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p_k = m_price_buf[idx];
         double s_k = m_smooth_buf[idx];

         if(s_k == 0.0 || s_k == EMPTY_VALUE)
            s_k = p_k;

         double diff = p_k - s_k;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / (double)m_period);

      if(std_dev > 1.0e-9)
         out_escore[i] = (p - current_smooth) / std_dev;
      else
         out_escore[i] = 0.0;
     }
  }

#endif // ESCORE_CALCULATOR_MQH
//+------------------------------------------------------------------+
