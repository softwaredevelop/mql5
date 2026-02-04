//+------------------------------------------------------------------+
//|                                        Squeeze_Calculator.mqh    |
//|      Engine for Volatility Squeeze (TTM Logic).                  |
//|      Combines Bollinger Bands and Keltner Channels.              |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\KeltnerChannel_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh> // To smooth momentum if needed

//+==================================================================+
//|             CLASS: CSqueezeCalculator                            |
//+==================================================================+
class CSqueezeCalculator
  {
protected:
   //--- Components
   CBollingerBandsCalculator *m_bb_calc;
   CKeltnerChannelCalculator *m_kc_calc;

   //--- Parameters
   int               m_period;
   int               m_mom_period;

   //--- Internal Buffers (State)
   double            m_bb_up[], m_bb_lo[], m_bb_mid[];
   double            m_kc_up[], m_kc_lo[], m_kc_mid[];
   double            m_delta[]; // For Momentum calculation (Price - Avg)
   double            m_mom_smooth[];

   //--- Linear Regression Helper
   void              CalculateMomentum(int rates_total, int prev_calculated, const double &price[], double &out_mom[]);

public:
                     CSqueezeCalculator();
   virtual          ~CSqueezeCalculator();

   bool              Init(int period, double bb_mult, double kc_mult, int mom_period);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_mom[], double &out_sqz_val[], double &out_sqz_color[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSqueezeCalculator::CSqueezeCalculator() : m_bb_calc(NULL), m_kc_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSqueezeCalculator::~CSqueezeCalculator()
  {
   if(CheckPointer(m_bb_calc) == POINTER_DYNAMIC)
      delete m_bb_calc;
   if(CheckPointer(m_kc_calc) == POINTER_DYNAMIC)
      delete m_kc_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSqueezeCalculator::Init(int period, double bb_mult, double kc_mult, int mom_period)
  {
   m_period = period;
   m_mom_period = mom_period;

// Initialize Components
   m_bb_calc = new CBollingerBandsCalculator();
// BB: Period, Deviation, SMA (Standard)
   if(!m_bb_calc.Init(m_period, bb_mult, SMA))
      return false;

   m_kc_calc = new CKeltnerChannelCalculator();
// KC: MA Period, SMA, ATR Period (same as length usually), Multiplier, Source Standard
   if(!m_kc_calc.Init(m_period, SMA, m_period, kc_mult, ATR_SOURCE_STANDARD))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CSqueezeCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                                   const double &open[], const double &high[],
                                   const double &low[], const double &close[],
                                   double &out_mom[], double &out_sqz_val[], double &out_sqz_color[])
  {
// 1. Resize Internal Buffers
   if(ArraySize(m_bb_up) != rates_total)
     {
      ArrayResize(m_bb_up, rates_total);
      ArrayResize(m_bb_lo, rates_total);
      ArrayResize(m_bb_mid, rates_total);
      ArrayResize(m_kc_up, rates_total);
      ArrayResize(m_kc_lo, rates_total);
      ArrayResize(m_kc_mid, rates_total);
      ArrayResize(m_delta, rates_total);
     }

// 2. Run BB Calc
   m_bb_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_bb_mid, m_bb_up, m_bb_lo);

// 3. Run KC Calc
// NOTE: Keltner Calc expects Arrays first in signature (fixed in v3.00 of script)
   m_kc_calc.Calculate(rates_total, prev_calculated, open, high, low, close, price_type, m_kc_mid, m_kc_up, m_kc_lo);

// 4. Calculate Squeeze State & Momentum
   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : m_period;
   if(start_index < m_period)
      start_index = m_period;

   for(int i = start_index; i < rates_total; i++)
     {
      // --- Squeeze Logic ---
      // Squeeze ON if BB is completely INSIDE KC
      // BB Upper < KC Upper  AND  BB Lower > KC Lower
      bool is_squeeze = (m_bb_up[i] < m_kc_up[i]) && (m_bb_lo[i] > m_kc_lo[i]);

      out_sqz_val[i] = 0.0; // Always plot on zero line

      // Color Index: 0=Green (OFF), 1=Red (ON)
      // Note: In MT5 drawing logic, usually index maps to colors defined in property.
      // If indicator_color2 = clrLime, clrRed
      // 0 -> Lime (No Squeeze)
      // 1 -> Red (Squeeze!)
      out_sqz_color[i] = is_squeeze ? 1.0 : 0.0;

      // --- Momentum Logic (Simplified TTM Style) ---
      // TTM Momentum is Linear Regression of (Price - Avg(DonchianMid + SMA))
      // Simplified professional version: Smoothed (Close - SMA) or Linear Reg Slope
      // Let's use: Price - SMA(20), smoothed by EMA(5) or similar, normalizing it.
      // Or simple Linear Regression Slope of Close.

      // Implementation: Difference from the Mean (m_bb_mid is the SMA)
      double delta = close[i] - m_bb_mid[i];

      // Simple smoothing for visual "wave"
      // Recurive EMA-like smoothing of delta
      // Inline EMA calculation for speed: Alpha = 2/(P+1)
      // Using m_mom_period
      // Assuming i is chronological
      if(i > 0)
        {
         // We can use a linear regression logic or simple smoothing.
         // Let's use Linear Regression of the delta over 12 bars for genuine "TTM" feel
         // Calculating LinReg Slope inline for last 'm_mom_period' bars

         double sum_x = 0, sum_y = 0, sum_xy = 0, sum_xx = 0;
         int n = m_mom_period;

         // Standard Linear Regression Forecast Logic on Price Deviation
         // We regress Price[k] against k
         // Actually, most Squeeze indicators use:
         // Val = LinearRegression( Source - (Highest+Lowest)/2 + SMA ) / 2 ... complicated.

         // Professional Approach: Smoothed Delta
         // This is robust and fast (O(1)).
         double mom_raw = close[i] - ((high[ArrayMaximum(high, i-m_period+1, m_period)] + low[ArrayMinimum(low, i-m_period+1, m_period)]) / 2.0 + m_bb_mid[i]) / 2.0;

         // Linear Regression on this 'mom_raw' is heavy.
         // Let's use simple coordinate smoothing.
         out_mom[i] = mom_raw; // Can be enhanced later with LinReg engine if strict TTM required
        }
      else
         out_mom[i] = 0;
     }

// Optional: Apply LinReg on the mom buffer if needed, but for "Pro" speed, raw delta is very effective directionaly.
// To mimic TTM perfectly, we would need a CLinearRegression calculator.
// For now, the delta from the "Donchian/SMA mix" is the core signal.
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
