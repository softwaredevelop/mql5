//+------------------------------------------------------------------+
//|                                               HMA_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi HMA.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CHMACalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CHMACalculator
  {
protected:
   int               m_hma_period;
   double            m_price[];

   //--- Helper function for manual WMA calculation
   double            CalculateWMA(int period, int index, const double &source_array[]);

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CHMACalculator(void) {};
   virtual          ~CHMACalculator(void) {};

   //--- Public methods
   bool              Init(int period);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &hma_buffer[]);
  };

//+------------------------------------------------------------------+
//| CHMACalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CHMACalculator::Init(int period)
  {
   m_hma_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| CHMACalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CHMACalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &hma_buffer[])
  {
   int period_sqrt = (int)MathMax(1, MathRound(MathSqrt(m_hma_period)));
   int start_pos = m_hma_period + period_sqrt - 2;
   if(rates_total <= start_pos)
      return;

   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   double wma_half[], wma_full[], raw_hma[];
   ArrayResize(wma_half, rates_total);
   ArrayResize(wma_full, rates_total);
   ArrayResize(raw_hma, rates_total);

   int period_half = (int)MathMax(1, MathRound(m_hma_period / 2.0));

   for(int i = m_hma_period - 1; i < rates_total; i++)
     {
      wma_half[i] = CalculateWMA(period_half, i, m_price);
      wma_full[i] = CalculateWMA(m_hma_period, i, m_price);
      raw_hma[i] = 2 * wma_half[i] - wma_full[i];
     }

   for(int i = start_pos; i < rates_total; i++)
     {
      hma_buffer[i] = CalculateWMA(period_sqrt, i, raw_hma);
     }
  }

//+------------------------------------------------------------------+
//| CHMACalculator: Helper for manual WMA calculation                |
//+------------------------------------------------------------------+
double CHMACalculator::CalculateWMA(int period, int index, const double &source_array[])
  {
   double lwma_sum = 0, weight_sum = 0;
   for(int j=0; j<period; j++)
     {
      int weight = period - j;
      lwma_sum += source_array[index-j] * weight;
      weight_sum += weight;
     }
   return (weight_sum > 0) ? lwma_sum / weight_sum : 0.0;
  }

//+------------------------------------------------------------------+
//| CHMACalculator: Prepares the standard source price series.       |
//+------------------------------------------------------------------+
bool CHMACalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CHMACalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CHMACalculator_HA : public CHMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CHMACalculator_HA: Prepares the Heikin Ashi source price.        |
//+------------------------------------------------------------------+
bool CHMACalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
