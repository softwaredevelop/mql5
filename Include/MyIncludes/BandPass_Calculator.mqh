//+------------------------------------------------------------------+
//|                                        BandPass_Calculator.mqh   |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CBandPassCalculator (Base Class)              |
//+==================================================================+
class CBandPassCalculator
  {
protected:
   int               m_lower_period; // For High-Pass
   int               m_upper_period; // For SuperSmoother

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_hp_buffer[]; // Intermediate High-Pass output

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CBandPassCalculator(void) {};
   virtual          ~CBandPassCalculator(void) {};

   bool              Init(int lower_period, int upper_period);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &bp_buffer[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CBandPassCalculator::Init(int lower_period, int upper_period)
  {
   m_lower_period = (lower_period < 2) ? 2 : lower_period;
   m_upper_period = (upper_period < 2) ? 2 : upper_period;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CBandPassCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &bp_buffer[])
  {
   if(rates_total < 10)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_hp_buffer, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// --- High-Pass Filter Coefficients (from LowerPeriod) ---
   double arg_hp = M_SQRT2 * M_PI / m_lower_period;
   double a1_hp = exp(-arg_hp);
   double b1_hp = 2.0 * a1_hp * cos(arg_hp);
   double c2_hp = b1_hp;
   double c3_hp = -a1_hp * a1_hp;
   double c1_hp = (1.0 + c2_hp - c3_hp) / 4.0;

// --- SuperSmoother Filter Coefficients (from UpperPeriod) ---
   double arg_ss = M_SQRT2 * M_PI / m_upper_period;
   double a1_ss = exp(-arg_ss);
   double b1_ss = 2.0 * a1_ss * cos(arg_ss);
   double c2_ss = b1_ss;
   double c3_ss = -a1_ss * a1_ss;
   double c1_ss = 1.0 - c2_ss - c3_ss;

// --- Incremental Loop ---
   int loop_start = MathMax(4, start_index);

// Initialization
   if(loop_start == 4)
     {
      m_hp_buffer[0] = 0;
      m_hp_buffer[1] = 0;
      m_hp_buffer[2] = 0;
      m_hp_buffer[3] = 0;
      bp_buffer[0] = 0;
      bp_buffer[1] = 0;
      bp_buffer[2] = 0;
      bp_buffer[3] = 0;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // --- Step 1: Calculate High-Pass filter value ---
      // Recursive: hp[i] depends on hp[i-1], hp[i-2]
      double hp1 = m_hp_buffer[i-1];
      double hp2 = m_hp_buffer[i-2];

      m_hp_buffer[i] = c1_hp * (m_price[i] - 2.0 * m_price[i-1] + m_price[i-2]) + c2_hp * hp1 + c3_hp * hp2;

      // --- Step 2: Calculate SuperSmoother on the High-Pass output ---
      // Recursive: bp[i] depends on bp[i-1], bp[i-2]
      double bp1 = bp_buffer[i-1];
      double bp2 = bp_buffer[i-2];

      bp_buffer[i] = c1_ss * (m_hp_buffer[i] + m_hp_buffer[i-1]) / 2.0 + c2_ss * bp1 + c3_ss * bp2;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CBandPassCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CBandPassCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CBandPassCalculator_HA : public CBandPassCalculator
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
bool CBandPassCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
