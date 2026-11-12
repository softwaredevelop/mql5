//+------------------------------------------------------------------+
//|                                           MFI_Calculator.mqh     |
//|      DSP Engine for Quong & Soudack's Money Flow Index (MFI)     |
//|      VERSION 1.00: 2026 Enterprise Edition with Modular 14-MA    |
//|                    Signal Line & Dynamic Volume Routing          |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef MFI_CALCULATOR_MQH
#define MFI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//| CLASS: CMFICalculator                                            |
//+==================================================================+
class CMFICalculator
  {
protected:
   int                       m_mfi_period;
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Smoothing & Composition Engines
   CMovingAverageCalculator *m_signal_engine;
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent Working Buffers
   double                    m_tp[];
   double                    m_vol_buf[];
   double                    m_pos_mf[];
   double                    m_neg_mf[];
   double                    m_mfi_internal[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   virtual bool              PrepareData(const int rates_total, const int start_index,
                                         const double &open[], const double &high[],
                                         const double &low[], const double &close[]);

   void                      ExecuteCalculation(const int rates_total, const int prev_calculated,
         const double &open[], const double &high[],
         const double &low[], const double &close[],
         double &mfi_out[], double &signal_out[]);

public:
                     CMFICalculator(void);
   virtual                  ~CMFICalculator(void);

   bool                      Init(const int mfi_period, const int signal_period,
                                  const ENUM_MA_TYPE signal_ma_type,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Overloaded Calculate for Long Volume (Native Tick / Real Volume)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const long &volume[],
                                       double &mfi_out[], double &signal_out[]);

   //--- Overloaded Calculate for Double Volume (MTF Volume Routing)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       const double &volume[],
                                       double &mfi_out[], double &signal_out[]);

   int                       GetMFIPeriod(void)    const { return m_mfi_period; }
   int                       GetSignalPeriod(void) const { return m_signal_period; }
   ENUM_MA_TYPE              GetSignalMAType(void) const { return m_signal_ma_type; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMFICalculator::CMFICalculator(void) : m_mfi_period(14),
   m_signal_period(9),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD),
   m_signal_engine(NULL)
  {
   m_signal_engine = new CMovingAverageCalculator();

   ArraySetAsSeries(m_tp,           false);
   ArraySetAsSeries(m_vol_buf,      false);
   ArraySetAsSeries(m_pos_mf,       false);
   ArraySetAsSeries(m_neg_mf,       false);
   ArraySetAsSeries(m_mfi_internal, false);
   ArraySetAsSeries(m_ha_open,      false);
   ArraySetAsSeries(m_ha_high,      false);
   ArraySetAsSeries(m_ha_low,       false);
   ArraySetAsSeries(m_ha_close,     false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMFICalculator::~CMFICalculator(void)
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
bool CMFICalculator::Init(const int mfi_period, const int signal_period,
                          const ENUM_MA_TYPE signal_ma_type,
                          const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_mfi_period     = MathMax(1, mfi_period);
   m_signal_period  = MathMax(1, signal_period);
   m_signal_ma_type = signal_ma_type;
   m_source_price   = price_source;

   if(CheckPointer(m_signal_engine) == POINTER_INVALID ||
      !m_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Data (Typical Price Derivation)                    |
//+------------------------------------------------------------------+
bool CMFICalculator::PrepareData(const int rates_total, const int start_index,
                                 const double &open[], const double &high[],
                                 const double &low[], const double &close[])
  {
   if(ArraySize(m_tp) != rates_total)
     {
      ArrayResize(m_tp, rates_total, 2048);
      ArraySetAsSeries(m_tp, false);
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
               m_tp[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_tp[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_tp[i] = m_ha_low[i];
               break;
            case PRICE_HA_CLOSE:
               m_tp[i] = m_ha_close[i];
               break;
            case PRICE_HA_MEDIAN:
               m_tp[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
               break;
            case PRICE_HA_WEIGHTED:
               m_tp[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
               break;
            case PRICE_HA_TYPICAL:
            default:
               m_tp[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
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
               m_tp[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_tp[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_tp[i] = low[i];
               break;
            case PRICE_CLOSE_STD:
               m_tp[i] = close[i];
               break;
            case PRICE_MEDIAN_STD:
               m_tp[i] = (high[i] + low[i]) * 0.5;
               break;
            case PRICE_WEIGHTED_STD:
               m_tp[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
               break;
            case PRICE_TYPICAL_STD:
            default:
               m_tp[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
               break;
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate with Long Volume (Native Tick / Real Volume)           |
//+------------------------------------------------------------------+
void CMFICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const long &volume[],
                               double &mfi_out[], double &signal_out[])
  {
   if(rates_total <= m_mfi_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total, 2048);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int k = start_index; k < rates_total; k++)
      m_vol_buf[k] = (volume[k] < 1) ? 1.0 : (double)volume[k];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, mfi_out, signal_out);
  }

//+------------------------------------------------------------------+
//| Calculate with Double Volume (MTF Volume Routing)                |
//+------------------------------------------------------------------+
void CMFICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               const double &volume[],
                               double &mfi_out[], double &signal_out[])
  {
   if(rates_total <= m_mfi_period)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_vol_buf) != rates_total)
     {
      ArrayResize(m_vol_buf, rates_total, 2048);
      ArraySetAsSeries(m_vol_buf, false);
     }

   for(int k = start_index; k < rates_total; k++)
      m_vol_buf[k] = (volume[k] < 1.0) ? 1.0 : volume[k];

   ExecuteCalculation(rates_total, prev_calculated, open, high, low, close, mfi_out, signal_out);
  }

//+------------------------------------------------------------------+
//| Core Execution Pipeline (Algebraic Zero-Division Shield)         |
//+------------------------------------------------------------------+
void CMFICalculator::ExecuteCalculation(const int rates_total, const int prev_calculated,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[],
                                        double &mfi_out[], double &signal_out[])
  {
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_pos_mf) != rates_total)
     {
      ArrayResize(m_pos_mf,       rates_total, 2048);
      ArrayResize(m_neg_mf,       rates_total, 2048);
      ArrayResize(m_mfi_internal, rates_total, 2048);

      ArraySetAsSeries(m_pos_mf,       false);
      ArraySetAsSeries(m_neg_mf,       false);
      ArraySetAsSeries(m_mfi_internal, false);
     }

// Prepare Typical Price vector
   if(!PrepareData(rates_total, start_index, open, high, low, close))
      return;

   int i = start_index;
   if(i == 0)
     {
      m_pos_mf[0]       = 0.0;
      m_neg_mf[0]       = 0.0;
      m_mfi_internal[0] = 50.0;
      mfi_out[0]        = 50.0;
      i = 1;
     }

// 1. Calculate Raw Money Flow Polarity
   for(; i < rates_total; i++)
     {
      double rmf = m_tp[i] * m_vol_buf[i];

      if(m_tp[i] > m_tp[i - 1])
        {
         m_pos_mf[i] = rmf;
         m_neg_mf[i] = 0.0;
        }
      else
         if(m_tp[i] < m_tp[i - 1])
           {
            m_pos_mf[i] = 0.0;
            m_neg_mf[i] = rmf;
           }
         else
           {
            m_pos_mf[i] = 0.0;
            m_neg_mf[i] = 0.0;
           }

      // 2. Window Summation & Algebraic Zero-Division Immune Formula
      if(i < m_mfi_period)
        {
         m_mfi_internal[i] = 50.0;
         mfi_out[i]        = 50.0;
        }
      else
        {
         double pos_sum = 0.0;
         double neg_sum = 0.0;

         for(int j = 0; j < m_mfi_period; j++)
           {
            pos_sum += m_pos_mf[i - j];
            neg_sum += m_neg_mf[i - j];
           }

         double total_flow = pos_sum + neg_sum;
         if(total_flow > 0.0)
            m_mfi_internal[i] = (100.0 * pos_sum) / total_flow;
         else
            m_mfi_internal[i] = 50.0;

         mfi_out[i] = m_mfi_internal[i];
        }
     }

// 3. Compute 14-Model Signal Line over the MFI Series
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_mfi_internal, signal_out, m_mfi_period);
  }

#endif // MFI_CALCULATOR_MQH
//+------------------------------------------------------------------+
