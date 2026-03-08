//+------------------------------------------------------------------+
//|                                     VolumePressure_Calculator.mqh|
//|      Engine for Volume Pressure (Money Flow Multiplier).         |
//|      Proxy for Tick Volume Delta (-1.0 to 1.0).                  |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVolumePressureCalculator
  {
protected:
   // Optional Smoothing
   CMovingAverageCalculator *m_ma;
   int                     m_smooth_period;

   double                  m_raw_mfm[]; // Raw Money Flow Multiplier

public:
                     CVolumePressureCalculator();
                    ~CVolumePressureCalculator();

   bool                    Init(int smooth_period);

   void                    Calculate(int rates_total, int prev_calculated,
                                     const double &high[], const double &low[], const double &close[],
                                     double &out_vpres[]);
  };

//+------------------------------------------------------------------+
CVolumePressureCalculator::CVolumePressureCalculator() : m_ma(NULL) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CVolumePressureCalculator::~CVolumePressureCalculator()
  {
   if(CheckPointer(m_ma)==POINTER_DYNAMIC)
      delete m_ma;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CVolumePressureCalculator::Init(int smooth_period)
  {
   m_smooth_period = (smooth_period < 1) ? 1 : smooth_period;

   if(m_smooth_period > 1)
     {
      m_ma = new CMovingAverageCalculator();
      // EMA smoothing for reactiveness
      if(!m_ma.Init(m_smooth_period, EMA))
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::Calculate(int rates_total, int prev_calculated,
      const double &high[], const double &low[], const double &close[],
      double &out_vpres[])
  {
   if(rates_total < 2)
      return;

   if(ArraySize(m_raw_mfm) != rates_total)
      ArrayResize(m_raw_mfm, rates_total);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double range = high[i] - low[i];
      double mfm = 0;

      if(range > 1.0e-9) // Prevent div/0
        {
         // Formula: ( (C-L) - (H-C) ) / (H-L)
         // Simplified: (2*C - H - L) / (H - L)
         mfm = (2.0 * close[i] - high[i] - low[i]) / range;
        }
      else
        {
         mfm = 0.0; // Flat bar (Doji with no range)
        }

      // Clamp just in case
      if(mfm > 1.0)
         mfm = 1.0;
      if(mfm < -1.0)
         mfm = -1.0;

      m_raw_mfm[i] = mfm;

      // Direct output if no smoothing
      if(m_smooth_period <= 1)
         out_vpres[i] = mfm;
     }

// Apply Smoothing if requested
   if(m_smooth_period > 1 && CheckPointer(m_ma) != POINTER_INVALID)
     {
      m_ma.CalculateOnArray(rates_total, prev_calculated, m_raw_mfm, out_vpres);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
