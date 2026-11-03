//+------------------------------------------------------------------+
//|                                         MovingAverage_Engine.mqh |
//|                 Universal Modular Facade & Memory Router         |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.60" // Fully Modularized Component-Based Architecture

#ifndef MOVING_AVERAGE_ENGINE_MQH
#define MOVING_AVERAGE_ENGINE_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Include Validated Core Algorithms from Dedicated Component Files
#include <MyIncludes\MACalculators\Base_Calculator.mqh>
#include <MyIncludes\MACalculators\SMA_Calculator.mqh>
#include <MyIncludes\MACalculators\EMA_Calculator.mqh>
#include <MyIncludes\MACalculators\SMMA_Calculator.mqh>
#include <MyIncludes\MACalculators\LWMA_Calculator.mqh>
#include <MyIncludes\MACalculators\TMA_Calculator.mqh>
#include <MyIncludes\MACalculators\DEMA_Calculator.mqh>
#include <MyIncludes\MACalculators\TEMA_Calculator.mqh>
#include <MyIncludes\MACalculators\VWMA_Calculator.mqh>
#include <MyIncludes\MACalculators\HMA_Calculator.mqh>

//--- Validated Algorithm Enums
#ifndef ENUM_MA_TYPE_DEFINED
#define ENUM_MA_TYPE_DEFINED
enum ENUM_MA_TYPE
  {
   SMA,
   EMA,
   SMMA,
   LWMA,
   TMA,
   DEMA,
   TEMA,
   VWMA,
   HMA
  };
#endif

