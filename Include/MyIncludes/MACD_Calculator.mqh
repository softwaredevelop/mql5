//+------------------------------------------------------------------+
//|                                               MACD_Calculator.mqh|
//|      Engine for Gerald Appel's MACD & Convergence/Divergence     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "5.00" // Full VWMA Support across Fast, Slow and Signal smoothing engines

#ifndef MACD_CALCULATOR_MQH
#define MACD_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CMACDCalculator (Base Class)                |
//+==================================================================+
class CMACDCalculator
  {
protected:
   int                       m_fast_p;
   int                       m_slow_p;
   int                       m_signal_p;
   ENUM_MA_TYPE              m_src_ma_type;
   ENUM_MA_TYPE              m_sig_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Smoothing Engines
   CMovingAverageCalculator *m_fast_ma_engine;
   CMovingAverageCalculator *m_slow_ma_engine;
   CMovingAverageCalculator *m_signal_ma_engine;

   //--- Composition Engine
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_vol_buf[];
   double                    m_fast_ma[];
   double                    m_slow_ma[];
   double                    m_macd_internal[];
   double                    m_signal_internal[];
   double                    m_hist_internal[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

   void                      ExecuteCalculation(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         const bool use_volume,
         double &macd_line[], double &signal_line[], double &histogram[]);

public:
                     CMACDCalculator(void);
   virtual                  ~CMACDCalculator(void);

   //--- Enhanced Pro Init (6 Parameters)
   bool                      Init(const int fast_p, const int slow_p, const int signal_p,
                                  const ENUM_MA_TYPE src_ma, const ENUM_MA_TYPE sig_ma,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (5 Parameters)
   bool                      Init(const int fast_p, const int slow_p, const int signal_p,
                                  const ENUM_MA_TYPE src_ma, const ENUM_MA_TYPE sig_ma)
     {
      return Init(fast_p, slow_p, signal_p, src_ma, sig_ma, PRICE_CLOSE_STD);
     }

   //--- Calculation Without Volume
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &macd_line[], double &signal_line[], double &histogram[])
     {
      ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, false, macd_line, signal_line, histogram);
     }

   //--- Calculation With Long Volume Array (Supports VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &macd_line[], double &signal_line[], double &histogram[]);

   //--- Calculation With Double Volume Array (Supports VWMA in MTF)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const double &volume[],
                                       double &macd_line[], double &signal_line[], double &histogram[]);

   //--- Legacy Overload with price_type parameter
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const ENUM_APPLIED_PRICE price_type,
                                       double &macd_line[], double &signal_line[], double &histogram[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, macd_line, signal_line, histogram);
     }

   void                      CalculateHistogramOnly(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &hist_out[]);

   void                      CalculateMACDLineOnly(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &macd_out[]);

   //--- Legacy Wrappers for Histogram and MACD Line Only with price_type
   void                      CalculateHistogramOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &hist_out[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;
      CalculateHistogramOnly(rates_total, prev_calculated, open, high, low, close, hist_out);
     }

   void                      CalculateMACDLineOnly(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &macd_out[])
     {
      if(m_source_price >= PRICE_CLOSE_STD)
         m_source_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;
      CalculateMACDLineOnly(rates_total, prev_calculated, open, high, low, close, macd_out);
     }

   int                       GetPeriodFast(void)   const { return m_fast_p; }
   int                       GetPeriodSlow(void)   const { return m_slow_p; }
   int                       GetPeriodSignal(void) const { return m_signal_p; }
   int                       GetRequiredWarmup(void) const { return m_slow_p + m_signal_p; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDCalculator::CMACDCalculator(void) : m_fast_p(12),
   m_slow_p(26),
   m_signal_p(9),
   m_src_ma_type(EMA),
   m_sig_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD)
  {
   m_fast_ma_engine   = new CMovingAverageCalculator();
   m_slow_ma_engine   = new CMovingAverageCalculator();
   m_signal_ma_engine = new CMovingAverageCalculator();

   ArraySetAsSeries(m_price,           false);
   ArraySetAsSeries(m_vol_buf,         false);
   ArraySetAsSeries(m_fast_ma,         false);
   ArraySetAsSeries(m_slow_ma,         false);
   ArraySetAsSeries(m_macd_internal,   false);
   ArraySetAsSeries(m_signal_internal, false);
   ArraySetAsSeries(m_hist_internal,   false);
   ArraySetAsSeries(m_ha_open,         false);
   ArraySetAsSeries(m_ha_high,         false);
   ArraySetAsSeries(m_ha_low,          false);
   ArraySetAsSeries(m_ha_close,        false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDCalculator::~CMACDCalculator(void)
  {
   if(CheckPointer(m_fast_ma_engine) != POINTER_INVALID)
     {
      delete m_fast_ma_engine;
      m_fast_ma_engine = NULL;
     }
   if(CheckPointer(m_slow_ma_engine) != POINTER_INVALID)
     {
      delete m_slow_ma_engine;
      m_slow_ma_engine = NULL;
     }
   if(CheckPointer(m_signal_ma_engine) != POINTER_INVALID)
     {
      delete m_signal_ma_engine;
      m_signal_ma_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CMACDCalculator::Init(const int fast_p, const int slow_p, const int signal_p,
                           const ENUM_MA_TYPE src_ma, const ENUM_MA_TYPE sig_ma,
                           const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   int f_p = (fast_p < 1) ? 1 : fast_p;
   int s_p = (slow_p < 1) ? 1 : slow_p;
   if(f_p > s_p)
     {
      int temp = f_p;
      f_p = s_p;
      s_p = temp;
     }

   m_fast_p       = f_p;
   m_slow_p       = s_p;
   m_signal_p     = (signal_p < 1) ? 1 : signal_p;
   m_src_ma_type  = src_ma;
   m_sig_ma_type  = sig_ma;
   m_source_price = price_source;

   if(CheckPointer(m_fast_ma_engine) == POINTER_INVALID || !m_fast_ma_engine.Init(m_fast_p, m_src_ma_type))
      return false;
   if(CheckPointer(m_slow_ma_engine) == POINTER_INVALID || !m_slow_ma_engine.Init(m_slow_p, m_src_ma_type))
      return false;
   if(CheckPointer(m_signal_ma_engine) == POINTER_INVALID || !m_signal_ma_engine.Init(m_signal_p, m_sig_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi)                    |
//+------------------------------------------------------------------+
bool CMACDCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);

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
               m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
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
               m_price[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
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
//| Calculate with Long Volume Overload                              |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(const int rates_total, const int prev_calculated,
                                const double &open[], const double &high[],
                                const double &low[], const double &close[],
                                const long &volume[],
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int j = start_index; j < rates_total; j++)
      m_vol_buf[j] = (volume[j] < 1) ? 1.0 : (double)volume[j];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, true, macd_line, signal_line, histogram);
  }

//+------------------------------------------------------------------+
//| Calculate with Double Volume Overload (For MTF)                  |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(const int rates_total, const int prev_calculated,
                                const double &open[], const double &high[],
                                const double &low[], const double &close[],
                                const double &volume[],
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int j = start_index; j < rates_total; j++)
      m_vol_buf[j] = (volume[j] < 1.0) ? 1.0 : volume[j];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, true, macd_line, signal_line, histogram);
  }

