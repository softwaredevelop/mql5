//+------------------------------------------------------------------+
//|                                    Ehlers_Bands_Calculator.mqh   |
//|      DSP Engine for John Ehlers' Volatility Envelopes            |
//|      VERSION 3.00: Clean-Slate Architecture (No Legacy Cruft)    |
//|                    Supports RMS Tracking Residual & Classic StDev|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00"

#ifndef EHLERS_BANDS_CALCULATOR_MQH
#define EHLERS_BANDS_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Ehlers Bands Dispersion Mode Enum
#ifndef ENUM_EHLERS_BANDS_MODE_DEFINED
#define ENUM_EHLERS_BANDS_MODE_DEFINED
enum ENUM_EHLERS_BANDS_MODE
  {
   BANDS_RMS_RESIDUAL,    // Ehlers RMS Tracking Residual (Tight in smooth trends)
   BANDS_CLASSIC_STDEV    // Classical Standard Deviation around Current Filter
  };
#endif

//+==================================================================+
//| CLASS: CEhlersBandsCalculator (Clean-Slate Unified Engine)       |
//+==================================================================+
class CEhlersBandsCalculator
  {
protected:
   int                       m_smooth_period;
   int                       m_band_period;
   double                    m_inv_band_period;
   double                    m_multiplier;
   ENUM_SMOOTHER_TYPE        m_smoother_type;
   ENUM_EHLERS_BANDS_MODE    m_bands_mode;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Embedded Stack Composition Engines (Zero Pointer Overhead)
   CEhlersSmootherCalculator m_calc_center;
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                      PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CEhlersBandsCalculator(void);
                    ~CEhlersBandsCalculator(void) {}

   bool                      Init(const int smooth_period,
                                  const int band_period,
                                  const double multiplier,
                                  const ENUM_SMOOTHER_TYPE smoother_type,
                                  const ENUM_EHLERS_BANDS_MODE bands_mode,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);

   void                      GetPriceBuffer(double &dest_array[]) const;

   int                       GetSmoothPeriod(void)  const { return m_smooth_period; }
   int                       GetBandPeriod(void)    const { return m_band_period; }
   double                    GetMultiplier(void)    const { return m_multiplier; }
   ENUM_SMOOTHER_TYPE        GetSmootherType(void)  const { return m_smoother_type; }
   ENUM_EHLERS_BANDS_MODE    GetBandsMode(void)     const { return m_bands_mode; }
   int                       GetWarmupBars(void)    const { return MathMax(m_smooth_period, m_band_period); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersBandsCalculator::CEhlersBandsCalculator(void) : m_smooth_period(20),
   m_band_period(20),
   m_inv_band_period(1.0 / 20.0),
   m_multiplier(2.0),
   m_smoother_type(SUPERSMOOTHER),
   m_bands_mode(BANDS_RMS_RESIDUAL),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Clean-Slate Unified Initialization                               |
//+------------------------------------------------------------------+
bool CEhlersBandsCalculator::Init(const int smooth_period,
                                  const int band_period,
                                  const double multiplier,
                                  const ENUM_SMOOTHER_TYPE smoother_type,
                                  const ENUM_EHLERS_BANDS_MODE bands_mode,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_smooth_period   = MathMax(2, smooth_period);
   m_band_period     = MathMax(2, band_period);
   m_inv_band_period = 1.0 / (double)m_band_period;
   m_multiplier      = (multiplier <= 0.0) ? 2.0 : multiplier;
   m_smoother_type   = smoother_type;
   m_bands_mode      = bands_mode;
   m_source_price    = price_source;

// Centerline smoother operates strictly on single-pass prepared m_price[]
   return m_calc_center.Init(m_smooth_period, m_smoother_type, SOURCE_PRICE, PRICE_CLOSE_STD);
  }

//+------------------------------------------------------------------+
//| Single-Pass Price Series Preparation (Standard / Heikin Ashi)    |
//+------------------------------------------------------------------+
bool CEhlersBandsCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
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
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
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
               m_price[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
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
//| Main Incremental Calculation (O(1) Live Tick Pipeline)           |
//+------------------------------------------------------------------+
void CEhlersBandsCalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   int warmup = GetWarmupBars();
   if(rates_total <= warmup)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// 1. Prepare Unified Price Series (Standard or HA)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 2. Calculate Centerline directly on prepared m_price[]
   m_calc_center.Calculate(rates_total, prev_calculated, m_price, m_price, m_price, m_price, middle_buffer);

// 3. Clean Pre-Warmup Zones on fresh calculation
   if(prev_calculated == 0)
     {
      int clear_limit = MathMin(warmup, rates_total);
      for(int i = 0; i < clear_limit; i++)
        {
         upper_buffer[i] = EMPTY_VALUE;
         lower_buffer[i] = EMPTY_VALUE;
        }
     }

   int loop_start = MathMax(warmup, start_index);

// 4. Calculate Outer Volatility Envelopes
   if(m_bands_mode == BANDS_RMS_RESIDUAL)
     {
      for(int i = loop_start; i < rates_total; i++)
        {
         double mid = middle_buffer[i];
         if(mid == EMPTY_VALUE)
           {
            upper_buffer[i] = EMPTY_VALUE;
            lower_buffer[i] = EMPTY_VALUE;
            continue;
           }

         double sum_sq = 0.0;
         for(int j = 0; j < m_band_period; j++)
           {
            double diff = m_price[i - j] - middle_buffer[i - j];
            sum_sq += diff * diff;
           }

         double rms_dev  = MathSqrt(sum_sq * m_inv_band_period);
         double band_ext = m_multiplier * rms_dev;

         upper_buffer[i] = mid + band_ext;
         lower_buffer[i] = mid - band_ext;
        }
     }
   else // BANDS_CLASSIC_STDEV
     {
      for(int i = loop_start; i < rates_total; i++)
        {
         double mid = middle_buffer[i];
         if(mid == EMPTY_VALUE)
           {
            upper_buffer[i] = EMPTY_VALUE;
            lower_buffer[i] = EMPTY_VALUE;
            continue;
           }

         double sum_sq = 0.0;
         for(int j = 0; j < m_band_period; j++)
           {
            double diff = m_price[i - j] - mid;
            sum_sq += diff * diff;
           }

         double stdev    = MathSqrt(sum_sq * m_inv_band_period);
         double band_ext = m_multiplier * stdev;

         upper_buffer[i] = mid + band_ext;
         lower_buffer[i] = mid - band_ext;
        }
     }
  }

//+------------------------------------------------------------------+
//| Export Internal Price Buffer (For %B & Ensemble Calculations)    |
//+------------------------------------------------------------------+
void CEhlersBandsCalculator::GetPriceBuffer(double &dest_array[]) const
  {
   int size = ArraySize(m_price);
   if(size > 0)
     {
      ArrayResize(dest_array, size, 2048);
      ArraySetAsSeries(dest_array, false);
      ArrayCopy(dest_array, m_price, 0, 0, size);
     }
  }

#endif // EHLERS_BANDS_CALCULATOR_MQH
//+------------------------------------------------------------------+
