//+------------------------------------------------------------------+
//|                                               AMA_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi AMA.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CAMACalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CAMACalculator
  {
protected:
   int               m_ama_period;
   int               m_fast_period;
   int               m_slow_period;

   //--- Internal buffer for the selected source price
   double            m_price[];

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CAMACalculator(void) {};
   virtual          ~CAMACalculator(void) {};

   //--- Public methods
   bool              Init(int ama_p, int fast_p, int slow_p);
   int               GetPeriod(void) const { return m_ama_period; }
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &ama_buffer[]);
  };

//+------------------------------------------------------------------+
//| CAMACalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CAMACalculator::Init(int ama_p, int fast_p, int slow_p)
  {
   m_ama_period  = (ama_p < 1) ? 1 : ama_p;
   m_fast_period = (fast_p < 1) ? 1 : fast_p;
   m_slow_period = (slow_p < 1) ? 1 : slow_p;
   return true;
  }

//+------------------------------------------------------------------+
//| CAMACalculator: Main Calculation Method (Shared Logic)           |
//+------------------------------------------------------------------+
void CAMACalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &ama_buffer[])
  {
   if(rates_total <= m_ama_period)
      return;

//--- STEP 1: Prepare the source price array (delegated to virtual method)
   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

//--- STEP 2: Core AMA calculation using the prepared m_price[] array
   double fast_sc = 2.0 / (m_fast_period + 1.0);
   double slow_sc = 2.0 / (m_slow_period + 1.0);

   for(int i = 1; i < rates_total; i++)
     {
      // --- Initialization Step ---
      if(i == m_ama_period)
        {
         // The first AMA value is simply the current price
         ama_buffer[i] = m_price[i];
         continue;
        }

      if(i > m_ama_period)
        {
         // --- Calculate Efficiency Ratio (ER) ---
         double direction = MathAbs(m_price[i] - m_price[i - m_ama_period]);
         double volatility = 0;
         for(int j = 0; j < m_ama_period; j++)
           {
            volatility += MathAbs(m_price[i - j] - m_price[i - j - 1]);
           }
         double er = (volatility > 0) ? direction / volatility : 0;

         // --- Calculate Scaled Smoothing Constant (SSC) ---
         double ssc = er * (fast_sc - slow_sc) + slow_sc;
         double ssc_sq = ssc * ssc;

         // --- Calculate Final AMA ---
         ama_buffer[i] = ama_buffer[i-1] + ssc_sq * (m_price[i] - ama_buffer[i-1]);
        }
     }
  }

//+------------------------------------------------------------------+
//| CAMACalculator: Prepares the standard source price series.       |
//+------------------------------------------------------------------+
bool CAMACalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i]) / 2.0;
         break;
      case PRICE_TYPICAL:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
         break;
      default: // PRICE_CLOSE
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CAMACalculator_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CAMACalculator_HA : public CAMACalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator; // Instance of the HA calculator tool

protected:
   //--- Overridden method to prepare Heikin Ashi price series
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CAMACalculator_HA: Prepares the Heikin Ashi source price series. |
//+------------------------------------------------------------------+
bool CAMACalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- Intermediate buffers for HA candles
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate the HA candles first
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, populate the m_price array from the calculated HA candles
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
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i]) / 2.0;
         break;
      case PRICE_TYPICAL:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i = 0; i < rates_total; i++)
            m_price[i] = (ha_high[i] + ha_low[i] + 2 * ha_close[i]) / 4.0;
         break;
      default: // PRICE_CLOSE
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