//+------------------------------------------------------------------+
//| Internal Calculation Engine (Handles Standard & VWMA Smoothing)  |
//+------------------------------------------------------------------+
void CMACDCalculator::ExecuteCalculation(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      const bool use_volume,
      double &macd_line[], double &signal_line[], double &histogram[])
  {
   int min_bars = m_slow_p + m_signal_p;
   if(rates_total <= min_bars || CheckPointer(m_fast_ma_engine) == POINTER_INVALID ||
      CheckPointer(m_slow_ma_engine) == POINTER_INVALID || CheckPointer(m_signal_ma_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(macd_line) != rates_total)
     {
      ArrayResize(macd_line, rates_total);
      ArraySetAsSeries(macd_line, false);
      ArrayInitialize(macd_line, EMPTY_VALUE);
     }
   if(ArraySize(signal_line) != rates_total)
     {
      ArrayResize(signal_line, rates_total);
      ArraySetAsSeries(signal_line, false);
      ArrayInitialize(signal_line, EMPTY_VALUE);
     }
   if(ArraySize(histogram) != rates_total)
     {
      ArrayResize(histogram, rates_total);
      ArraySetAsSeries(histogram, false);
      ArrayInitialize(histogram, 0.0);
     }

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,           rates_total);
      ArraySetAsSeries(m_price,           false);
      ArrayResize(m_fast_ma,         rates_total);
      ArraySetAsSeries(m_fast_ma,         false);
      ArrayResize(m_slow_ma,         rates_total);
      ArraySetAsSeries(m_slow_ma,         false);
      ArrayResize(m_macd_internal,   rates_total);
      ArraySetAsSeries(m_macd_internal,   false);
      ArrayResize(m_signal_internal, rates_total);
      ArraySetAsSeries(m_signal_internal, false);
      ArrayResize(m_hist_internal,   rates_total);
      ArraySetAsSeries(m_hist_internal,   false);
     }

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

