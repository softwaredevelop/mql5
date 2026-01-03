//+------------------------------------------------------------------+
//|                                     Butterworth_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Butterworth Filter. |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_BUTTERWORTH_POLES { POLES_TWO = 2, POLES_THREE = 3 };
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM };

//+==================================================================+
//|             CLASS 1: CButterworthCalculator                      |
//+==================================================================+
class CButterworthCalculator
  {
protected:
   int                     m_period;
   ENUM_BUTTERWORTH_POLES  m_poles;
   ENUM_INPUT_SOURCE       m_source_type;

   //--- Persistent Buffer for Price
   double                  m_price[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CButterworthCalculator(void) {};
   virtual          ~CButterworthCalculator(void) {};

   bool              Init(int period, ENUM_BUTTERWORTH_POLES poles, ENUM_INPUT_SOURCE source_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CButterworthCalculator::Init(int period, ENUM_BUTTERWORTH_POLES poles, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_poles = poles;
   m_source_type = source_type;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CButterworthCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &filter_buffer[])
  {
   if(rates_total < 4)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize internal buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Incremental Loop
   int loop_start = MathMax(3, start_index);

// Initialization
   if(loop_start == 3)
     {
      filter_buffer[0] = m_price[0];
      filter_buffer[1] = m_price[1];
      filter_buffer[2] = m_price[2];
     }

   if(m_poles == POLES_TWO)
     {
      double a = exp(-M_SQRT2 * M_PI / m_period);
      double b = 2.0 * a * cos(M_SQRT2 * M_PI / m_period);
      double c1 = (1.0 - b + a*a) / 4.0;

      for(int i = loop_start; i < rates_total; i++)
        {
         // Recursive calculation using persistent buffer [i-1], [i-2]
         double f1 = filter_buffer[i-1];
         double f2 = filter_buffer[i-2];

         filter_buffer[i] = b * f1 - a * a * f2 + c1 * (m_price[i] + 2.0 * m_price[i-1] + m_price[i-2]);
        }
     }
   else // POLES_THREE
     {
      double a = exp(-M_PI / m_period);
      double b = 2.0 * a * cos(1.738 * M_PI / m_period); // 1.738 is approx sqrt(3) * pi / 3? No, it's specific to 3-pole.
      double c = a * a;
      double c1 = (1.0 - b + c) * (1.0 - c) / 8.0;

      for(int i = loop_start; i < rates_total; i++)
        {
         // Recursive calculation using persistent buffer [i-1], [i-2], [i-3]
         double f1 = filter_buffer[i-1];
         double f2 = filter_buffer[i-2];
         double f3 = filter_buffer[i-3];

         filter_buffer[i] = (b + c) * f1 - (c + b*c) * f2 + c*c * f3 + c1 * (m_price[i] + 3.0 * m_price[i-1] + 3.0 * m_price[i-2] + m_price[i-3]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CButterworthCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
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
      else // SOURCE_MOMENTUM
        {
         m_price[i] = close[i] - open[i];
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CButterworthCalculator_HA                   |
//+==================================================================+
class CButterworthCalculator_HA : public CButterworthCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CButterworthCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      if(m_source_type == SOURCE_PRICE)
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
      else // SOURCE_MOMENTUM
        {
         m_price[i] = m_ha_close[i] - m_ha_open[i];
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
