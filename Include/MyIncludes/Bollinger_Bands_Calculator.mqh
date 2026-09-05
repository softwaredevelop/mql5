//+------------------------------------------------------------------+
//|                                   Bollinger_Bands_Calculator.mqh |
//|      Engine for John Bollinger's Classic Bollinger Bands         |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00" // Leak-free pointer lifecycle, bounds protection & full VWMA routing

#ifndef BOLLINGER_BANDS_CALCULATOR_MQH
#define BOLLINGER_BANDS_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|          CLASS 1: CBollingerBandsCalculator (Base Class)         |
//+==================================================================+
class CBollingerBandsCalculator
  {
protected:
   int                       m_period;
   double                    m_deviation;
   ENUM_MA_TYPE              m_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Composition Engine
   CMovingAverageCalculator *m_ma_engine;

   //--- Persistent State Buffers
   double                    m_price[];
   double                    m_ma_buffer[];

   virtual bool              PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);

   virtual void              CreateEngine(void);

public:
                     CBollingerBandsCalculator(void);
   virtual                  ~CBollingerBandsCalculator(void);

   //--- Enhanced Pro Init (4 Parameters)
   bool                      Init(const int period, const double deviation, const ENUM_MA_TYPE ma_type, const ENUM_APPLIED_PRICE_HA_ALL price_source);

   //--- Legacy Compatible Init (3 Parameters)
   bool                      Init(const int period, const double deviation, const ENUM_MA_TYPE ma_type)
     {
      return Init(period, deviation, ma_type, PRICE_CLOSE_STD);
     }

   //--- Standard Calculate (Without Volume)
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &ma_out[], double &upper_out[], double &lower_out[]);

   //--- Overloaded Calculate with Long Volume (For VWMA Support)
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const long &volume[],
                                       double &ma_out[], double &upper_out[], double &lower_out[]);

   //--- Overloaded Calculate with Double Volume (For MTF VWMA)
   void                      Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const double &volume[],
                                       double &ma_out[], double &upper_out[], double &lower_out[]);

   void                      GetPriceBuffer(double &dest_array[]);
   int                       GetPeriod(void) const { return m_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBollingerBandsCalculator::CBollingerBandsCalculator(void) : m_period(20),
   m_deviation(2.0),
   m_ma_type(SMA),
   m_source_price(PRICE_CLOSE_STD),
   m_ma_engine(NULL)
  {
   ArraySetAsSeries(m_price,     false);
   ArraySetAsSeries(m_ma_buffer, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBollingerBandsCalculator::~CBollingerBandsCalculator(void)
  {
   if(CheckPointer(m_ma_engine) != POINTER_INVALID)
     {
      delete m_ma_engine;
      m_ma_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Factory Method (Virtual)                                         |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::CreateEngine(void)
  {
   if(CheckPointer(m_ma_engine) != POINTER_INVALID)
     {
      delete m_ma_engine;
      m_ma_engine = NULL;
     }
   m_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Enhanced Pro Initialization                                      |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator::Init(const int period, const double deviation, const ENUM_MA_TYPE ma_type, const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_period       = (period < 1) ? 1 : period;
   m_deviation    = deviation;
   m_ma_type      = ma_type;
   m_source_price = price_source;

   CreateEngine();
   if(CheckPointer(m_ma_engine) == POINTER_INVALID || !m_ma_engine.Init(m_period, m_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series (Standard - Optimized)                      |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total < m_period || CheckPointer(m_ma_engine) == POINTER_INVALID)
      return;

// Safe allocation of destination arrays
   if(ArraySize(ma_out) != rates_total)
     {
      ArrayResize(ma_out, rates_total);
      ArraySetAsSeries(ma_out, false);
      ArrayInitialize(ma_out, EMPTY_VALUE);
     }
   if(ArraySize(upper_out) != rates_total)
     {
      ArrayResize(upper_out, rates_total);
      ArraySetAsSeries(upper_out, false);
      ArrayInitialize(upper_out, EMPTY_VALUE);
     }
   if(ArraySize(lower_out) != rates_total)
     {
      ArrayResize(lower_out, rates_total);
      ArraySetAsSeries(lower_out, false);
      ArrayInitialize(lower_out, EMPTY_VALUE);
     }

// Resize internal buffers
   if(ArraySize(m_ma_buffer) != rates_total)
     {
      ArrayResize(m_ma_buffer, rates_total);
      ArraySetAsSeries(m_ma_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

// 1. Prepare Price Series
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Calculate Centerline MA
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_price, m_ma_buffer, 0);

// 3. Clean invalid warmup range on fresh calculation
   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_period - 1; i++)
        {
         ma_out[i]    = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
        }
     }

   int loop_start = MathMax(m_period - 1, start_index);

// 4. Calculate Rolling Standard Deviation Bands
   for(int i = loop_start; i < rates_total; i++)
     {
      double current_mean = m_ma_buffer[i];
      if(current_mean == EMPTY_VALUE)
        {
         ma_out[i] = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
         continue;
        }

      double sum_sq = 0.0;
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i - j] - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev_val = MathSqrt(sum_sq / (double)m_period);

      ma_out[i]    = current_mean;
      upper_out[i] = current_mean + m_deviation * std_dev_val;
      lower_out[i] = current_mean - m_deviation * std_dev_val;
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Long Volume for VWMA)               |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total < m_period || CheckPointer(m_ma_engine) == POINTER_INVALID)
      return;

   if(ArraySize(ma_out) != rates_total)
     {
      ArrayResize(ma_out, rates_total);
      ArraySetAsSeries(ma_out, false);
      ArrayInitialize(ma_out, EMPTY_VALUE);
     }
   if(ArraySize(upper_out) != rates_total)
     {
      ArrayResize(upper_out, rates_total);
      ArraySetAsSeries(upper_out, false);
      ArrayInitialize(upper_out, EMPTY_VALUE);
     }
   if(ArraySize(lower_out) != rates_total)
     {
      ArrayResize(lower_out, rates_total);
      ArraySetAsSeries(lower_out, false);
      ArrayInitialize(lower_out, EMPTY_VALUE);
     }

   if(ArraySize(m_ma_buffer) != rates_total)
     {
      ArrayResize(m_ma_buffer, rates_total);
      ArraySetAsSeries(m_ma_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Convert volume for VWMA
   double vol_double[];
   ArrayResize(vol_double, rates_total);
   ArraySetAsSeries(vol_double, false);
   for(int k = start_index; k < rates_total; k++)
      vol_double[k] = (volume[k] < 1) ? 1.0 : (double)volume[k];

// 2. Calculate Centerline MA with Volume
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_price, vol_double, m_ma_buffer, 0);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_period - 1; i++)
        {
         ma_out[i]    = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
        }
     }

   int loop_start = MathMax(m_period - 1, start_index);

// 3. Calculate Rolling Standard Deviation Bands
   for(int i = loop_start; i < rates_total; i++)
     {
      double current_mean = m_ma_buffer[i];
      if(current_mean == EMPTY_VALUE)
        {
         ma_out[i] = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
         continue;
        }

      double sum_sq = 0.0;
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i - j] - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev_val = MathSqrt(sum_sq / (double)m_period);

      ma_out[i]    = current_mean;
      upper_out[i] = current_mean + m_deviation * std_dev_val;
      lower_out[i] = current_mean - m_deviation * std_dev_val;
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Double Volume for MTF VWMA)         |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const double &volume[],
      double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total < m_period || CheckPointer(m_ma_engine) == POINTER_INVALID)
      return;

   if(ArraySize(ma_out) != rates_total)
     {
      ArrayResize(ma_out, rates_total);
      ArraySetAsSeries(ma_out, false);
      ArrayInitialize(ma_out, EMPTY_VALUE);
     }
   if(ArraySize(upper_out) != rates_total)
     {
      ArrayResize(upper_out, rates_total);
      ArraySetAsSeries(upper_out, false);
      ArrayInitialize(upper_out, EMPTY_VALUE);
     }
   if(ArraySize(lower_out) != rates_total)
     {
      ArrayResize(lower_out, rates_total);
      ArraySetAsSeries(lower_out, false);
      ArrayInitialize(lower_out, EMPTY_VALUE);
     }

   if(ArraySize(m_ma_buffer) != rates_total)
     {
      ArrayResize(m_ma_buffer, rates_total);
      ArraySetAsSeries(m_ma_buffer, false);
     }

   int start_index = (prev_calculated == 0) ? 0 : (prev_calculated - 1);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Calculate Centerline MA with Double Volume Array
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_price, volume, m_ma_buffer, 0);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < m_period - 1; i++)
        {
         ma_out[i]    = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
        }
     }

   int loop_start = MathMax(m_period - 1, start_index);

