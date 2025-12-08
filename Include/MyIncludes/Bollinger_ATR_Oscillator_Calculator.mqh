//+------------------------------------------------------------------+
//|                               Bollinger_ATR_Oscillator_Calculator.mqh|
//|      VERSION 2.20: Full incremental support with selectable ATR src.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Define the Enum here locally
enum ENUM_ATR_SOURCE
  {
   ATR_SOURCE_STANDARD,    // Calculate ATR from standard candles
   ATR_SOURCE_HEIKIN_ASHI  // Calculate ATR from Heikin Ashi candles
  };

//+==================================================================+
//|      CLASS 1: CBollingerATROscillatorCalculator (Standard)       |
//+==================================================================+
class CBollingerATROscillatorCalculator
  {
protected:
   int               m_atr_period;
   int               m_bb_period;
   double            m_bb_dev;
   ENUM_ATR_SOURCE   m_atr_source;

   //--- Persistent Buffers
   double            m_price[];
   double            m_atr_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];
   double            m_tr[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Core logic separated to allow passing different High/Low/Close arrays
   void              CalculateCore(int rates_total, int start_index, const double &high[], const double &low[], const double &close[], double &osc_out[]);

public:
                     CBollingerATROscillatorCalculator(void) {};
   virtual          ~CBollingerATROscillatorCalculator(void) {};

   bool              Init(int atr_p, int bb_p, double bb_dev, ENUM_ATR_SOURCE atr_src);

   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_out[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator::Init(int atr_p, int bb_p, double bb_dev, ENUM_ATR_SOURCE atr_src)
  {
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_bb_period = (bb_p < 1) ? 1 : bb_p;
   m_bb_dev = bb_dev;
   m_atr_source = atr_src;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculate (Standard)                                        |
//+------------------------------------------------------------------+
void CBollingerATROscillatorCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_out[])
  {
   int start_pos = MathMax(m_atr_period, m_bb_period);
   if(rates_total <= start_pos)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_atr_buffer, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
      ArrayResize(m_upper_band, rates_total);
      ArrayResize(m_lower_band, rates_total);
      ArrayResize(m_tr, rates_total);
     }

// Prepare Price (Standard) - Fills m_price for BB calculation
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Call Core with Standard Arrays for ATR
   CalculateCore(rates_total, start_index, high, low, close, osc_out);
  }

//+------------------------------------------------------------------+
//| Core Calculation Logic (ATR + BB + Osc)                          |
//+------------------------------------------------------------------+
void CBollingerATROscillatorCalculator::CalculateCore(int rates_total, int start_index, const double &high[], const double &low[], const double &close[], double &osc_out[])
  {
//--- 1. Calculate ATR (Incremental)
   int loop_start_atr = MathMax(m_atr_period, start_index);

// TR Calculation
   int tr_start = (start_index < 1) ? 1 : start_index;
   for(int i = tr_start; i < rates_total; i++)
      m_tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

   for(int i = loop_start_atr; i < rates_total; i++)
     {
      if(i == m_atr_period)
        {
         double sum=0;
         for(int j=1; j<=m_atr_period; j++)
            sum+=m_tr[j];
         m_atr_buffer[i]=sum/m_atr_period;
        }
      else
         m_atr_buffer[i] = (m_atr_buffer[i-1] * (m_atr_period - 1) + m_tr[i]) / m_atr_period;
     }

//--- 2. Calculate Bollinger Bands (Incremental)
// Uses m_price which is already prepared by PreparePriceSeries
   int loop_start_bb = MathMax(m_bb_period - 1, start_index);

   for(int i = loop_start_bb; i < rates_total; i++)
     {
      // SMA
      double sum = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum += m_price[i-j];
      m_ma_buffer[i] = sum / m_bb_period;

      // StdDev
      double sum_sq = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum_sq += pow(m_price[i-j] - m_ma_buffer[i], 2);
      double std_dev = sqrt(sum_sq / m_bb_period);

      m_upper_band[i] = m_ma_buffer[i] + m_bb_dev * std_dev;
      m_lower_band[i] = m_ma_buffer[i] - m_bb_dev * std_dev;
     }

//--- 3. Calculate Oscillator
   int start_pos = MathMax(m_atr_period, m_bb_period);
   int loop_start_osc = MathMax(start_pos, start_index);

   for(int i = loop_start_osc; i < rates_total; i++)
     {
      double bb_diff = m_upper_band[i] - m_lower_band[i];
      if(bb_diff != 0)
         osc_out[i] = m_atr_buffer[i] / bb_diff;
      else
         osc_out[i] = 0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CBollingerATROscillatorCalculator_HA        |
//+==================================================================+
class CBollingerATROscillatorCalculator_HA : public CBollingerATROscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;

public:
   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_out[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (HA Override)                                          |
//+------------------------------------------------------------------+
void CBollingerATROscillatorCalculator_HA::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_out[])
  {
   int start_pos = MathMax(m_atr_period, m_bb_period);
   if(rates_total <= start_pos)
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers (Same as base)
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_atr_buffer, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
      ArrayResize(m_upper_band, rates_total);
      ArrayResize(m_lower_band, rates_total);
      ArrayResize(m_tr, rates_total);
     }

// 1. Prepare HA Data (and m_price for BB)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Call Core with Selected Arrays for ATR
   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
     {
      // Use HA arrays for ATR
      CalculateCore(rates_total, start_index, m_ha_high, m_ha_low, m_ha_close, osc_out);
     }
   else
     {
      // Use Standard arrays for ATR (Hybrid mode)
      CalculateCore(rates_total, start_index, high, low, close, osc_out);
     }
  }
//+------------------------------------------------------------------+
