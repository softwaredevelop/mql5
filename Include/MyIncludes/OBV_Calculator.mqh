//+------------------------------------------------------------------+
//|                                           OBV_Calculator.mqh     |
//|      DSP Engine for Joseph Granville's On Balance Volume (OBV)   |
//|      VERSION 1.00: 2026 Enterprise Edition with Modular 14-MA    |
//|                    Signal Line & Dynamic Volume Routing          |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef OBV_CALCULATOR_MQH
#define OBV_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//| CLASS: COBVCalculator                                            |
//+==================================================================+
class COBVCalculator
  {
protected:
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Smoothing & Composition Engines
   CMovingAverageCalculator *m_signal_engine;
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent Working Buffers
   double                    m_price[];
   double                    m_vol_buf[];
   double                    m_obv_internal[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PrepareData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

   void                      ExecuteCalculation(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &obv_out[], double &signal_out[]);

public:
                     COBVCalculator(void);
   virtual                  ~COBVCalculator(void);

   bool                      Init(const int signal_period, const ENUM_MA_TYPE signal_ma_type,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Overloaded Calculate for Long Volume (Native Tick / Real Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &obv_out[], double &signal_out[]);

   //--- Overloaded Calculate for Double Volume (MTF Volume Routing)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const double &volume[],
                                       double &obv_out[], double &signal_out[]);

   int                       GetSignalPeriod(void) const { return m_signal_period; }
   ENUM_MA_TYPE              GetSignalMAType(void) const { return m_signal_ma_type; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COBVCalculator::COBVCalculator(void) : m_signal_period(20),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD),
   m_signal_engine(NULL)
  {
   m_signal_engine = new CMovingAverageCalculator();

   ArraySetAsSeries(m_price,        false);
   ArraySetAsSeries(m_vol_buf,      false);
   ArraySetAsSeries(m_obv_internal, false);
   ArraySetAsSeries(m_ha_open,      false);
   ArraySetAsSeries(m_ha_high,      false);
   ArraySetAsSeries(m_ha_low,       false);
   ArraySetAsSeries(m_ha_close,     false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COBVCalculator::~COBVCalculator(void)
  {
   if(CheckPointer(m_signal_engine) != POINTER_INVALID && m_signal_engine != NULL)
     {
      delete m_signal_engine;
      m_signal_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool COBVCalculator::Init(const int signal_period, const ENUM_MA_TYPE signal_ma_type,
                          const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_signal_period  = MathMax(1, signal_period);
   m_signal_ma_type = signal_ma_type;
   m_source_price   = price_source;

   if(CheckPointer(m_signal_engine) == POINTER_INVALID ||
      !m_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Data (Standard or Synthetic Heikin Ashi)           |
//+------------------------------------------------------------------+
bool COBVCalculator::PrepareData(const int rates_total, const int start_index,
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
//| Calculate with Long Volume (Native Tick / Real Volume)           |
//+------------------------------------------------------------------+
void COBVCalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const long &volume[],
                               double &obv_out[], double &signal_out[])
  {
   if(rates_total < 2)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total, 2048);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int k = start_index; k < rates_total; k++)
      m_vol_buf[k] = (volume[k] < 1) ? 1.0 : (double)volume[k];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, obv_out, signal_out);
  }

//+------------------------------------------------------------------+
//| Calculate with Double Volume (MTF Volume Routing)                |
//+------------------------------------------------------------------+
void COBVCalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const double &volume[],
                               double &obv_out[], double &signal_out[])
  {
   if(rates_total < 2)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total, 2048);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int k = start_index; k < rates_total; k++)
      m_vol_buf[k] = (volume[k] < 1.0) ? 1.0 : volume[k];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, obv_out, signal_out);
  }

//+------------------------------------------------------------------+
//| Core Execution Pipeline (O(1) Stateful Cumulative Walk)          |
//+------------------------------------------------------------------+
void COBVCalculator::ExecuteCalculation(const int rates_total, const int prev_calculated,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &obv_out[], double &signal_out[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_obv_internal) != rates_total)
     {
      ArrayResize(m_obv_internal, rates_total, 2048);
      ArraySetAsSeries(m_obv_internal, false);
     }

   if(!PrepareData(rates_total, start_index, open, high, low, close))
      return;

   int i = start_index;

// 1. Bar 0 Initialization
   if(i == 0)
     {
      m_obv_internal[0] = m_vol_buf[0];
      obv_out[0]        = m_obv_internal[0];
      i = 1;
     }

// 2. Incremental Cumulative Walk
   for(; i < rates_total; i++)
     {
      double prev_obv = m_obv_internal[i - 1];

      if(m_price[i] > m_price[i - 1])
         m_obv_internal[i] = prev_obv + m_vol_buf[i];
      else
         if(m_price[i] < m_price[i - 1])
            m_obv_internal[i] = prev_obv - m_vol_buf[i];
         else
            m_obv_internal[i] = prev_obv;

      obv_out[i] = m_obv_internal[i];
     }

// 3. Compute 14-Model Signal Line over the OBV Series
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_obv_internal, signal_out, 0);
  }

#endif // OBV_CALCULATOR_MQH
//+------------------------------------------------------------------+
