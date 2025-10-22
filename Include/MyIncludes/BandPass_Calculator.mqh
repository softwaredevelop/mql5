//+------------------------------------------------------------------+
//|                                        BandPass_Calculator.mqh   |
//|      Calculation engine for the John Ehlers' Band-Pass Filter.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CBandPassCalculator (Base Class)              |
//|                                                                  |
//+==================================================================+
class CBandPassCalculator
  {
protected:
   int               m_lower_period; // For High-Pass
   int               m_upper_period; // For SuperSmoother
   double            m_price[];

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBandPassCalculator(void) {};
   virtual          ~CBandPassCalculator(void) {};

   bool              Init(int lower_period, int upper_period);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &bp_buffer[]);
  };

//+------------------------------------------------------------------+
bool CBandPassCalculator::Init(int lower_period, int upper_period)
  {
   m_lower_period = (lower_period < 2) ? 2 : lower_period;
   m_upper_period = (upper_period < 2) ? 2 : upper_period;
   return true;
  }

//+------------------------------------------------------------------+
void CBandPassCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &bp_buffer[])
  {
   if(rates_total < 10)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

// --- Intermediate buffer for the High-Pass filter output ---
   double hp_buffer[];
   ArrayResize(hp_buffer, rates_total);

// --- High-Pass Filter Coefficients (from LowerPeriod) ---
   double arg_hp = 1.414 * M_PI / m_lower_period;
   double a1_hp = exp(-arg_hp);
   double b1_hp = 2.0 * a1_hp * cos(arg_hp);
   double c2_hp = b1_hp;
   double c3_hp = -a1_hp * a1_hp;
   double c1_hp = (1.0 + c2_hp - c3_hp) / 4.0;

// --- SuperSmoother Filter Coefficients (from UpperPeriod) ---
   double arg_ss = 1.414 * M_PI / m_upper_period;
   double a1_ss = exp(-arg_ss);
   double b1_ss = 2.0 * a1_ss * cos(arg_ss);
   double c2_ss = b1_ss;
   double c3_ss = -a1_ss * a1_ss;
   double c1_ss = 1.0 - c2_ss - c3_ss;

// --- State variables for recursive calculations ---
   double hp1=0, hp2=0; // High-Pass previous values
   double bp1=0, bp2=0; // Band-Pass (SuperSmoother) previous values

// --- Full recalculation loop ---
   for(int i = 0; i < rates_total; i++)
     {
      // Initialization period
      if(i < 4)
        {
         hp_buffer[i] = 0;
         bp_buffer[i] = 0;
         continue;
        }

      // --- Step 1: Calculate High-Pass filter value ---
      double current_hp = c1_hp * (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]) + c2_hp * hp1 + c3_hp * hp2;
      hp_buffer[i] = current_hp;

      // --- Step 2: Calculate SuperSmoother on the High-Pass output ---
      double current_bp = c1_ss * (hp_buffer[i] + hp_buffer[i-1]) / 2.0 + c2_ss * bp1 + c3_ss * bp2;
      bp_buffer[i] = current_bp;

      // --- Update state variables for next iteration ---
      hp2 = hp1;
      hp1 = current_hp;
      bp2 = bp1;
      bp1 = current_bp;
     }
  }

//+------------------------------------------------------------------+
bool CBandPassCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
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
class CBandPassCalculator_HA : public CBandPassCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
bool CBandPassCalculator_HA::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
