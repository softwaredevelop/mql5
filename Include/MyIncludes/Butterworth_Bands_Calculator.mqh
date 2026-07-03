//+------------------------------------------------------------------+
//|                                    Butterworth_Bands_Calculator.mqh|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // High-performance John Ehlers' Butterworth Bands calculator engine
#property description "Butterworth Filter Middle Line + StdDev Bands (Bollinger Concept)."

#ifndef BUTTERWORTH_BANDS_CALCULATOR_MQH
#define BUTTERWORTH_BANDS_CALCULATOR_MQH

#include <MyIncludes\Butterworth_Calculator.mqh>

//+==================================================================+
//|           CLASS 1: CButterworthBandsCalculator (Base)            |
//+==================================================================+
class CButterworthBandsCalculator
  {
protected:
   int                     m_period;       // Volatility lookback period (N)
   double                  m_deviation;    // Standard Deviation multiplier (d)
   int                     m_butter_period;// Butterworth cutoff period (P)
   ENUM_BUTTERWORTH_POLES  m_poles;        // Butterworth poles

   CButterworthCalculator  *m_butter_calc;  // Embedded Butterworth Filter engine

   double                  m_price[];      // Local price cache for StdDev calculations

   virtual void      CreateEngine(void);
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CButterworthBandsCalculator(void);
   virtual          ~CButterworthBandsCalculator(void);

   bool              Init(int period, double deviation, int butter_period, ENUM_BUTTERWORTH_POLES poles);

   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CButterworthBandsCalculator::CButterworthBandsCalculator(void)
  {
   m_butter_calc = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CButterworthBandsCalculator::~CButterworthBandsCalculator(void)
  {
   if(CheckPointer(m_butter_calc) != POINTER_INVALID)
      delete m_butter_calc;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CButterworthBandsCalculator::CreateEngine(void)
  {
   m_butter_calc = new CButterworthCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CButterworthBandsCalculator::Init(int period, double deviation, int butter_period, ENUM_BUTTERWORTH_POLES poles)
  {
   m_period = (period < 2) ? 2 : period;
   m_deviation = deviation;
   m_butter_period = (butter_period < 2) ? 2 : butter_period;
   m_poles = poles;

   CreateEngine(); // Polymorphically instantiates the correct engine

   if(CheckPointer(m_butter_calc) == POINTER_INVALID || !m_butter_calc.Init(m_butter_period, m_poles, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CButterworthBandsCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   if(rates_total < m_period)
      return;

   if(CheckPointer(m_butter_calc) == POINTER_INVALID)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Internal Buffer and force chronological indexing
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArraySetAsSeries(m_price, false); // Fixed: strict chronological safety on internal buffers
     }

//--- 3. Prepare Price (For StdDev calculation)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 4. Calculate Centerline (Butterworth Filter)
   m_butter_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 5. Calculate Bands (StdDev from Butterworth centerline)
   int loop_start = MathMax(m_period, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      double sum_sq = 0;

      // Calculate Standard Deviation relative to the Butterworth centerline
      for(int j = 0; j < m_period; j++)
        {
         double diff = m_price[i-j] - middle_buffer[i];
         sum_sq += diff * diff;
        }

      double std_dev = sqrt(sum_sq / m_period);

      upper_buffer[i] = middle_buffer[i] + (std_dev * m_deviation);
      lower_buffer[i] = middle_buffer[i] - (std_dev * m_deviation);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CButterworthBandsCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|           CLASS 2: CButterworthBandsCalculator_HA                |
//+==================================================================+
class CButterworthBandsCalculator_HA : public CButterworthBandsCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      CreateEngine(void) override;
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Factory Override                                                 |
//+------------------------------------------------------------------+
void CButterworthBandsCalculator_HA::CreateEngine(void)
  {
   m_butter_calc = new CButterworthCalculator_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CButterworthBandsCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers and force chronological indexing
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open, false);
      ArraySetAsSeries(m_ha_high, false);
      ArraySetAsSeries(m_ha_low, false);
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
#endif // BUTTERWORTH_BANDS_CALCULATOR_MQH
//+------------------------------------------------------------------+
