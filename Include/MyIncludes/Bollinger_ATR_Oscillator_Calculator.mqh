//+------------------------------------------------------------------+
//|                               Bollinger_ATR_Oscillator_Calculator.mqh|
//|   Calculation engine for Standard and Heikin Ashi BB ATR Osc.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|      CLASS 1: CBollingerATROscillatorCalculator (Standard)       |
//|                                                                  |
//+==================================================================+
class CBollingerATROscillatorCalculator
  {
protected:
   int               m_atr_period;
   int               m_bb_period;
   double            m_bb_dev;

   double            m_price[];
   double            m_atr_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBollingerATROscillatorCalculator(void) {};
   virtual          ~CBollingerATROscillatorCalculator(void) {};

   bool              Init(int atr_p, int bb_p, double bb_dev);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_out[]);
  };

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator: Initialization                |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator::Init(int atr_p, int bb_p, double bb_dev)
  {
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_bb_period = (bb_p < 1) ? 1 : bb_p;
   m_bb_dev = bb_dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator: Main Calculation Method       |
//+------------------------------------------------------------------+
void CBollingerATROscillatorCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_out[])
  {
   int start_pos = MathMax(m_atr_period, m_bb_period);
   if(rates_total <= start_pos)
      return;

   ArrayResize(m_price, rates_total);
   ArrayResize(m_atr_buffer, rates_total);
   ArrayResize(m_ma_buffer, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);

   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- Step 1: Calculate ATR (always on standard candles)
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

   for(int i = m_atr_period; i < rates_total; i++)
     {
      if(i == m_atr_period)
        {
         double sum=0;
         for(int j=1; j<=m_atr_period; j++)
            sum+=tr[j];
         m_atr_buffer[i]=sum/m_atr_period;
        }
      else
         m_atr_buffer[i] = (m_atr_buffer[i-1] * (m_atr_period - 1) + tr[i]) / m_atr_period;
     }

//--- Step 2: Calculate Bollinger Bands components (on prepared price)
   for(int i = m_bb_period - 1; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum += m_price[i-j];
      m_ma_buffer[i] = sum / m_bb_period;
     }
   for(int i = m_bb_period - 1; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum_sq += pow(m_price[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_bb_period);

      m_upper_band[i] = m_ma_buffer[i] + m_bb_dev * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_bb_dev * std_dev_val;
     }

//--- Step 3: Calculate the final Oscillator value
   for(int i = start_pos; i < rates_total; i++)
     {
      double bb_diff = m_upper_band[i] - m_lower_band[i];
      if(bb_diff != 0)
         osc_out[i] = m_atr_buffer[i] / bb_diff;
     }
  }

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator: Prepares the source price.    |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- Corrected: Added all price types
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|      CLASS 2: CBollingerATROscillatorCalculator_HA (Heikin Ashi) |
//|                                                                  |
//+==================================================================+
class CBollingerATROscillatorCalculator_HA : public CBollingerATROscillatorCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;

protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator_HA: Prepares the source price. |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Corrected: The HA version now also uses the selected price type from the HA candles
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_price[i] = (ha_high[i]+ha_low[i]+ha_close[i]+ha_close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
