//+------------------------------------------------------------------+
//|                                          VScore_Calculator.mqh   |
//|      Engine for V-Score (VWAP Z-Score).                          |
//|      Measures statistical deviation from VWAP.                   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\VWAP_Calculator.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVScoreCalculator
  {
protected:
   int               m_period;
   CVWAPCalculator   *m_vwap_calc;

   // Buffers
   double            m_vwap_buf[];
   double            m_diff_sq[]; // Squared differences buffer

   void              PrepareVWAP(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[]);

public:
                     CVScoreCalculator();
   virtual          ~CVScoreCalculator();

   bool              Init(int period, ENUM_VWAP_PERIOD vwap_reset);

   void              Calculate(int rates_total, int prev_calculated,
                               const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[],
                               double &out_vscore[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVScoreCalculator::CVScoreCalculator() : m_vwap_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVScoreCalculator::~CVScoreCalculator()
  {
   if(CheckPointer(m_vwap_calc) == POINTER_DYNAMIC)
      delete m_vwap_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVScoreCalculator::Init(int period, ENUM_VWAP_PERIOD vwap_reset)
  {
   m_period = (period < 2) ? 2 : period;

   m_vwap_calc = new CVWAPCalculator();
// Init VWAP with Tick Volume, enabled
   if(!m_vwap_calc.Init(vwap_reset, VOLUME_TICK, 0, true))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CVScoreCalculator::Calculate(int rates_total, int prev_calculated,
                                  const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                  const long &tick_volume[], const long &volume[],
                                  double &out_vscore[])
  {
   if(rates_total < m_period)
      return;

// 1. Prepare VWAP Buffer
   if(ArraySize(m_vwap_buf) != rates_total)
      ArrayResize(m_vwap_buf, rates_total);
   PrepareVWAP(rates_total, time, open, high, low, close, tick_volume, volume);

// 2. Calculate Standard Deviation of (Price - VWAP)
// We look back 'm_period' bars to calculate the volatility of the deviation

   int start = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

   for(int i = start; i < rates_total; i++)
     {
      double current_vwap = m_vwap_buf[i];

      // If VWAP is newly reset (0 or empty), VScore is 0
      if(current_vwap == 0 || current_vwap == EMPTY_VALUE)
        {
         out_vscore[i] = 0.0;
         continue;
        }

      double sum_sq_diff = 0;

      // StdDev of deviation over the window
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p = close[idx];
         double v = m_vwap_buf[idx];

         // If history has bad vwap, use price (diff=0)
         if(v == 0 || v == EMPTY_VALUE)
            v = p;

         double diff = p - v;
         sum_sq_diff += diff * diff;
        }

      double std_dev = MathSqrt(sum_sq_diff / m_period);

      if(std_dev > 1.0e-9)
         out_vscore[i] = (close[i] - current_vwap) / std_dev;
      else
         out_vscore[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Helper: Fill Internal VWAP Buffer                                |
//+------------------------------------------------------------------+
void CVScoreCalculator::PrepareVWAP(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[])
  {
   double odd[], even[];
   ArrayResize(odd, rates_total);
   ArrayResize(even, rates_total);

   m_vwap_calc.Calculate(rates_total, 0, time, open, high, low, close, tick_volume, volume, odd, even);

// Determine active buffer (Odd/Even logic of VWAP engine)
// We merge them into one continuous buffer
   for(int i=0; i<rates_total; i++)
     {
      if(odd[i] != EMPTY_VALUE && odd[i] != 0)
         m_vwap_buf[i] = odd[i];
      else
         m_vwap_buf[i] = even[i];
     }
  }
//+------------------------------------------------------------------+
