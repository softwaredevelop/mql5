//+------------------------------------------------------------------+
//|                                  Gaussian_Bands_Calculator.mqh   |
//|      Calculation engine for Bollinger-style bands using a        |
//|      Gaussian Filter as the centerline.                          |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Gaussian_Filter_Calculator.mqh>

//+==================================================================+
class CGaussianBandsCalculator
  {
protected:
   CGaussianFilterCalculator *m_calc_center;
   int               m_period;
   double            m_multiplier;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGaussianBandsCalculator(void);
   virtual          ~CGaussianBandsCalculator(void);

   bool              Init(int period, double multiplier);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);
  };

//+------------------------------------------------------------------+
CGaussianBandsCalculator::CGaussianBandsCalculator(void)
  {
   m_calc_center = NULL;
  }
//+------------------------------------------------------------------+
CGaussianBandsCalculator::~CGaussianBandsCalculator(void)
  {
   if(CheckPointer(m_calc_center) != POINTER_INVALID)
      delete m_calc_center;
  }
//+------------------------------------------------------------------+
bool CGaussianBandsCalculator::Init(int period, double multiplier)
  {
   m_period = (period < 2) ? 2 : period;
   m_multiplier = multiplier;

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      m_calc_center = new CGaussianFilterCalculator();

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      return false;

   return(m_calc_center.Init(m_period, SOURCE_PRICE));
  }

//+------------------------------------------------------------------+
void CGaussianBandsCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Step 1: Calculate Centerline using Gaussian Filter ---
   m_calc_center.Calculate(rates_total, price_type, open, high, low, close, middle_buffer);

// --- Step 2: Calculate Standard Deviation ---
   for(int i = m_period - 1; i < rates_total; i++)
     {
      double sum_sq = 0;
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i-j] - middle_buffer[i-j];
         sum_sq += diff * diff;
        }

      double std_dev = sqrt(sum_sq / m_period);

      // --- Step 3: Calculate Upper and Lower Bands ---
      if(middle_buffer[i] != EMPTY_VALUE)
        {
         upper_buffer[i] = middle_buffer[i] + m_multiplier * std_dev;
         lower_buffer[i] = middle_buffer[i] - m_multiplier * std_dev;
        }
     }
  }

//+------------------------------------------------------------------+
bool CGaussianBandsCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
// For StdDev, we use the same price source as the filter itself
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
class CGaussianBandsCalculator_HA : public CGaussianBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
public:
                     CGaussianBandsCalculator_HA(void)
     {
      if(CheckPointer(m_calc_center) != POINTER_INVALID)
         delete m_calc_center;
      m_calc_center = new CGaussianFilterCalculator_HA();
     }
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CGaussianBandsCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
