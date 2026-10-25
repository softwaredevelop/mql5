//+------------------------------------------------------------------+
//|                               ChaosWeightedRSI_Calculator.mqh   |
//|      Engine for Fractal-Chaos-Weighted Relative Strength Index   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.30" // Enterprise: Integrated Central CFractalEngine Architecture
#property description "Mathematical engine for Chaos-Weighted RSI utilizing unified CFractalEngine."

#ifndef CHAOS_WEIGHTED_RSI_CALCULATOR_MQH
#define CHAOS_WEIGHTED_RSI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\Fractal_Engine.mqh>

//+==================================================================+
//|             CLASS: CChaosWeightedRSI_Calculator                  |
//+==================================================================+
class CChaosWeightedRSI_Calculator
  {
private:
   int                       m_rsi_period;
   int                       m_fdi_period;
   double                    m_sensitivity;
   ENUM_APPLIED_PRICE_HA_ALL m_source_type;
   double                    m_base_alpha;

   // Embedded Central DSP Engines
   CFractalEngine            m_fractal_engine;
   CHeikinAshi_Calculator    m_ha_engine;

   // Persistent Buffers
   double                    m_price[];
   double                    m_avg_gain[];
   double                    m_avg_loss[];
   double                    m_wrsi[];

   // Heikin Ashi Buffers
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                      PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CChaosWeightedRSI_Calculator(void);
                    ~CChaosWeightedRSI_Calculator(void);

   bool                      Init(const int rsi_period, const int fdi_period,
                                  const double sensitivity, const ENUM_APPLIED_PRICE_HA_ALL source);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_wrsi[], const int history_limit = 0);

   double                    GetWRSI(const int index) const;
   int                       GetWarmupBars(void) const { return MathMax(m_rsi_period, m_fdi_period) + 2; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CChaosWeightedRSI_Calculator::CChaosWeightedRSI_Calculator(void) :
   m_rsi_period(14),
   m_fdi_period(20),
   m_sensitivity(1.0),
   m_source_type(PRICE_CLOSE_STD),
   m_base_alpha(0.07142857)
  {
   ArraySetAsSeries(m_price,     false);
   ArraySetAsSeries(m_avg_gain,  false);
   ArraySetAsSeries(m_avg_loss,  false);
   ArraySetAsSeries(m_wrsi,      false);
   ArraySetAsSeries(m_ha_open,   false);
   ArraySetAsSeries(m_ha_high,   false);
   ArraySetAsSeries(m_ha_low,    false);
   ArraySetAsSeries(m_ha_close,  false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CChaosWeightedRSI_Calculator::~CChaosWeightedRSI_Calculator(void)
  {
   ArrayFree(m_price);
   ArrayFree(m_avg_gain);
   ArrayFree(m_avg_loss);
   ArrayFree(m_wrsi);
   ArrayFree(m_ha_open);
   ArrayFree(m_ha_high);
   ArrayFree(m_ha_low);
   ArrayFree(m_ha_close);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CChaosWeightedRSI_Calculator::Init(const int rsi_period, const int fdi_period,
                                        const double sensitivity, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_rsi_period    = (rsi_period < 2) ? 2 : rsi_period;
   m_fdi_period    = (fdi_period < 5) ? 5 : fdi_period;
   m_sensitivity   = (sensitivity <= 0.0) ? 1.0 : sensitivity;
   m_source_type   = source;
   m_base_alpha    = 1.0 / (double)m_rsi_period;

// Initialize Embedded Central Fractal Engine
   if(!m_fractal_engine.Init(m_fdi_period, FDI_CANONICAL_SEVCIK))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series                                             |
//+------------------------------------------------------------------+
bool CChaosWeightedRSI_Calculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   bool is_ha = (m_source_type <= PRICE_HA_CLOSE);

   if(is_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total, 2048);
         ArrayResize(m_ha_high,  rates_total, 2048);
         ArrayResize(m_ha_low,   rates_total, 2048);
         ArrayResize(m_ha_close, rates_total, 2048);
         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_type)
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
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.333333333333;
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
         switch(m_source_type)
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
               m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
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

//+------------------------------------------------------------------+
//| Main Incremental Calculation Engine                              |
//+------------------------------------------------------------------+
void CChaosWeightedRSI_Calculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_wrsi[], const int history_limit)
  {
   int warmup = GetWarmupBars();
   if(rates_total < warmup)
      return;

   if(ArraySize(out_wrsi) != rates_total)
     {
      ArrayResize(out_wrsi, rates_total, 2048);
      ArraySetAsSeries(out_wrsi, false);
     }

// Safe state allocation preserving recursive memory
   if(ArraySize(m_avg_gain) != rates_total)
     {
      int old_sz = ArraySize(m_avg_gain);
      ArrayResize(m_avg_gain, rates_total, 2048);
      ArrayResize(m_avg_loss, rates_total, 2048);
      ArrayResize(m_wrsi,     rates_total, 2048);
      ArraySetAsSeries(m_avg_gain, false);
      ArraySetAsSeries(m_avg_loss, false);
      ArraySetAsSeries(m_wrsi,     false);

      if(old_sz == 0 || prev_calculated == 0)
        {
         ArrayInitialize(m_avg_gain, EMPTY_VALUE);
         ArrayInitialize(m_avg_loss, EMPTY_VALUE);
         ArrayInitialize(m_wrsi,     50.0);
        }
      else
        {
         for(int k = old_sz; k < rates_total; k++)
           {
            m_avg_gain[k] = EMPTY_VALUE;
            m_avg_loss[k] = EMPTY_VALUE;
            m_wrsi[k]     = 50.0;
           }
        }
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PreparePriceSeries(rates_total, start_prep, open, high, low, close))
      return;

   int start = (prev_calculated > 0) ? (prev_calculated - 1) : 1;
   int actual_start = 1;

   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start)
        {
         start = limit_start;
         actual_start = limit_start;
        }
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start; i++)
        {
         out_wrsi[i]   = 50.0;
         m_avg_gain[i] = EMPTY_VALUE;
         m_avg_loss[i] = EMPTY_VALUE;
         m_wrsi[i]     = 50.0;
        }
     }

   for(int i = start; i < rates_total; i++)
     {
      // Calculate Chaos directly via Central Fractal Engine
      double chaos = m_fractal_engine.CalculateChaosPoint(i, m_fdi_period, m_price);

      // Adaptive smoothing modulation
      double adjusted_alpha = m_base_alpha * MathPow(1.0 - chaos, m_sensitivity);
      adjusted_alpha = MathMax(0.001, MathMin(1.0, adjusted_alpha));

      double change = m_price[i] - m_price[i - 1];
      double gain   = MathMax(change, 0.0);
      double loss   = MathMax(-change, 0.0);

      if(i == actual_start || m_avg_gain[i - 1] == EMPTY_VALUE || m_avg_loss[i - 1] == EMPTY_VALUE)
        {
         m_avg_gain[i] = gain;
         m_avg_loss[i] = loss;
        }
      else
        {
         m_avg_gain[i] = m_avg_gain[i - 1] + adjusted_alpha * (gain - m_avg_gain[i - 1]);
         m_avg_loss[i] = m_avg_loss[i - 1] + adjusted_alpha * (loss - m_avg_loss[i - 1]);
        }

      if(m_avg_loss[i] <= 1.0e-12)
        {
         out_wrsi[i] = 100.0;
        }
      else
        {
         double rs = m_avg_gain[i] / m_avg_loss[i];
         out_wrsi[i] = 100.0 - (100.0 / (1.0 + rs));
        }

      m_wrsi[i] = out_wrsi[i];
     }
  }

//+------------------------------------------------------------------+
//| Accessor                                                         |
//+------------------------------------------------------------------+
double CChaosWeightedRSI_Calculator::GetWRSI(const int index) const
  {
   if(index >= 0 && index < ArraySize(m_wrsi))
      return m_wrsi[index];
   return 50.0;
  }

#endif // CHAOS_WEIGHTED_RSI_CALCULATOR_MQH
//+------------------------------------------------------------------+
