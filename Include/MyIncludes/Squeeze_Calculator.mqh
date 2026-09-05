//+------------------------------------------------------------------+
//|                                        Squeeze_Calculator.mqh    |
//|      Engine for Volatility Squeeze (John Carter's TTM Logic).    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Genuine TTM Linear Regression Engine with Bounds Protection

#ifndef SQUEEZE_CALCULATOR_MQH
#define SQUEEZE_CALCULATOR_MQH

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\KeltnerChannel_Calculator.mqh>

//+==================================================================+
//|             CLASS: CSqueezeCalculator                            |
//+==================================================================+
class CSqueezeCalculator
  {
protected:
   //--- Composition Engines
   CBollingerBandsCalculator *m_bb_calc;
   CKeltnerChannelCalculator *m_kc_calc;

   int                       m_period;
   int                       m_mom_period;
   double                    m_bb_mult;
   double                    m_kc_mult;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Persistent State Buffers
   double                    m_bb_up[], m_bb_lo[], m_bb_mid[];
   double                    m_kc_up[], m_kc_lo[], m_kc_mid[];
   double                    m_delta[];
   double                    m_price_close[];

   double                    CalculateLinRegSlope(const int bar_idx, const int length, const double &src_array[]);

public:
                     CSqueezeCalculator(void);
   virtual                  ~CSqueezeCalculator(void);

   //--- Enhanced Pro Init
   bool                      Init(const int period, const double bb_mult, const double kc_mult, const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init
   bool                      Init(const int period, const double bb_mult, const double kc_mult, const int mom_period)
     {
      return Init(period, bb_mult, kc_mult, mom_period, PRICE_CLOSE_STD);
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

   int                       GetRequiredWarmup(void) const { return MathMax(m_period, m_mom_period) + 5; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSqueezeCalculator::CSqueezeCalculator(void) : m_period(20),
   m_mom_period(20),
   m_bb_mult(2.0),
   m_kc_mult(1.5),
   m_source_price(PRICE_CLOSE_STD),
   m_bb_calc(NULL),
   m_kc_calc(NULL)
  {
   ArraySetAsSeries(m_bb_up,       false);
   ArraySetAsSeries(m_bb_lo,       false);
   ArraySetAsSeries(m_bb_mid,      false);
   ArraySetAsSeries(m_kc_up,       false);
   ArraySetAsSeries(m_kc_lo,       false);
   ArraySetAsSeries(m_kc_mid,      false);
   ArraySetAsSeries(m_delta,       false);
   ArraySetAsSeries(m_price_close, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSqueezeCalculator::~CSqueezeCalculator(void)
  {
   if(CheckPointer(m_bb_calc) != POINTER_INVALID)
     {
      delete m_bb_calc;
      m_bb_calc = NULL;
     }
   if(CheckPointer(m_kc_calc) != POINTER_INVALID)
     {
      delete m_kc_calc;
      m_kc_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CSqueezeCalculator::Init(const int period, const double bb_mult, const double kc_mult, const int mom_period, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period       = (period < 5) ? 5 : period;
   m_mom_period   = (mom_period < 2) ? 2 : mom_period;
   m_bb_mult      = (bb_mult <= 0.0) ? 2.0 : bb_mult;
   m_kc_mult      = (kc_mult <= 0.0) ? 1.5 : kc_mult;
   m_source_price = price_source;

// 1. Initialize Bollinger Bands Engine
   if(CheckPointer(m_bb_calc) != POINTER_INVALID)
     {
      delete m_bb_calc;
      m_bb_calc = NULL;
     }
   m_bb_calc = new CBollingerBandsCalculator();
   if(CheckPointer(m_bb_calc) == POINTER_INVALID || !m_bb_calc.Init(m_period, m_bb_mult, SMA, m_source_price))
      return false;

// 2. Initialize Keltner Channel Engine
   if(CheckPointer(m_kc_calc) != POINTER_INVALID)
     {
      delete m_kc_calc;
      m_kc_calc = NULL;
     }
   m_kc_calc = new CKeltnerChannelCalculator();
   if(CheckPointer(m_kc_calc) == POINTER_INVALID || !m_kc_calc.Init(m_period, SMA, m_period, m_kc_mult, ATR_SOURCE_STANDARD, m_source_price))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Closed-Form O(1) Linear Regression Fitting Helper                |
//+------------------------------------------------------------------+
double CSqueezeCalculator::CalculateLinRegSlope(const int bar_idx, const int length, const double &src_array[])
  {
   if(bar_idx < length - 1)
      return 0.0;

   double sum_y  = 0.0;
   double sum_xy = 0.0;

// Closed-form constant: sum(x) = 0 when centered at 0
// x ranges from -(length-1)/2 to +(length-1)/2
   double half_len = (double)(length - 1) / 2.0;

   for(int k = 0; k < length; k++)
     {
      int idx = bar_idx - (length - 1 - k);
      double y = src_array[idx];
      double x = (double)k - half_len;

      sum_y  += y;
      sum_xy += x * y;
     }

// sum(x^2) = length * (length^2 - 1) / 12
   double sum_xx = (double)length * ((double)length * (double)length - 1.0) / 12.0;
   double slope  = (sum_xx > 1.0e-9) ? (sum_xy / sum_xx) : 0.0;
   double intercept = sum_y / (double)length;

// End point value of linear regression line at current bar
   return intercept + slope * half_len;
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

// Safe allocation of destination arrays
   if(ArraySize(out_mom) != rates_total)
     {
      ArrayResize(out_mom, rates_total);
      ArraySetAsSeries(out_mom, false);
      ArrayInitialize(out_mom, 0.0);
     }
   if(ArraySize(out_mom_color) != rates_total)
     {
      ArrayResize(out_mom_color, rates_total);
      ArraySetAsSeries(out_mom_color, false);
      ArrayInitialize(out_mom_color, 0.0);
     }
   if(ArraySize(out_sqz_val) != rates_total)
     {
      ArrayResize(out_sqz_val, rates_total);
      ArraySetAsSeries(out_sqz_val, false);
      ArrayInitialize(out_sqz_val, 0.0);
     }
   if(ArraySize(out_sqz_color) != rates_total)
     {
      ArrayResize(out_sqz_color, rates_total);
      ArraySetAsSeries(out_sqz_color, false);
      ArrayInitialize(out_sqz_color, 0.0);
     }

// Resize internal state buffers
   if(ArraySize(m_bb_up) != rates_total)
     {
      ArrayResize(m_bb_up,       rates_total);
      ArraySetAsSeries(m_bb_up,       false);
      ArrayResize(m_bb_lo,       rates_total);
      ArraySetAsSeries(m_bb_lo,       false);
      ArrayResize(m_bb_mid,      rates_total);
      ArraySetAsSeries(m_bb_mid,      false);
      ArrayResize(m_kc_up,       rates_total);
      ArraySetAsSeries(m_kc_up,       false);
      ArrayResize(m_kc_lo,       rates_total);
      ArraySetAsSeries(m_kc_lo,       false);
      ArrayResize(m_kc_mid,      rates_total);
      ArraySetAsSeries(m_kc_mid,      false);
      ArrayResize(m_delta,       rates_total);
      ArraySetAsSeries(m_delta,       false);
      ArrayResize(m_price_close, rates_total);
      ArraySetAsSeries(m_price_close, false);
     }

   ENUM_APPLIED_PRICE price_type = (m_source_price <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)m_source_price) :
                                   (ENUM_APPLIED_PRICE)m_source_price;

// 1. Run Bollinger Bands Calculation
   m_bb_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_bb_mid, m_bb_up, m_bb_lo);

// 2. Run Keltner Channels Calculation
   m_kc_calc.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, m_kc_mid, m_kc_up, m_kc_lo);

   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : m_period;
   if(start_index < m_period)
      start_index = m_period;

// 3. Compute TTM Delta Series: Close - Avg(DonchianMid + SMA)
   for(int i = start_index; i < rates_total; i++)
     {
      m_price_close[i] = close[i];

      double highest_h = high[i];
      double lowest_l  = low[i];

      for(int k = 1; k < m_period; k++)
        {
         int idx = i - k;
         if(idx < 0)
            break;
         highest_h = MathMax(highest_h, high[idx]);
         lowest_l  = MathMin(lowest_l,  low[idx]);
        }

      double donchian_mid = (highest_h + lowest_l) / 2.0;
      double avg_baseline = (donchian_mid + m_bb_mid[i]) / 2.0;
      m_delta[i]          = close[i] - avg_baseline;
     }

// 4. Compute Linear Regression Momentum & Squeeze State
   int mom_start = MathMax(start_index, m_period + m_mom_period - 1);

   for(int i = mom_start; i < rates_total; i++)
     {
      // --- A. Squeeze Condition (BB completely inside KC) ---
      bool is_squeeze = (m_bb_up[i] < m_kc_up[i]) && (m_bb_lo[i] > m_kc_lo[i]);

      out_sqz_val[i]   = 0.0; // Anchored directly on zero line
      out_sqz_color[i] = is_squeeze ? 1.0 : 0.0; // 0=Lime (Fired / No Sqz), 1=Red (Squeeze Active)

      // --- B. TTM Linear Regression Momentum Value ---
      out_mom[i] = CalculateLinRegSlope(i, m_mom_period, m_delta);

      // --- C. 4-Color Swapped Thermal Momentum Classification ---
      double cur_mom  = out_mom[i];
      double prev_mom = out_mom[i - 1];

      if(cur_mom >= 0.0)
        {
         if(cur_mom >= prev_mom)
            out_mom_color[i] = 0.0; // Index 0: clrLightSkyBlue (Expanding Bull Momentum)
         else
            out_mom_color[i] = 1.0; // Index 1: clrDeepSkyBlue (Decelerating Bull Momentum)
        }
      else // cur_mom < 0.0
        {
         if(cur_mom <= prev_mom)
            out_mom_color[i] = 2.0; // Index 2: clrOrangeRed (Expanding Bear Momentum)
         else
            out_mom_color[i] = 3.0; // Index 3: clrCoral (Decelerating Bear Momentum)
        }
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
   ArrayResize(dummy_mom_color, rates_total);
   Calculate(rates_total, prev_calculated, open, high, low, close, out_mom, dummy_mom_color, out_sqz_val, out_sqz_color);
  }

#endif // SQUEEZE_CALCULATOR_MQH
//+------------------------------------------------------------------+
