//+------------------------------------------------------------------+
//|                                       Donchian_Calculator.mqh    |
//|      DSP Engine for Richard Donchian's Asymmetric Breakout Channel|
//|      VERSION 2.20: Streamlined Pure Architecture (No Legacy Cruft)|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.20"

#ifndef DONCHIAN_CALCULATOR_MQH
#define DONCHIAN_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Dedicated Two-State Price Enum for Donchian Channel Extremes
#ifndef ENUM_DONCHIAN_PRICE_TYPE_DEFINED
#define ENUM_DONCHIAN_PRICE_TYPE_DEFINED
enum ENUM_DONCHIAN_PRICE_TYPE
  {
   PRICE_DONCHIAN_STANDARD,    // Standard High / Low
   PRICE_DONCHIAN_HEIKIN_ASHI  // Synthetic Heikin Ashi High / Low
  };
#endif

//+==================================================================+
//| CLASS: CDonchianCalculator                                       |
//+==================================================================+
class CDonchianCalculator
  {
protected:
   int                       m_upper_period;
   int                       m_lower_period;
   int                       m_bar_offset;
   ENUM_DONCHIAN_PRICE_TYPE  m_price_type;

   //--- Synthetic Heikin Ashi Composition
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent Working Buffers
   double                    m_high_buf[];
   double                    m_low_buf[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PrepareData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

public:
                     CDonchianCalculator(void);
   virtual                  ~CDonchianCalculator(void) {}

   //--- Single Authoritative Initialization
   bool                      Init(const int upper_period, const int lower_period,
                                  const int bar_offset, const ENUM_DONCHIAN_PRICE_TYPE price_type);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &upper_out[], double &middle_out[], double &lower_out[]);

   int                       GetUpperPeriod(void) const { return m_upper_period; }
   int                       GetLowerPeriod(void) const { return m_lower_period; }
   int                       GetWarmupBars(void)  const { return MathMax(m_upper_period, m_lower_period) + m_bar_offset; }
   ENUM_DONCHIAN_PRICE_TYPE  GetPriceType(void)   const { return m_price_type; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDonchianCalculator::CDonchianCalculator(void) : m_upper_period(20),
   m_lower_period(20),
   m_bar_offset(1),
   m_price_type(PRICE_DONCHIAN_STANDARD)
  {
   ArraySetAsSeries(m_high_buf,  false);
   ArraySetAsSeries(m_low_buf,   false);
   ArraySetAsSeries(m_ha_open,   false);
   ArraySetAsSeries(m_ha_high,   false);
   ArraySetAsSeries(m_ha_low,    false);
   ArraySetAsSeries(m_ha_close,  false);
  }

//+------------------------------------------------------------------+
//| Primary Initialization                                           |
//+------------------------------------------------------------------+
bool CDonchianCalculator::Init(const int upper_period, const int lower_period,
                               const int bar_offset, const ENUM_DONCHIAN_PRICE_TYPE price_type)
  {
   m_upper_period = MathMax(1, upper_period);
   m_lower_period = MathMax(1, lower_period);
   m_bar_offset   = MathMax(0, bar_offset);
   m_price_type   = price_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Data (Direct Extreme Routing)                      |
//+------------------------------------------------------------------+
bool CDonchianCalculator::PrepareData(const int rates_total, const int start_index,
                                      const double &open[], const double &high[],
                                      const double &low[], const double &close[])
  {
   if(ArraySize(m_high_buf) != rates_total)
     {
      ArrayResize(m_high_buf, rates_total, 2048);
      ArrayResize(m_low_buf,  rates_total, 2048);
      ArraySetAsSeries(m_high_buf, false);
      ArraySetAsSeries(m_low_buf,  false);
     }

   if(m_price_type == PRICE_DONCHIAN_HEIKIN_ASHI)
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
         m_high_buf[i] = m_ha_high[i];
         m_low_buf[i]  = m_ha_low[i];
        }
     }
   else // PRICE_DONCHIAN_STANDARD
     {
      for(int i = start_index; i < rates_total; i++)
        {
         m_high_buf[i] = high[i];
         m_low_buf[i]  = low[i];
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Core Calculation Pipeline                                        |
//+------------------------------------------------------------------+
void CDonchianCalculator::Calculate(const int rates_total, const int prev_calculated,
                                    const double &open[], const double &high[],
                                    const double &low[], const double &close[],
                                    double &upper_out[], double &middle_out[], double &lower_out[])
  {
   int warmup = GetWarmupBars();
   if(rates_total <= warmup)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(!PrepareData(rates_total, start_index, open, high, low, close))
      return;

   int loop_start = MathMax(warmup, start_index);

// Incremental Scanning
   for(int i = loop_start; i < rates_total; i++)
     {
      // 1. Scan Highest High over UpperPeriod
      int u_scan_start = i - m_bar_offset;
      int u_scan_end   = u_scan_start - m_upper_period + 1;
      double highest   = m_high_buf[u_scan_start];

      for(int j = u_scan_start - 1; j >= u_scan_end; j--)
        {
         if(m_high_buf[j] > highest)
            highest = m_high_buf[j];
        }

      // 2. Scan Lowest Low over LowerPeriod (Asymmetric lookback)
      int l_scan_start = i - m_bar_offset;
      int l_scan_end   = l_scan_start - m_lower_period + 1;
      double lowest    = m_low_buf[l_scan_start];

      for(int j = l_scan_start - 1; j >= l_scan_end; j--)
        {
         if(m_low_buf[j] < lowest)
            lowest = m_low_buf[j];
        }

      // 3. Output Assignment with FMA Median
      upper_out[i]  = highest;
      lower_out[i]  = lowest;
      middle_out[i] = (highest + lowest) * 0.5;
     }

// Pre-warmup zone clearing
   if(prev_calculated == 0)
     {
      for(int i = 0; i < loop_start; i++)
        {
         upper_out[i]  = EMPTY_VALUE;
         middle_out[i] = EMPTY_VALUE;
         lower_out[i]  = EMPTY_VALUE;
        }
     }
  }

#endif // DONCHIAN_CALCULATOR_MQH
//+------------------------------------------------------------------+
