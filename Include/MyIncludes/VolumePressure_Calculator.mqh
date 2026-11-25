//+------------------------------------------------------------------+
//|                                     VolumePressure_Calculator.mqh|
//|      Engine for Volume Pressure (Money Flow Multiplier / CLV).   |
//|      VERSION 2.00: 2026 Enterprise Edition with 14-MA Smoothing, |
//|                    VWMA Weighting, HA Support & Capacity Memory  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef VOLUME_PRESSURE_CALCULATOR_MQH
#define VOLUME_PRESSURE_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//| CLASS: CVolumePressureCalculator                                 |
//+==================================================================+
class CVolumePressureCalculator
  {
protected:
   CMovingAverageCalculator *m_ma;
   CHeikinAshi_Calculator    m_ha_engine;

   int                       m_smooth_period;
   ENUM_MA_TYPE              m_ma_type;
   bool                      m_use_heikin_ashi;

   //--- Persistent State Buffers
   double                    m_raw_mfm[];
   double                    m_vol_buf[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   void                      ComputeRawMFM(const int rates_total, const int start_index,
                                           const double &high[], const double &low[], const double &close[],
                                           double &out_vpres[]);

public:
                     CVolumePressureCalculator(void);
   virtual                  ~CVolumePressureCalculator(void);

   //--- Modern Unified Init (14-Model MA + Synthetic HA Support)
   bool                      Init(const int smooth_period, const ENUM_MA_TYPE ma_type, const bool use_heikin_ashi);

   //--- 100% Backward Compatible Legacy Init (External Scripts Compatible)
   bool                      Init(const int smooth_period)
     {
      return Init(smooth_period, EMA, false);
     }

   //--- Legacy Compatible Calculate (High, Low, Close only - No Volume / No HA Open)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &high[], const double &low[], const double &close[],
                                       double &out_vpres[]);

   //--- Modern Calculate with Full OHLC (Supports Synthetic Heikin Ashi)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_vpres[]);

   //--- Modern Calculate with OHLC + Long Volume (Supports Native VWMA Smoothing)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &out_vpres[]);

   //--- Modern Calculate with OHLC + Double Volume (Supports MTF VWMA Smoothing)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const double &volume[],
                                       double &out_vpres[]);

   int                       GetSmoothPeriod(void) const { return m_smooth_period; }
   ENUM_MA_TYPE              GetMAType(void)       const { return m_ma_type; }
   bool                      IsHeikinAshi(void)    const { return m_use_heikin_ashi; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVolumePressureCalculator::CVolumePressureCalculator(void) : m_ma(NULL),
   m_smooth_period(1),
   m_ma_type(EMA),
   m_use_heikin_ashi(false)
  {
   ArraySetAsSeries(m_raw_mfm,  false);
   ArraySetAsSeries(m_vol_buf,  false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVolumePressureCalculator::~CVolumePressureCalculator(void)
  {
   if(CheckPointer(m_ma) != POINTER_INVALID && m_ma != NULL)
     {
      delete m_ma;
      m_ma = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Modern Unified Initialization (Leak-Free)                        |
//+------------------------------------------------------------------+
bool CVolumePressureCalculator::Init(const int smooth_period, const ENUM_MA_TYPE ma_type, const bool use_heikin_ashi)
  {
   m_smooth_period   = (smooth_period < 1) ? 1 : smooth_period;
   m_ma_type         = ma_type;
   m_use_heikin_ashi = use_heikin_ashi;

// Clean up prior instance to prevent memory leak on re-init
   if(CheckPointer(m_ma) != POINTER_INVALID && m_ma != NULL)
     {
      delete m_ma;
      m_ma = NULL;
     }

   if(m_smooth_period > 1)
     {
      m_ma = new CMovingAverageCalculator();
      if(CheckPointer(m_ma) == POINTER_INVALID || m_ma == NULL || !m_ma.Init(m_smooth_period, m_ma_type))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Core Money Flow Multiplier (CLV) Calculation                     |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::ComputeRawMFM(const int rates_total, const int start_index,
      const double &high[], const double &low[], const double &close[],
      double &out_vpres[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      double range = high[i] - low[i];
      double mfm   = 0.0;

      if(range > 1.0e-9)
         mfm = (2.0 * close[i] - high[i] - low[i]) / range;
      else
         mfm = 0.0;

      // Strict bounds [-1.0, +1.0]
      if(mfm > 1.0)
         mfm = 1.0;
      else
         if(mfm < -1.0)
            mfm = -1.0;

      m_raw_mfm[i] = mfm;

      if(m_smooth_period <= 1)
         out_vpres[i] = mfm;
     }
  }

//+------------------------------------------------------------------+
//| Legacy Compatible Calculate (High, Low, Close only)              |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &high[], const double &low[], const double &close[],
      double &out_vpres[])
  {
   if(rates_total < 2)
      return;

   if(ArraySize(m_raw_mfm) != rates_total)
     {
      ArrayResize(m_raw_mfm, rates_total, 2048);
      ArraySetAsSeries(m_raw_mfm, false);
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   ComputeRawMFM(rates_total, start, high, low, close, out_vpres);

   if(m_smooth_period > 1 && CheckPointer(m_ma) != POINTER_INVALID && m_ma != NULL)
      m_ma.CalculateOnArray(rates_total, prev_calculated, m_raw_mfm, out_vpres, 0);
  }

//+------------------------------------------------------------------+
//| Modern Calculate (Full OHLC - Supports Heikin Ashi)              |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &out_vpres[])
  {
   if(rates_total < 2)
      return;

   if(ArraySize(m_raw_mfm) != rates_total)
     {
      ArrayResize(m_raw_mfm, rates_total, 2048);
      ArraySetAsSeries(m_raw_mfm, false);
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(m_use_heikin_ashi)
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

      m_ha_engine.Calculate(rates_total, start, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      ComputeRawMFM(rates_total, start, m_ha_high, m_ha_low, m_ha_close, out_vpres);
     }
   else
     {
      ComputeRawMFM(rates_total, start, high, low, close, out_vpres);
     }

   if(m_smooth_period > 1 && CheckPointer(m_ma) != POINTER_INVALID && m_ma != NULL)
      m_ma.CalculateOnArray(rates_total, prev_calculated, m_raw_mfm, out_vpres, 0);
  }

//+------------------------------------------------------------------+
//| Modern Calculate with Long Volume (Native VWMA Support)          |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const long &volume[],
      double &out_vpres[])
  {
   if(rates_total < 2)
      return;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total, 2048);
      ArraySetAsSeries(m_vol_buf, false);
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
      m_vol_buf[i] = (volume[i] < 1) ? 1.0 : (double)volume[i];

   Calculate(rates_total, prev_calculated, open, high, low, close, m_vol_buf, out_vpres);
  }

//+------------------------------------------------------------------+
//| Modern Calculate with Double Volume (MTF VWMA Support)           |
//+------------------------------------------------------------------+
void CVolumePressureCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const double &volume[],
      double &out_vpres[])
  {
   if(rates_total < 2)
      return;

   if(ArraySize(m_raw_mfm) != rates_total)
     {
      ArrayResize(m_raw_mfm, rates_total, 2048);
      ArraySetAsSeries(m_raw_mfm, false);
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(m_use_heikin_ashi)
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

      m_ha_engine.Calculate(rates_total, start, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      ComputeRawMFM(rates_total, start, m_ha_high, m_ha_low, m_ha_close, out_vpres);
     }
   else
     {
      ComputeRawMFM(rates_total, start, high, low, close, out_vpres);
     }

   if(m_smooth_period > 1 && CheckPointer(m_ma) != POINTER_INVALID && m_ma != NULL)
      m_ma.CalculateOnArray(rates_total, prev_calculated, m_raw_mfm, volume, out_vpres, 0);
  }

#endif // VOLUME_PRESSURE_CALCULATOR_MQH
//+------------------------------------------------------------------+