// Calculate Rolling Standard Deviation Bands
   for(int i = loop_start; i < rates_total; i++)
     {
      double current_mean = m_ma_buffer[i];
      if(current_mean == EMPTY_VALUE)
        {
         ma_out[i] = EMPTY_VALUE;
         upper_out[i] = EMPTY_VALUE;
         lower_out[i] = EMPTY_VALUE;
         continue;
        }

      double sum_sq = 0.0;
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i - j] - current_mean;
         sum_sq += diff * diff;
        }

      double std_dev_val = MathSqrt(sum_sq / (double)m_period);

      ma_out[i]    = current_mean;
      upper_out[i] = current_mean + m_deviation * std_dev_val;
      lower_out[i] = current_mean - m_deviation * std_dev_val;
     }
  }

//+------------------------------------------------------------------+
//| Get Internal Price Buffer                                        |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::GetPriceBuffer(double &dest_array[])
  {
   int size = ArraySize(m_price);
   if(size > 0)
     {
      ArrayResize(dest_array, size);
      ArraySetAsSeries(dest_array, false);
      ArrayCopy(dest_array, m_price, 0, 0, size);
     }
  }

//+==================================================================+
//|             CLASS 2: CBollingerBandsCalculator_HA                |
//+==================================================================+
class CBollingerBandsCalculator_HA : public CBollingerBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArraySetAsSeries(m_ha_open,  false);
      ArrayResize(m_ha_high,  rates_total);
      ArraySetAsSeries(m_ha_high,  false);
      ArrayResize(m_ha_low,   rates_total);
      ArraySetAsSeries(m_ha_low,   false);
      ArrayResize(m_ha_close, rates_total);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false);
     }

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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // BOLLINGER_BANDS_CALCULATOR_MQH
//+------------------------------------------------------------------+
