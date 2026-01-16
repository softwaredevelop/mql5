//+------------------------------------------------------------------+
//|                                   Bollinger_Bands_Calculator.mqh |
//|      VERSION 3.00: Refactored to use MovingAverage_Engine.       |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|          CLASS 1: CBollingerBandsCalculator (Standard)           |
//+==================================================================+
class CBollingerBandsCalculator
  {
protected:
   int               m_period;
   double            m_deviation;

   //--- Composition: Use Moving Average Engine
   CMovingAverageCalculator *m_ma_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_ma_buffer[]; // Internal buffer for centerline

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBollingerBandsCalculator(void);
   virtual          ~CBollingerBandsCalculator(void);

   bool              Init(int period, double deviation, ENUM_MA_TYPE ma_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &ma_out[], double &upper_out[], double &lower_out[]);

   void              GetPriceBuffer(double &dest_array[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBollingerBandsCalculator::CBollingerBandsCalculator(void)
  {
   m_ma_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBollingerBandsCalculator::~CBollingerBandsCalculator(void)
  {
   if(CheckPointer(m_ma_engine) != POINTER_INVALID)
      delete m_ma_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator::Init(int period, double deviation, ENUM_MA_TYPE ma_type)
  {
   m_period = (period < 1) ? 1 : period;
   m_deviation = deviation;

// Initialize the MA engine
   if(!m_ma_engine.Init(m_period, ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CBollingerBandsCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Centerline (Using Engine on Custom Array)
// We use CalculateOnArray because we have already prepared m_price (which handles HA logic if needed)
   m_ma_engine.CalculateOnArray(rates_total, prev_calculated, m_price, m_ma_buffer);

//--- 5. Calculate Bands (Incremental)
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;
      // Standard Deviation Calculation
      // Note: Standard Bollinger Bands use the SMA of (Price - MA)^2 if the center line is SMA.
      // If the center line is EMA, usually the StdDev is still calculated over the raw period window.
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i-j] - m_ma_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev_val = sqrt(sum_sq / m_period);

      upper_out[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      lower_out[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }

// Copy internal MA buffer to output
   ArrayCopy(ma_out, m_ma_buffer, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CBollingerBandsCalculator_HA                |
//+==================================================================+
class CBollingerBandsCalculator_HA : public CBollingerBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CBollingerBandsCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
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
      ArrayCopy(dest_array, m_price, 0, 0, size);
     }
  }
//+------------------------------------------------------------------+