// 1. Calculate Fast & Slow MAs (With or Without Volume)
   if(use_volume)
     {
      m_fast_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_vol_buf, m_fast_ma);
      m_slow_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_vol_buf, m_slow_ma);
     }
   else
     {
      m_fast_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_fast_ma);
      m_slow_ma_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_price, m_price, m_price, m_price, m_slow_ma);
     }

// 2. Calculate MACD Line
   int loop_start_macd = MathMax(m_slow_p - 1, start_index);

   for(int i = loop_start_macd; i < rates_total; i++)
     {
      if(m_fast_ma[i] != EMPTY_VALUE && m_slow_ma[i] != EMPTY_VALUE)
         m_macd_internal[i] = m_fast_ma[i] - m_slow_ma[i];
      else
         m_macd_internal[i] = EMPTY_VALUE;
     }

// 3. Calculate Signal Line (With or Without Volume)
   int macd_offset = m_slow_p - 1;

   if(use_volume)
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_macd_internal, m_vol_buf, m_signal_internal, macd_offset);
   else
      m_signal_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_macd_internal, m_signal_internal, macd_offset);

// 4. Calculate Histogram Difference & Output
   int signal_start = macd_offset + m_signal_p - 1;
   int loop_start_hist = MathMax(signal_start, start_index);

   for(int i = loop_start_hist; i < rates_total; i++)
     {
      if(m_macd_internal[i] != EMPTY_VALUE && m_signal_internal[i] != EMPTY_VALUE)
         m_hist_internal[i] = m_macd_internal[i] - m_signal_internal[i];
      else
         m_hist_internal[i] = 0.0;

      macd_line[i]   = m_macd_internal[i];
      signal_line[i] = m_signal_internal[i];
      histogram[i]   = m_hist_internal[i];
     }
  }

//+------------------------------------------------------------------+
//| Calculate Histogram Only                                         |
//+------------------------------------------------------------------+
void CMACDCalculator::CalculateHistogramOnly(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &hist_out[])
  {
   double dummy_macd[], dummy_signal[];
   Calculate(rates_total, prev_calculated, open, high, low, close, dummy_macd, dummy_signal, hist_out);
  }

//+------------------------------------------------------------------+
//| Calculate MACD Line Only                                         |
//+------------------------------------------------------------------+
void CMACDCalculator::CalculateMACDLineOnly(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &macd_out[])
  {
   double dummy_signal[], dummy_hist[];
   Calculate(rates_total, prev_calculated, open, high, low, close, macd_out, dummy_signal, dummy_hist);
  }

//+==================================================================+
//|             CLASS 2: CMACDCalculator_HA (Legacy Wrapper)         |
//+==================================================================+
class CMACDCalculator_HA : public CMACDCalculator
  {
public:
                     CMACDCalculator_HA(void)
     {
      m_source_price = PRICE_HA_CLOSE;
     }
  };

#endif // MACD_CALCULATOR_MQH
//+------------------------------------------------------------------+
