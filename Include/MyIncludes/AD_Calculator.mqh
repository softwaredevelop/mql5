//+------------------------------------------------------------------+
//|                                                AD_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi A/D.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CADCalculator (Base Class)                  |
//|                                                                  |
//+==================================================================+
class CADCalculator
  {
protected:
   //--- Internal buffers for the selected candle data
   double            m_high[];
   double            m_low[];
   double            m_close[];

   //--- Virtual method for preparing the candle data. Base class handles standard candles.
   //--- CORRECTED: Added 'open' array to the signature for consistency with derived class.
   virtual bool      PrepareCandleData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CADCalculator(void) {};
   virtual          ~CADCalculator(void) {};

   //--- Public calculation method
   //--- CORRECTED: Added 'open' array to the signature.
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &ad_buffer[]);
  };

//+------------------------------------------------------------------+
//| CADCalculator: Main Calculation Method (Shared Logic)            |
//+------------------------------------------------------------------+
void CADCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                              const long &tick_volume[], const long &volume[], ENUM_APPLIED_VOLUME volume_type, double &ad_buffer[])
  {
   if(rates_total < 1)
      return;

//--- STEP 1: Prepare the source candle arrays (delegated to virtual method)
   if(!PrepareCandleData(rates_total, open, high, low, close))
      return;

//--- STEP 2: Core A/D calculation using the prepared m_high[], m_low[], m_close[] arrays
   for(int i = 0; i < rates_total; i++)
     {
      double mfm = 0; // Money Flow Multiplier
      double range = m_high[i] - m_low[i];

      if(range > 0)
        {
         mfm = ((m_close[i] - m_low[i]) - (m_high[i] - m_close[i])) / range;
        }

      long current_volume = (volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
      double mfv = mfm * current_volume; // Money Flow Volume

      if(i > 0)
         ad_buffer[i] = ad_buffer[i-1] + mfv;
      else
         ad_buffer[i] = mfv; // First value
     }
  }

//+------------------------------------------------------------------+
//| CADCalculator: Prepares the standard candle data series.         |
//+------------------------------------------------------------------+
bool CADCalculator::PrepareCandleData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- CORRECTED: Use ArrayCopy for robust data handling instead of invalid pointer assignment.
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);

   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);
   ArrayCopy(m_close, close, 0, 0, rates_total);

   return true;
  }

//+==================================================================+
//|                                                                  |
//|             CLASS 2: CADCalculator_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CADCalculator_HA : public CADCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator; // Instance of the HA calculator tool

protected:
   //--- Overridden method to prepare Heikin Ashi candle data
   //--- CORRECTED: Signature now matches the base class, including 'open'.
   virtual bool      PrepareCandleData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CADCalculator_HA: Prepares the Heikin Ashi candle data series.   |
//+------------------------------------------------------------------+
bool CADCalculator_HA::PrepareCandleData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
//--- For the HA calculator, we must calculate and store the HA values.
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);

//--- We need a temporary ha_open buffer for the calculation
   double ha_open[];
   ArrayResize(ha_open, rates_total);

//--- Calculate the HA candles into our member arrays
//--- CORRECTED: Removed invalid GetPointer() calls.
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_high, m_low, m_close);

   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