//+==================================================================+
//| CLASS: CMovingAverageCalculator (Unified Facade)                 |
//+==================================================================+
class CMovingAverageCalculator
  {
protected:
   int                m_period;
   ENUM_MA_TYPE       m_ma_type;
   CBaseMACalculator *m_algo;

   //--- Persistent Calculation Scratchpads
   double             m_price[];
   double             m_volume[];

   virtual bool       PreparePriceSeries(const int rates_total,
                                         const int start_index,
                                         const ENUM_APPLIED_PRICE price_type,
                                         const double &open[],
                                         const double &high[],
                                         const double &low[],
                                         const double &close[]);

   bool               CreateAlgorithm(const ENUM_MA_TYPE ma_type);

public:
                     CMovingAverageCalculator(void);
   virtual           ~CMovingAverageCalculator(void);

   bool               Init(const int period, const ENUM_MA_TYPE ma_type);

   //--- Standard Calculation (OHLC input - No Volume, legacy compatible)
   void               Calculate(const int rates_total,
                                const int prev_calculated,
                                const ENUM_APPLIED_PRICE price_type,
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[],
                                double &ma_buffer[]);

   //--- Overloaded Calculation with Volume (Specifically for VWMA support, long[] Volume)
   void               Calculate(const int rates_total,
                                const int prev_calculated,
                                const ENUM_APPLIED_PRICE price_type,
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[],
                                const long &volume[],
                                double &ma_buffer[]);

   //--- Overloaded Calculation with Double Volume (MTF VWMA)
   void               Calculate(const int rates_total,
                                const int prev_calculated,
                                const ENUM_APPLIED_PRICE price_type,
                                const double &open[],
                                const double &high[],
                                const double &low[],
                                const double &close[],
                                const double &volume[],
                                double &ma_buffer[]);

   //--- Calculation on Custom Array (No Volume)
   void               CalculateOnArray(const int rates_total,
                                       const int prev_calculated,
                                       const double &src_buffer[],
                                       double &output_buffer[],
                                       const int src_start_index = 0);

   //--- Overloaded Calculation on Custom Array with Volume (VWMA Signals)
   void               CalculateOnArray(const int rates_total,
                                       const int prev_calculated,
                                       const double &src_buffer[],
                                       const double &volume_buffer[],
                                       double &output_buffer[],
                                       const int src_start_index = 0);

   int                GetPeriod(void)     const { return m_period; }
   ENUM_MA_TYPE       GetMAType(void)     const { return m_ma_type; }
   int                GetDrawBegin(void)  const { return (m_algo != NULL) ? m_algo.GetWarmupBars() : (m_period - 1); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMovingAverageCalculator::CMovingAverageCalculator(void) : m_period(20),
   m_ma_type(SMA),
   m_algo(NULL)
  {
   ArraySetAsSeries(m_price,  false);
   ArraySetAsSeries(m_volume, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMovingAverageCalculator::~CMovingAverageCalculator(void)
  {
   if(CheckPointer(m_algo) != POINTER_INVALID && m_algo != NULL)
     {
      delete m_algo;
      m_algo = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Algorithm Factory: Pluggable Component Instantiation             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::CreateAlgorithm(const ENUM_MA_TYPE ma_type)
  {
   if(CheckPointer(m_algo) != POINTER_INVALID && m_algo != NULL)
     {
      delete m_algo;
      m_algo = NULL;
     }

   switch(ma_type)
     {
      case EMA:
         m_algo = new CEMACalculator();
         break;
      case SMMA:
         m_algo = new CSMMACalculator();
         break;
      case LWMA:
         m_algo = new CLWMACalculator();
         break;
      case TMA:
         m_algo = new CTMACalculator();
         break;
      case DEMA:
         m_algo = new CDEMACalculator();
         break;
      case TEMA:
         m_algo = new CTEMACalculator();
         break;
      case VWMA:
         m_algo = new CVWMACalculator();
         break;
      case HMA:
         m_algo = new CHMACalculator();
         break;
      case SMA:
      default:
         m_algo = new CSMACalculator();
         break;
     }

   if(CheckPointer(m_algo) == POINTER_INVALID || m_algo == NULL)
      return false;

   return m_algo.Init(m_period);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::Init(const int period, const ENUM_MA_TYPE ma_type)
  {
   m_period  = (period < 1) ? 1 : period;
   m_ma_type = ma_type;
   return CreateAlgorithm(m_ma_type);
  }

//+------------------------------------------------------------------+
//| Calculate (Standard OHLC - No Volume)                            |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total,
      const int prev_calculated,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      double &ma_buffer[])
  {
   if(rates_total < m_period || m_algo == NULL)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   if(m_ma_type == VWMA)
     {
      if(ArraySize(m_volume) != rates_total)
        {
         ArrayResize(m_volume, rates_total, 2048);
         ArraySetAsSeries(m_volume, false);
        }
      for(int i = start_index; i < rates_total; i++)
         m_volume[i] = 1.0;
     }

   m_algo.Calculate(rates_total, start_index, m_price, m_volume, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Calculate (With Long Volume)                                     |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total,
      const int prev_calculated,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      const long &volume[],
      double &ma_buffer[])
  {
   if(rates_total < m_period || m_algo == NULL)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total, 2048);
      ArraySetAsSeries(m_volume, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (volume[i] < 1) ? 1.0 : (double)volume[i];

   m_algo.Calculate(rates_total, start_index, m_price, m_volume, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| Calculate (With Double Volume)                                   |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::Calculate(const int rates_total,
      const int prev_calculated,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      const double &volume[],
      double &ma_buffer[])
  {
   if(rates_total < m_period || m_algo == NULL)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total, 2048);
      ArraySetAsSeries(m_volume, false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (volume[i] < 1.0) ? 1.0 : volume[i];

   m_algo.Calculate(rates_total, start_index, m_price, m_volume, ma_buffer, 0);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Custom Array - No Volume)                      |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(const int rates_total,
      const int prev_calculated,
      const double &src_buffer[],
      double &output_buffer[],
      const int src_start_index)
  {
   if(rates_total < src_start_index + m_period || m_algo == NULL)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   if(m_ma_type == VWMA)
     {
      if(ArraySize(m_volume) != rates_total)
        {
         ArrayResize(m_volume, rates_total, 2048);
         ArraySetAsSeries(m_volume, false);
        }
      for(int i = start_index; i < rates_total; i++)
         m_volume[i] = 1.0;
     }

   int copy_start = MathMax(start_index, src_start_index);
   for(int i = copy_start; i < rates_total; i++)
      m_price[i] = src_buffer[i];

   m_algo.Calculate(rates_total, start_index, m_price, m_volume, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| CalculateOnArray (Custom Array With Volume)                      |
//+------------------------------------------------------------------+
void CMovingAverageCalculator::CalculateOnArray(const int rates_total,
      const int prev_calculated,
      const double &src_buffer[],
      const double &volume_buffer[],
      double &output_buffer[],
      const int src_start_index)
  {
   if(rates_total < src_start_index + m_period || m_algo == NULL)
      return;

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total, 2048);
      ArraySetAsSeries(m_price, false);
     }

   if(ArraySize(m_volume) != rates_total)
     {
      ArrayResize(m_volume, rates_total, 2048);
      ArraySetAsSeries(m_volume, false);
     }

   int copy_start = MathMax(start_index, src_start_index);
   int vol_size   = ArraySize(volume_buffer);

   for(int i = copy_start; i < rates_total; i++)
     {
      m_price[i] = src_buffer[i];
      if(i < vol_size)
         m_volume[i] = (volume_buffer[i] < 1.0) ? 1.0 : volume_buffer[i];
      else
         m_volume[i] = 1.0;
     }

   m_algo.Calculate(rates_total, start_index, m_price, m_volume, output_buffer, src_start_index);
  }

//+------------------------------------------------------------------+
//| PreparePriceSeries (Standard Market Data)                        |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator::PreparePriceSeries(const int rates_total,
      const int start_index,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//| CLASS: CMovingAverageCalculator_HA (Heikin Ashi Specialization)  |
//+==================================================================+
class CMovingAverageCalculator_HA : public CMovingAverageCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[];
   double                 m_ha_high[];
   double                 m_ha_low[];
   double                 m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total,
         const int start_index,
         const ENUM_APPLIED_PRICE price_type,
         const double &open[],
         const double &high[],
         const double &low[],
         const double &close[]) override;

public:
                     CMovingAverageCalculator_HA(void)
     {
      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }
  };

//+------------------------------------------------------------------+
//| PreparePriceSeries for Heikin Ashi                               |
//+------------------------------------------------------------------+
bool CMovingAverageCalculator_HA::PreparePriceSeries(const int rates_total,
      const int start_index,
      const ENUM_APPLIED_PRICE price_type,
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[])
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

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // MOVING_AVERAGE_ENGINE_MQH
//+------------------------------------------------------------------+
