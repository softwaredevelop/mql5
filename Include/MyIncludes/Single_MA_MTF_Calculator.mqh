//+------------------------------------------------------------------+
//|                                     Single_MA_MTF_Calculator.mqh |
//|      VERSION 1.01: Corrected access to protected members.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CSingleMAMTFCalculator
  {
protected:
   CMovingAverageCalculator *m_ma_calc;
   ENUM_TIMEFRAMES          m_timeframe;

   virtual CMovingAverageCalculator *CreateMAInstance(void);

public:
                     CSingleMAMTFCalculator(void);
   virtual          ~CSingleMAMTFCalculator(void);

   bool              Init(ENUM_TIMEFRAMES tf, int period, ENUM_MA_TYPE ma_type, bool is_ha);
   void              Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSingleMAMTFCalculator_HA : public CSingleMAMTFCalculator
  {
protected:
   virtual CMovingAverageCalculator *CreateMAInstance(void) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSingleMAMTFCalculator::CSingleMAMTFCalculator(void) { m_ma_calc = NULL; }
CSingleMAMTFCalculator::~CSingleMAMTFCalculator(void) { if(CheckPointer(m_ma_calc) != POINTER_INVALID) delete m_ma_calc; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMovingAverageCalculator *CSingleMAMTFCalculator::CreateMAInstance(void) { return new CMovingAverageCalculator(); }
CMovingAverageCalculator *CSingleMAMTFCalculator_HA::CreateMAInstance(void) { return new CMovingAverageCalculator_HA(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSingleMAMTFCalculator::Init(ENUM_TIMEFRAMES tf, int period, ENUM_MA_TYPE ma_type, bool is_ha)
  {
   m_timeframe = (tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : tf;

   if(is_ha)
      m_ma_calc = new CMovingAverageCalculator_HA();
   else
      m_ma_calc = new CMovingAverageCalculator();

   if(CheckPointer(m_ma_calc) == POINTER_INVALID || !m_ma_calc.Init(period, ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSingleMAMTFCalculator::Calculate(int rates_total, const datetime &time[], ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &ma_buffer[])
  {
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return;

   bool is_mtf_mode = (m_timeframe > Period());

   if(is_mtf_mode)
     {
      int htf_rates_total = (int)SeriesInfoInteger(_Symbol, m_timeframe, SERIES_BARS_COUNT);
      //--- CORRECTED: Use the public GetPeriod() method ---
      if(htf_rates_total < m_ma_calc.GetPeriod())
         return;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];
      if(CopyTime(_Symbol, m_timeframe, 0, htf_rates_total, htf_time) <= 0 || CopyOpen(_Symbol, m_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, m_timeframe, 0, htf_rates_total, htf_high) <= 0 || CopyLow(_Symbol, m_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, m_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return;

      double htf_ma_buffer[];
      ArrayResize(htf_ma_buffer, htf_rates_total);
      m_ma_calc.Calculate(htf_rates_total, price_type, htf_open, htf_high, htf_low, htf_close, htf_ma_buffer);

      ArraySetAsSeries(htf_ma_buffer, true);
      datetime time_series[];
      ArrayCopy(time_series, time, 0, 0, rates_total);
      ArraySetAsSeries(time_series, true);
      ArraySetAsSeries(ma_buffer, true);

      for(int i = 0; i < rates_total; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, m_timeframe, time_series[i]);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            ma_buffer[i] = htf_ma_buffer[htf_bar_shift];
         else
            ma_buffer[i] = EMPTY_VALUE;
        }
      ArraySetAsSeries(ma_buffer, false);
     }
   else
     {
      m_ma_calc.Calculate(rates_total, price_type, open, high, low, close, ma_buffer);
     }
  }
//+------------------------------------------------------------------+
