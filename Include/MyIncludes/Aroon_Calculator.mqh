//+------------------------------------------------------------------+
//|                                             Aroon_Calculator.mqh |
//|        Calculation engine for Standard and Heikin Ashi Aroon.    |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CAroonCalculator (Base Class)               |
//|                                                                  |
//+==================================================================+
class CAroonCalculator
  {
protected:
   int               m_aroon_period;

   //--- Virtual method for preparing the source high/low data.
   virtual void      PrepareSourceData(int rates_total, const double &high[], const double &low[],
                                       double &source_high[], double &source_low[]);

public:
                     CAroonCalculator(void) {};
   virtual          ~CAroonCalculator(void) {};

   //--- Public methods
   bool              Init(int period);
   int               GetPeriod(void) const { return m_aroon_period; }
   void              Calculate(int rates_total, const double &high[], const double &low[],
                               double &aroon_up_buffer[], double &aroon_down_buffer[]);
  };

//+------------------------------------------------------------------+
//| CAroonCalculator: Initialization                                 |
//+------------------------------------------------------------------+
bool CAroonCalculator::Init(int period)
  {
   m_aroon_period = (period < 1) ? 1 : period;
   return true;
  }

//+------------------------------------------------------------------+
//| CAroonCalculator: Main Calculation Method (Shared Logic)         |
//+------------------------------------------------------------------+
void CAroonCalculator::Calculate(int rates_total, const double &high[], const double &low[],
                                 double &aroon_up_buffer[], double &aroon_down_buffer[])
  {
   if(rates_total < m_aroon_period)
      return;

//--- STEP 1: Get the source high/low data (standard or HA)
   double source_high[], source_low[];
   PrepareSourceData(rates_total, high, low, source_high, source_low);

//--- STEP 2: Calculate Aroon Up and Aroon Down for each bar
// Start from the first bar where a full period is available.
   for(int i = m_aroon_period - 1; i < rates_total; i++)
     {
      double highest_val = -DBL_MAX;
      int    highest_idx = -1;
      double lowest_val  = DBL_MAX;
      int    lowest_idx  = -1;

      // Inner loop: Look back over the defined period to find the highest high and lowest low.
      // The period is from [i - period + 1] to [i].
      for(int j = i - m_aroon_period + 1; j <= i; j++)
        {
         // Use '>=' to ensure that if multiple bars have the same high,
         // the most recent one is chosen. This is crucial for the "time since" concept.
         if(source_high[j] >= highest_val)
           {
            highest_val = source_high[j];
            highest_idx = j;
           }
         // Use '<=' for the same reason for the low.
         if(source_low[j] <= lowest_val)
           {
            lowest_val = source_low[j];
            lowest_idx = j;
           }
        }

      // STEP 3: Calculate the number of bars that have passed since these extremes occurred.
      // If the extreme was on the current bar (i), the result is 0.
      // If it was on the previous bar (i-1), the result is 1, and so on.
      int bars_since_high = i - highest_idx;
      int bars_since_low  = i - lowest_idx;

      // STEP 4: Apply the original Aroon formula by Tushar Chande.
      // The formula converts the "bars since" value into a percentage scale from 0 to 100.
      // A value of 100 means the extreme occurred on the current bar (0 bars ago).
      // A value of 0 means the extreme occurred 'period' or more bars ago.
      aroon_up_buffer[i]   = (double)(m_aroon_period - bars_since_high) / m_aroon_period * 100.0;
      aroon_down_buffer[i] = (double)(m_aroon_period - bars_since_low) / m_aroon_period * 100.0;
     }
  }

//+------------------------------------------------------------------+
//| CAroonCalculator: Prepares source data from standard prices.     |
//+------------------------------------------------------------------+
void CAroonCalculator::PrepareSourceData(int rates_total, const double &high[], const double &low[],
      double &source_high[], double &source_low[])
  {
   ArrayResize(source_high, rates_total);
   ArrayResize(source_low, rates_total);
   ArrayCopy(source_high, high, 0, 0, rates_total);
   ArrayCopy(source_low, low, 0, 0, rates_total);
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CAroonCalculator_HA (Heikin Ashi)           |
//|                                                                  |
//+==================================================================+
class CAroonCalculator_HA : public CAroonCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator; // Instance of the HA calculator tool

protected:
   //--- Overridden method to prepare Heikin Ashi based source data
   virtual void      PrepareSourceData(int rates_total, const double &high[], const double &low[],
                                       double &source_high[], double &source_low[]) override;
  };

//+------------------------------------------------------------------+
//| CAroonCalculator_HA: Prepares source data from HA prices.        |
//+------------------------------------------------------------------+
void CAroonCalculator_HA::PrepareSourceData(int rates_total, const double &high[], const double &low[],
      double &source_high[], double &source_low[])
  {
//--- We need open and close to calculate HA candles
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, rates_total, rates) <= 0)
      return;

   double open[], close[];
   ArrayResize(open, rates_total);
   ArrayResize(close, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      open[i] = rates[i].open;
      close[i] = rates[i].close;
     }

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate the HA candles first
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, provide the HA high and low as the source data
   ArrayResize(source_high, rates_total);
   ArrayResize(source_low, rates_total);
   ArrayCopy(source_high, ha_high, 0, 0, rates_total);
   ArrayCopy(source_low, ha_low, 0, 0, rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
