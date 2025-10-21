//+------------------------------------------------------------------+
//|                                              DMH_Calculator.mqh  |
//|    Calculation engine for Ehlers' Directional Movement with      |
//|    Hann Windowing (DMH).                                         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CDMHCalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CDMHCalculator
  {
protected:
   int               m_period;
   // These arrays will hold the source data, either standard or HA
   double            m_source_high[], m_source_low[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDMHCalculator(void) {};
   virtual          ~CDMHCalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dmh_buffer[]);
  };

//+------------------------------------------------------------------+
bool CDMHCalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;
   return true;
  }

//+------------------------------------------------------------------+
void CDMHCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dmh_buffer[])
  {
   if(rates_total < m_period * 2)
      return;

// This call populates m_source_high and m_source_low with either standard or HA data
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double ema_buffer[];
   ArrayResize(ema_buffer, rates_total);
   double ema_prev = 0;
   double sf = 1.0 / m_period; // EMA alpha

// Step 1 & 2: Calculate raw DM difference and smooth with EMA
   for(int i = 1; i < rates_total; i++)
     {
      double plus_dm = 0, minus_dm = 0;
      double upper_move = m_source_high[i] - m_source_high[i-1];
      double lower_move = m_source_low[i-1] - m_source_low[i];

      if(upper_move > lower_move && upper_move > 0)
         plus_dm = upper_move;
      else
         if(lower_move > upper_move && lower_move > 0)
            minus_dm = lower_move;

      double dm_diff = plus_dm - minus_dm;
      ema_buffer[i] = sf * dm_diff + (1.0 - sf) * ema_prev;
      ema_prev = ema_buffer[i];
     }

// Step 3: Smooth the EMA with a Hann-windowed FIR filter
   double hann_weights[];
   ArrayResize(hann_weights, m_period);
   double coef_sum = 0;
   for(int i = 0; i < m_period; i++)
     {
      hann_weights[i] = 1.0 - cos(2 * M_PI * (i + 1.0) / (m_period + 1.0));
      coef_sum += hann_weights[i];
     }

   if(coef_sum <= 0)
      return;

   for(int i = m_period - 1; i < rates_total; i++)
     {
      double dm_sum = 0;
      for(int j = 0; j < m_period; j++)
        {
         dm_sum += hann_weights[j] * ema_buffer[i-j];
        }
      dmh_buffer[i] = dm_sum / coef_sum;
     }
  }

//+------------------------------------------------------------------+
// Base class implementation: copies standard prices to source arrays
//+------------------------------------------------------------------+
bool CDMHCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_source_high, rates_total);
   ArrayResize(m_source_low, rates_total);
   ArrayCopy(m_source_high, high, 0, 0, rates_total);
   ArrayCopy(m_source_low, low, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
class CDMHCalculator_HA : public CDMHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
// Derived class implementation: copies HA prices to source arrays
//+------------------------------------------------------------------+
bool CDMHCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// CORRECTED: Resize the destination arrays before the calculation
   ArrayResize(m_source_high, rates_total);
   ArrayResize(m_source_low, rates_total);

   double ha_open[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_close, rates_total);

// The m_source_high and m_source_low arrays are protected members of the base class,
// so this overridden method can write directly into them.
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_source_high, m_source_low, ha_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
