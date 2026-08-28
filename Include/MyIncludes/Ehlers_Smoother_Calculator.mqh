//+------------------------------------------------------------------+
//|                                   Ehlers_Smoother_Calculator.mqh |
//|      Engine for John Ehlers' SuperSmoother & UltimateSmoother    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.25" // 100% Backward Compatible & Robust Composition DSP Engine

#ifndef EHLERS_SMOOTHER_CALCULATOR_MQH
#define EHLERS_SMOOTHER_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

#ifndef ENUM_SMOOTHER_DEFINITIONS_DEFINED
#define ENUM_SMOOTHER_DEFINITIONS_DEFINED
enum ENUM_SMOOTHER_TYPE { SUPERSMOOTHER, ULTIMATESMOOTHER };
enum ENUM_INPUT_SOURCE  { SOURCE_PRICE, SOURCE_MOMENTUM };
#endif

//+==================================================================+
//|             CLASS 1: CEhlersSmootherCalculator                   |
//+==================================================================+
class CEhlersSmootherCalculator
  {
protected:
   int                       m_period;
   ENUM_SMOOTHER_TYPE        m_type;
   ENUM_INPUT_SOURCE         m_source_type;
   ENUM_APPLIED_PRICE_HA_ALL m_applied_price;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   //--- Embedded Composition Engine
   CHeikinAshi_Calculator    m_ha_engine;

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CEhlersSmootherCalculator(void);
   virtual                  ~CEhlersSmootherCalculator(void) {};

   //--- Enhanced Pro Init (4 Parameters)
   bool                      Init(const int period, const ENUM_SMOOTHER_TYPE type,
                                  const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (3 Parameters)
   bool                      Init(const int period, const ENUM_SMOOTHER_TYPE type, const ENUM_INPUT_SOURCE source_type)
     {
      return Init(period, type, source_type, PRICE_CLOSE_STD);
     }

   //--- Modern Unified Calculation Method
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &filter_buffer[]);

   //--- Legacy Overload (With explicit price_type parameter)
   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &filter_buffer[])
     {
      // Preserve dynamic applied price passed from legacy caller
      if(m_applied_price >= PRICE_CLOSE_STD)
         m_applied_price = (ENUM_APPLIED_PRICE_HA_ALL)price_type;

      Calculate(rates_total, prev_calculated, open, high, low, close, filter_buffer);
     }

   int                       GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersSmootherCalculator::CEhlersSmootherCalculator(void) : m_period(20),
   m_type(SUPERSMOOTHER),
   m_source_type(SOURCE_PRICE),
   m_applied_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_price,    false);
   ArraySetAsSeries(m_ha_open,  false);
   ArraySetAsSeries(m_ha_high,  false);
   ArraySetAsSeries(m_ha_low,   false);
   ArraySetAsSeries(m_ha_close, false);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::Init(const int period, const ENUM_SMOOTHER_TYPE type,
                                     const ENUM_INPUT_SOURCE source_type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period        = (period < 2) ? 2 : period;
   m_type          = type;
   m_source_type   = source_type;
   m_applied_price = price_source;
   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard / Heikin Ashi / Momentum)         |
//+------------------------------------------------------------------+
bool CEhlersSmootherCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

   bool is_heikin_ashi = (m_applied_price <= PRICE_HA_CLOSE);

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
         if(m_source_type == SOURCE_PRICE)
           {
            switch(m_applied_price)
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
         else // SOURCE_MOMENTUM
           {
            m_price[i] = m_ha_close[i] - m_ha_open[i];
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         if(m_source_type == SOURCE_PRICE)
           {
            switch(m_applied_price)
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
         else // SOURCE_MOMENTUM
           {
            m_price[i] = close[i] - open[i];
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CEhlersSmootherCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &filter_buffer[])
  {
   if(rates_total < 4)
      return;

//--- Safe allocation of destination array
   if(ArraySize(filter_buffer) != rates_total)
     {
      ArrayResize(filter_buffer, rates_total);
      ArraySetAsSeries(filter_buffer, false);
      ArrayInitialize(filter_buffer, EMPTY_VALUE);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

//--- Calculate Analytical DSP Filter Coefficients
   double a1 = MathExp(-M_SQRT2 * M_PI / (double)m_period);
   double b1 = 2.0 * a1 * MathCos(M_SQRT2 * M_PI / (double)m_period);
   double c2 = b1;
   double c3 = -a1 * a1;
   double c1 = (m_type == SUPERSMOOTHER) ? (1.0 - c2 - c3) : ((1.0 + c2 - c3) / 4.0);

   int loop_start = MathMax(3, start_index);

// Initialization for the seed bars on fresh run
   if(prev_calculated == 0 || loop_start == 3)
     {
      filter_buffer[0] = m_price[0];
      filter_buffer[1] = m_price[1];
      filter_buffer[2] = m_price[2];
     }

// Recursive 2-Pole Difference Equation
   for(int i = loop_start; i < rates_total; i++)
     {
      double f1 = filter_buffer[i - 1];
      double f2 = filter_buffer[i - 2];

      double current_f;
      if(m_type == SUPERSMOOTHER)
         current_f = c1 * (m_price[i] + m_price[i - 1]) / 2.0 + c2 * f1 + c3 * f2;
      else // ULTIMATESMOOTHER
         current_f = (1.0 - c1) * m_price[i] + (2.0 * c1 - c2) * m_price[i - 1] - (c1 + c3) * m_price[i - 2] + c2 * f1 + c3 * f2;

      filter_buffer[i] = current_f;
     }
  }

//+==================================================================+
//|             CLASS 2: CEhlersSmootherCalculator_HA (Legacy Wrapp) |
//+==================================================================+
class CEhlersSmootherCalculator_HA : public CEhlersSmootherCalculator
  {
public:
                     CEhlersSmootherCalculator_HA(void)
     {
      m_applied_price = PRICE_HA_CLOSE;
     }
  };

#endif // EHLERS_SMOOTHER_CALCULATOR_MQH
//+------------------------------------------------------------------+
