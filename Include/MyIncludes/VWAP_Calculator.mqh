//+------------------------------------------------------------------+
//|                                               VWAP_Calculator.mqh|
//|         Calculation engine for Standard and Heikin Ashi VWAP.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Enum for VWAP Reset Period ---
enum ENUM_VWAP_PERIOD
  {
   PERIOD_SESSION, // Reset every day
   PERIOD_WEEK,    // Reset every week
   PERIOD_MONTH    // Reset every month
  };

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CVWAPCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CVWAPCalculator
  {
protected:
   ENUM_VWAP_PERIOD    m_period;
   ENUM_APPLIED_VOLUME m_volume_type;
   double              m_typical_price[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVWAPCalculator(void) {};
   virtual          ~CVWAPCalculator(void) {};

   bool              Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type);
   void              Calculate(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[]);
  };

//+------------------------------------------------------------------+
//| CVWAPCalculator: Initialization                                  |
//+------------------------------------------------------------------+
bool CVWAPCalculator::Init(ENUM_VWAP_PERIOD period, ENUM_APPLIED_VOLUME vol_type)
  {
   m_period      = period;
   m_volume_type = vol_type;
   return true;
  }

//+------------------------------------------------------------------+
//| CVWAPCalculator: Main Calculation Method (Shared Logic)          |
//+------------------------------------------------------------------+
void CVWAPCalculator::Calculate(int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[],
                                const long &tick_volume[], const long &volume[], double &vwap_odd[], double &vwap_even[])
  {
   if(rates_total < 1)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double cumulative_tpv = 0;
   double cumulative_vol = 0;
   int period_index = 0;

   MqlDateTime time_struct, prev_time_struct;

   for(int i = 0; i < rates_total; i++)
     {
      TimeToStruct(time[i], time_struct);
      bool new_period = false;

      if(i == 0)
        {
         new_period = true;
        }
      else
        {
         TimeToStruct(time[i-1], prev_time_struct);
         switch(m_period)
           {
            case PERIOD_SESSION:
               if(time_struct.day_of_year != prev_time_struct.day_of_year || time_struct.year != prev_time_struct.year)
                  new_period = true;
               break;
            case PERIOD_WEEK:
               if(time_struct.day_of_week < prev_time_struct.day_of_week)
                  new_period = true;
               break;
            case PERIOD_MONTH:
               if(time_struct.mon != prev_time_struct.mon || time_struct.year != prev_time_struct.year)
                  new_period = true;
               break;
           }
        }

      if(new_period)
        {
         cumulative_tpv = 0;
         cumulative_vol = 0;
         period_index++; // Increment period counter
        }

      long current_volume = (m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
      if(current_volume < 1)
         current_volume = 1;

      cumulative_tpv += m_typical_price[i] * (double)current_volume;
      cumulative_vol += (double)current_volume;

      double vwap_value = (cumulative_vol > 0) ? cumulative_tpv / cumulative_vol : (i > 0 ? (period_index % 2 != 0 ? vwap_odd[i-1] : vwap_even[i-1]) : EMPTY_VALUE);

      // Write to the correct buffer based on period index (odd/even)
      if(period_index % 2 != 0) // Odd period
        {
         vwap_odd[i] = vwap_value;
         vwap_even[i] = EMPTY_VALUE;
        }
      else // Even period
        {
         vwap_even[i] = vwap_value;
         vwap_odd[i] = EMPTY_VALUE;
        }
     }
  }

//+------------------------------------------------------------------+
//| CVWAPCalculator: Prepares the standard source data.              |
//+------------------------------------------------------------------+
bool CVWAPCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (high[i] + low[i] + close[i]) / 3.0;
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CVWAPCalculator_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CVWAPCalculator_HA : public CVWAPCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CVWAPCalculator_HA: Prepares the HA source data.                 |
//+------------------------------------------------------------------+
bool CVWAPCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_typical_price, rates_total);
   for(int i=0; i<rates_total; i++)
      m_typical_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
