//+------------------------------------------------------------------+
//|                                     Windowed_MA_Calculator.mqh   |
//|      Calculation engine for Windowed FIR filters (SMA, HWMA).    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_WINDOW_TYPE { W_SMA, W_TRIANGULAR, W_HANN };
enum ENUM_INPUT_SOURCE { SOURCE_PRICE, SOURCE_MOMENTUM }; // Price or (Close-Open)

//+==================================================================+
class CWindowedMACalculator
  {
protected:
   int                 m_period;
   ENUM_WINDOW_TYPE    m_window_type;
   ENUM_INPUT_SOURCE   m_source_type;
   double              m_source_data[];

   virtual bool      PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CWindowedMACalculator(void) {};
   virtual          ~CWindowedMACalculator(void) {};

   bool              Init(int period, ENUM_WINDOW_TYPE window_type, ENUM_INPUT_SOURCE source_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[]);
  };

//+------------------------------------------------------------------+
bool CWindowedMACalculator::Init(int period, ENUM_WINDOW_TYPE window_type, ENUM_INPUT_SOURCE source_type)
  {
   m_period = (period < 1) ? 1 : period;
   m_window_type = window_type;
   m_source_type = source_type;
   return true;
  }

//+------------------------------------------------------------------+
void CWindowedMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &output_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PrepareSourceData(rates_total, price_type, open, high, low, close))
      return;

   for(int i = m_period - 1; i < rates_total; i++)
     {
      double sum = 0;
      double weight_sum = 0;

      for(int j = 0; j < m_period; j++)
        {
         double weight = 1.0;
         switch(m_window_type)
           {
            case W_TRIANGULAR:
               weight = (m_period/2.0) - fabs(j - (m_period-1.0)/2.0);
               break;
            case W_HANN:
               if(m_period > 1)
                  weight = 0.5 * (1.0 - cos(2.0 * M_PI * j / (m_period - 1.0)));
               else
                  weight = 1.0;
               break;
           }

         sum += m_source_data[i-j] * weight;
         weight_sum += weight;
        }

      if(weight_sum > 0)
         output_buffer[i] = sum / weight_sum;
     }
  }

//+------------------------------------------------------------------+
bool CWindowedMACalculator::PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_source_data, rates_total);
   if(m_source_type == SOURCE_PRICE)
     {
      // Use the selected price type for the calculation
      switch(price_type)
        {
         case PRICE_OPEN:
            ArrayCopy(m_source_data, open, 0, 0, rates_total);
            break;
         case PRICE_HIGH:
            ArrayCopy(m_source_data, high, 0, 0, rates_total);
            break;
         case PRICE_LOW:
            ArrayCopy(m_source_data, low, 0, 0, rates_total);
            break;
         case PRICE_MEDIAN:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            ArrayCopy(m_source_data, close, 0, 0, rates_total);
            break;
        }
     }
   else // SOURCE_MOMENTUM
     {
      for(int i=0; i<rates_total; i++)
         m_source_data[i] = close[i] - open[i];
     }
   return true;
  }

//+==================================================================+
class CWindowedMACalculator_HA : public CWindowedMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   // CORRECTED: Function name typo fixed
   virtual bool      PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
// CORRECTED: Function name typo fixed
bool CWindowedMACalculator_HA::PrepareSourceData(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_source_data, rates_total);
   if(m_source_type == SOURCE_PRICE)
     {
      switch(price_type)
        {
         case PRICE_OPEN:
            ArrayCopy(m_source_data, ha_open, 0, 0, rates_total);
            break;
         case PRICE_HIGH:
            ArrayCopy(m_source_data, ha_high, 0, 0, rates_total);
            break;
         case PRICE_LOW:
            ArrayCopy(m_source_data, ha_low, 0, 0, rates_total);
            break;
         case PRICE_MEDIAN:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (ha_high[i]+ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            for(int i=0; i<rates_total; i++)
               m_source_data[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
            break;
         default:
            ArrayCopy(m_source_data, ha_close, 0, 0, rates_total);
            break;
        }
     }
   else // SOURCE_MOMENTUM
     {
      for(int i=0; i<rates_total; i++)
         m_source_data[i] = ha_close[i] - ha_open[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
