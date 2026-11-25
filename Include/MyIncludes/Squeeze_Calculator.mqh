//+------------------------------------------------------------------+
//|                                        Squeeze_Calculator.mqh    |
//|      Engine for Volatility Squeeze (John Carter's TTM Logic).    |
//|      VERSION 4.00: 2026 Enterprise Edition with Independent ATR  |
//|                    Period, Fixed HA Pipeline & Precomputed LinReg|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00"

#ifndef SQUEEZE_CALCULATOR_MQH
#define SQUEEZE_CALCULATOR_MQH

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\KeltnerChannel_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CSqueezeCalculator                            |
//+==================================================================+
class CSqueezeCalculator
  {
protected:
   //--- Composition Engines
   CBollingerBandsCalculator *m_bb_calc;
   CKeltnerChannelCalculator *m_kc_calc;
   CHeikinAshi_Calculator     m_ha_engine;

   int                       m_period;       // BB & KC MA & Donchian Period
   int                       m_atr_period;   // Independent ATR Volatility Period
   int                       m_mom_period;   // Linear Regression Momentum Period
   double                    m_bb_mult;
   double                    m_kc_mult;
   ENUM_ATR_SOURCE           m_atr_source;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Precomputed Linear Regression Constants (Calculated ONCE in Init)
   double                    m_half_len;
   double                    m_inv_mom_period;
   double                    m_inv_sum_xx;

   //--- Persistent State Buffers
   double                    m_bb_up[], m_bb_lo[], m_bb_mid[];
   double                    m_kc_up[], m_kc_lo[], m_kc_mid[];
   double                    m_delta[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   double                    CalculateLinRegEndPoint(const int bar_idx, const double &src_array[]) const;

public:
                     CSqueezeCalculator(void);
   virtual                  ~CSqueezeCalculator(void);

   //--- Modern 7-Parameter Init (Full Control: Independent ATR Period & ATR Source)
   bool                      Init(const int period, const double bb_mult, const int atr_period, const double kc_mult,
                                  const ENUM_ATR_SOURCE atr_src, const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Modern 6-Parameter Init (Independent ATR Period, Standard ATR Source)
   bool                      Init(const int period, const double bb_mult, const int atr_period, const double kc_mult,
                                  const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source)
     {
      return Init(period, bb_mult, atr_period, kc_mult, ATR_SOURCE_STANDARD, mom_period, price_source);
     }

   //--- 100% Backward Compatible Legacy 5-Parameter Init
   bool                      Init(const int period, const double bb_mult, const double kc_mult,
                                  const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source)
     {
      return Init(period, bb_mult, period, kc_mult, ATR_SOURCE_STANDARD, mom_period, price_source);
     }

   //--- 100% Backward Compatible Legacy 4-Parameter Init
   bool                      Init(const int period, const double bb_mult, const double kc_mult, const int mom_period)
     {
      return Init(period, bb_mult, period, kc_mult, ATR_SOURCE_STANDARD, mom_period, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculate Method
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_mom[], double &out_mom_color[],
                                       double &out_sqz_val[], double &out_sqz_color[]);

   //--- Legacy Overload with price_type parameter
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_mom[], double &out_sqz_val[], double &out_sqz_color[]);

   int                       GetPeriod(void)         const { return m_period; }
   int                       GetATRPeriod(void)      const { return m_atr_period; }
   int                       GetMomPeriod(void)      const { return m_mom_period; }
   int                       GetRequiredWarmup(void) const { return MathMax(MathMax(m_period, m_atr_period), m_period + m_mom_period); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSqueezeCalculator::CSqueezeCalculator(void) : m_period(20),
   m_atr_period(20),
   m_mom_period(20),
   m_bb_mult(2.0),
   m_kc_mult(1.5),
   m_atr_source(ATR_SOURCE_STANDARD),
   m_source_price(PRICE_CLOSE_STD),
   m_half_len(9.5),
   m_inv_mom_period(0.05),
   m_inv_sum_xx(12.0 / (20.0 * 399.0)),
   m_bb_calc(NULL),
   m_kc_calc(NULL)
  {
   ArraySetAsSeries(m_bb_up,    false);
   ArraySetAsSeries(m_bb_lo,    false);
   ArraySetAsSeries(m_bb_mid,   false);
   ArraySetAsSeries(m_kc_up,    false);
   ArraySetAsSeries(m_kc_lo,    false);
   ArraySetAsSeries(m_kc_mid,   false);
   ArraySetAsSeries(m_delta,    false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSqueezeCalculator::~CSqueezeCalculator(void)
  {
   if(CheckPointer(m_bb_calc) != POINTER_INVALID && m_bb_calc != NULL)
     {
      delete m_bb_calc;
      m_bb_calc = NULL;
     }
   if(CheckPointer(m_kc_calc) != POINTER_INVALID && m_kc_calc != NULL)
     {
      delete m_kc_calc;
      m_kc_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Master Initialization                                            |
//+------------------------------------------------------------------+
bool CSqueezeCalculator::Init(const int period, const double bb_mult, const int atr_period, const double kc_mult,
                              const ENUM_ATR_SOURCE atr_src, const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period       = (period < 5) ? 5 : period;
   m_atr_period   = (atr_period < 1) ? 1 : atr_period;
   m_mom_period   = (mom_period < 2) ? 2 : mom_period;
   m_bb_mult      = (bb_mult <= 0.0) ? 2.0 : bb_mult;
   m_kc_mult      = (kc_mult <= 0.0) ? 1.5 : kc_mult;
   m_atr_source   = atr_src;
   m_source_price = price_source;

// Precompute Linear Regression Constants
   double len       = (double)m_mom_period;
   m_half_len       = (len - 1.0) * 0.5;
   m_inv_mom_period = 1.0 / len;
   double sum_xx    = len * (len * len - 1.0) / 12.0;
   m_inv_sum_xx     = (sum_xx > 1.0e-9) ? (1.0 / sum_xx) : 0.0;

   bool is_ha = (m_source_price <= PRICE_HA_CLOSE);

// 1. Initialize Bollinger Bands Engine (Instantiate true HA subclass if HA selected!)
   if(CheckPointer(m_bb_calc) != POINTER_INVALID && m_bb_calc != NULL)
     {
      delete m_bb_calc;
      m_bb_calc = NULL;
     }
   m_bb_calc = is_ha ? (CBollingerBandsCalculator*)(new CBollingerBandsCalculator_HA()) : (CBollingerBandsCalculator*)(new CBollingerBandsCalculator());

   if(CheckPointer(m_bb_calc) == POINTER_INVALID || !m_bb_calc.Init(m_period, m_bb_mult, SMA, m_source_price))
      return false;

// 2. Initialize Keltner Channel Engine (With independent ATR Period and ATR Source!)
   if(CheckPointer(m_kc_calc) != POINTER_INVALID && m_kc_calc != NULL)
     {
      delete m_kc_calc;
      m_kc_calc = NULL;
     }
   m_kc_calc = is_ha ? (CKeltnerChannelCalculator*)(new CKeltnerChannelCalculator_HA()) : (CKeltnerChannelCalculator*)(new CKeltnerChannelCalculator());

   if(CheckPointer(m_kc_calc) == POINTER_INVALID || !m_kc_calc.Init(m_period, SMA, m_atr_period, m_kc_mult, m_atr_source, m_source_price))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Division-Free Closed-Form Linear Regression Endpoint             |
//+------------------------------------------------------------------+
double CSqueezeCalculator::CalculateLinRegEndPoint(const int bar_idx, const double &src_array[]) const
  {
   if(bar_idx < m_mom_period - 1)
      return 0.0;

   double sum_y  = 0.0;
   double sum_xy = 0.0;

   for(int k = 0; k < m_mom_period; k++)
     {
      int idx  = bar_idx - (m_mom_period - 1 - k);
      double y = src_array[idx];
      double x = (double)k - m_half_len;

      sum_y  += y;
      sum_xy += x * y;
     }

   double slope     = sum_xy * m_inv_sum_xx;
   double intercept = sum_y * m_inv_mom_period;

   return intercept + slope * m_half_len;
  }

//+------------------------------------------------------------------+
//| Main Incremental Squeeze & TTM Momentum Calculation Loop         |
//+------------------------------------------------------------------+
void CSqueezeCalculator::Calculate(const int rates_total, const int prev_calculated,
                                   const double &open[], const double &high[],
                                   const double &low[], const double &close[],
                                   double &out_mom[], double &out_mom_color[],
                                   double &out_sqz_val[], double &out_sqz_color[])
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_bb_calc) == POINTER_INVALID || CheckPointer(m_kc_calc) == POINTER_INVALID)
      return;

// Safe capacity allocation of destination arrays
   if(ArraySize(out_mom) != rates_total)
     {
      ArrayResize(out_mom, rates_total, 2048);
      ArraySetAsSeries(out_mom, false);
     }
   if(ArraySize(out_mom_color) != rates_total)
     {
      ArrayResize(out_mom_color, rates_total, 2048);
      ArraySetAsSeries(out_mom_color, false);
     }
   if(ArraySize(out_sqz_val) != rates_total)
     {
      ArrayResize(out_sqz_val, rates_total, 2048);
      ArraySetAsSeries(out_sqz_val, false);
     }
   if(ArraySize(out_sqz_color) != rates_total)
     {
      ArrayResize(out_sqz_color, rates_total, 2048);
      ArraySetAsSeries(out_sqz_color, false);
     }

// Resize internal working buffers with memory reservation capacity
   if(ArraySize(m_bb_up) != rates_total)
     {
      ArrayResize(m_bb_up,  rates_total, 2048);
      ArrayResize(m_bb_lo,  rates_total, 2048);
      ArrayResize(m_bb_mid, rates_total, 2048);
      ArrayResize(m_kc_up,  rates_total, 2048);
      ArrayResize(m_kc_lo,  rates_total, 2048);
      ArrayResize(m_kc_mid, rates_total, 2048);
      ArrayResize(m_delta,  rates_total, 2048);

      ArraySetAsSeries(m_bb_up,  false);
      ArraySetAsSeries(m_bb_lo,  false);
      ArraySetAsSeries(m_bb_mid, false);
      ArraySetAsSeries(m_kc_up,  false);
      ArraySetAsSeries(m_kc_lo,  false);
      ArraySetAsSeries(m_kc_mid, false);
      ArraySetAsSeries(m_delta,  false);
     }

// EXACT MATHEMATICAL APPLIED PRICE MAPPING (Eliminates Off-by-One Mismatch!)
   bool is_ha = (m_source_price <= PRICE_HA_CLOSE);
   ENUM_APPLIED_PRICE price_type = is_ha ?
                                   (ENUM_APPLIED_PRICE)(-((int)m_source_price) - 1) :
                                   (ENUM_APPLIED_PRICE)m_source_price;

// 1. Run Bollinger Bands Calculation
   m_bb_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_bb_mid, m_bb_up, m_bb_lo);

// 2. Run Keltner Channels Calculation (With Independent ATR Period & Source)
   m_kc_calc.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, m_kc_mid, m_kc_up, m_kc_lo);

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;

// If HA mode is selected, synthesize authentic HA candles for TTM Delta calculation
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
     }

   int delta_start = MathMax(m_period - 1, start_index);

// 3. Compute TTM Delta Series: Close - Avg(DonchianMid + SMA)
   for(int i = delta_start; i < rates_total; i++)
     {
      double highest_h = is_ha ? m_ha_high[i] : high[i];
      double lowest_l  = is_ha ? m_ha_low[i]  : low[i];
      double c_price   = is_ha ? m_ha_close[i]: close[i];

      for(int k = 1; k < m_period; k++)
        {
         int idx = i - k;
         if(idx < 0)
            break;
         double h_val = is_ha ? m_ha_high[idx] : high[idx];
         double l_val = is_ha ? m_ha_low[idx]  : low[idx];
         if(h_val > highest_h)
            highest_h = h_val;
         if(l_val < lowest_l)
            lowest_l  = l_val;
        }

      double donchian_mid = (highest_h + lowest_l) * 0.5;
      double avg_baseline = (donchian_mid + m_bb_mid[i]) * 0.5;
      m_delta[i]          = c_price - avg_baseline;
     }

   int channel_warmup = MathMax(m_period, m_atr_period);
   int mom_start      = MathMax(start_index, MathMax(channel_warmup, m_period + m_mom_period - 1));

// Clean pre-warmup bars on fresh calculation
   if(prev_calculated == 0)
     {
      int clear_limit = MathMin(mom_start, rates_total);
      for(int i = 0; i < clear_limit; i++)
        {
         out_mom[i]       = 0.0;
         out_mom_color[i] = 0.0;
         out_sqz_val[i]   = 0.0;
         out_sqz_color[i] = 0.0;
        }
     }

// 4. Compute Linear Regression Momentum & Squeeze State
   for(int i = mom_start; i < rates_total; i++)
     {
      // --- A. Squeeze Condition (Bollinger Bands strictly inside Keltner Channels) ---
      bool is_squeeze = (m_bb_up[i] != EMPTY_VALUE && m_kc_up[i] != EMPTY_VALUE) &&
                        (m_bb_up[i] < m_kc_up[i]) && (m_bb_lo[i] > m_kc_lo[i]);

      out_sqz_val[i]   = 0.0;
      out_sqz_color[i] = is_squeeze ? 1.0 : 0.0; // 0 = Lime (Fired), 1 = Red (Squeeze Active)

      // --- B. TTM Linear Regression Momentum Value ---
      out_mom[i] = CalculateLinRegEndPoint(i, m_delta);

      // --- C. 4-Color Thermal Momentum Classification ---
      double cur_mom  = out_mom[i];
      double prev_mom = out_mom[i - 1];

      if(cur_mom >= 0.0)
         out_mom_color[i] = (cur_mom >= prev_mom) ? 0.0 : 1.0; // 0 = Expanding Bull, 1 = Decelerating Bull
      else
         out_mom_color[i] = (cur_mom <= prev_mom) ? 2.0 : 3.0; // 2 = Expanding Bear, 3 = Decelerating Bear
     }
  }

//+------------------------------------------------------------------+
//| Legacy Overload with price_type parameter                        |
//+------------------------------------------------------------------+
void CSqueezeCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                   const double &open[], const double &high[],
                                   const double &low[], const double &close[],
                                   double &out_mom[], double &out_sqz_val[], double &out_sqz_color[])
  {
   double dummy_mom_color[];
   ArrayResize(dummy_mom_color, rates_total, 2048);
   Calculate(rates_total, prev_calculated, open, high, low, close, out_mom, dummy_mom_color, out_sqz_val, out_sqz_color);
  }

#endif // SQUEEZE_CALCULATOR_MQH
//+------------------------------------------------------------------+
