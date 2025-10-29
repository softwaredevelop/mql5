//+------------------------------------------------------------------+
//|                                    Ehlers_Bands_Calculator.mqh   |
//|      Calculation engine for Ehlers Bands, using a selectable     |
//|      smoother (SuperSmoother or UltimateSmoother) as centerline. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
class CEhlersBandsCalculator
  {
protected:
   CEhlersSmootherCalculator *m_calc_center;
   int               m_period;
   double            m_multiplier;
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CEhlersBandsCalculator(void);
   virtual          ~CEhlersBandsCalculator(void);

   bool              Init(int period, double multiplier, ENUM_SMOOTHER_TYPE smoother_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);
  };

//+------------------------------------------------------------------+
CEhlersBandsCalculator::CEhlersBandsCalculator(void)
  {
   m_calc_center = NULL; // Will be instantiated in Init based on HA/Std choice
  }
//+------------------------------------------------------------------+
CEhlersBandsCalculator::~CEhlersBandsCalculator(void)
  {
   if(CheckPointer(m_calc_center) != POINTER_INVALID)
      delete m_calc_center;
  }
//+------------------------------------------------------------------+
bool CEhlersBandsCalculator::Init(int period, double multiplier, ENUM_SMOOTHER_TYPE smoother_type)
  {
   m_period = (period < 2) ? 2 : period;
   m_multiplier = multiplier;

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      m_calc_center = new CEhlersSmootherCalculator();

   if(CheckPointer(m_calc_center) == POINTER_INVALID)
      return false;

// CORRECTED: Pass the required SOURCE_PRICE to the smoother's Init method.
   return(m_calc_center.Init(m_period, smoother_type, SOURCE_PRICE));
  }

//+------------------------------------------------------------------+
void CEhlersBandsCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                       double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Step 1: Calculate Centerline using the selected smoother ---
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
bool CEhlersBandsCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
class CEhlersBandsCalculator_HA : public CEhlersBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
public:
                     CEhlersBandsCalculator_HA(void)
     {
      if(CheckPointer(m_calc_center) != POINTER_INVALID)
         delete m_calc_center;
      m_calc_center = new CEhlersSmootherCalculator_HA();
     }
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CEhlersBandsCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
