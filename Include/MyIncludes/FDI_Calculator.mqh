//+------------------------------------------------------------------+
//|                                            FDI_Calculator.mqh    |
//|      Engine for Fractal Dimension Index (Carlos Sevcik Method).  |
//|      VERSION 3.10: Full Heikin Ashi & Multi-Price Integration    |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.10" // Enterprise: Added Full Heikin Ashi & Universal Price Pipeline
#property description "Calculation engine for Fractal Dimension Index delegating to central CFractalEngine."

#ifndef FDI_CALCULATOR_MQH
#define FDI_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\Fractal_Engine.mqh>

//+==================================================================+
//|             CLASS: CFDICalculator                                |
//+==================================================================+
class CFDICalculator
  {
protected:
   int                       m_period;
   ENUM_FDI_METHOD           m_method;
   ENUM_APPLIED_PRICE_HA_ALL m_source_type;

   // Persistent Price Buffers
   double                    m_price[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   // Embedded Engines
   CFractalEngine            m_fractal_engine;
   CHeikinAshi_Calculator    m_ha_engine;

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CFDICalculator(void);
   virtual                  ~CFDICalculator(void);

   bool                      Init(const int period, const ENUM_FDI_METHOD method = FDI_NORMALIZED_BROWNIAN,
                                  const ENUM_APPLIED_PRICE_HA_ALL source = PRICE_CLOSE_STD);
   int                       GetPeriod(void) const { return m_period; }
   double                    GetTheoreticalRandomWalkD(void) const { return m_fractal_engine.GetTheoreticalRandomWalkD(); }

   // Main Calculation Method
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_fdi[], const int history_limit = 0);

   // Legacy 8-parameter overload (for backward compatibility with standard applied prices)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &out_fdi[], const int history_limit = 0);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFDICalculator::CFDICalculator(void) :
   m_period(30),
   m_method(FDI_NORMALIZED_BROWNIAN),
   m_source_type(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFDICalculator::~CFDICalculator(void)
  {
   ArrayFree(m_price);
   ArrayFree(m_ha_open);
   ArrayFree(m_ha_high);
   ArrayFree(m_ha_low);
   ArrayFree(m_ha_close);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CFDICalculator::Init(const int period, const ENUM_FDI_METHOD method, const ENUM_APPLIED_PRICE_HA_ALL source)
  {
   m_period      = (period < 5) ? 5 : period;
   m_method      = method;
   m_source_type = source;

// Initialize Embedded Central Fractal Engine
   if(!m_fractal_engine.Init(m_period, m_method))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Unified Standard / Heikin Ashi)            |
//+------------------------------------------------------------------+
bool CFDICalculator::PreparePriceSeries(const int rates_total, const int start_index,
                                        const double &open[], const double &high[],
                                        const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   bool is_ha = (m_source_type <= PRICE_HA_CLOSE);

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

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_type)
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
               m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.333333333333;
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
         switch(m_source_type)
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
               m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
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
//| Main Calculation (Primary Interface)                             |
//+------------------------------------------------------------------+
void CFDICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_fdi[], const int history_limit)
  {
   if(rates_total < m_period)
      return;

   if(ArraySize(out_fdi) != rates_total)
     {
      ArrayResize(out_fdi, rates_total, 2048);
      ArraySetAsSeries(out_fdi, false);
     }

   int start_prep = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PreparePriceSeries(rates_total, start_prep, open, high, low, close))
      return;

   int start_index = (prev_calculated > m_period) ? (prev_calculated - 1) : m_period;
   if(history_limit > 0 && prev_calculated == 0)
     {
      int limit_start = rates_total - history_limit;
      if(limit_start > start_index)
         start_index = limit_start;
     }

   if(prev_calculated == 0)
     {
      for(int i = 0; i < start_index; i++)
         out_fdi[i] = EMPTY_VALUE;
     }

   for(int i = start_index; i < rates_total; i++)
     {
      out_fdi[i] = m_fractal_engine.CalculateFDIPoint(i, m_period, m_price);
     }
  }

//+------------------------------------------------------------------+
//| Legacy Calculation Overload (100% Backward Compatible)           |
//+------------------------------------------------------------------+
void CFDICalculator::Calculate(const int rates_total, const int prev_calculated,
                               const ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[],
                               const double &low[], const double &close[],
                               double &out_fdi[], const int history_limit)
  {
   m_source_type = (ENUM_APPLIED_PRICE_HA_ALL)price_type;
   Calculate(rates_total, prev_calculated, open, high, low, close, out_fdi, history_limit);
  }

#endif // FDI_CALCULATOR_MQH
//+------------------------------------------------------------------+
