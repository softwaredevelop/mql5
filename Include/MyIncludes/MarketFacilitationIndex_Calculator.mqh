//+------------------------------------------------------------------+
//|                         MarketFacilitationIndex_Calculator.mqh   |
//|      VERSION 1.30: Re-architected to 4-buffer histogram.         |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };

//+==================================================================+
class CMarketFacilitationIndexCalculator
  {
protected:
   ENUM_APPLIED_VOLUME m_volume_type;
   double            m_high[], m_low[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CMarketFacilitationIndexCalculator(void) {};
   virtual          ~CMarketFacilitationIndexCalculator(void) {};

   bool              Init(ENUM_APPLIED_VOLUME vol_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &green_buffer[], double &fade_buffer[], double &fake_buffer[], double &squat_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMarketFacilitationIndexCalculator_HA : public CMarketFacilitationIndexCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMarketFacilitationIndexCalculator::Init(ENUM_APPLIED_VOLUME vol_type)
  {
   m_volume_type = vol_type;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMarketFacilitationIndexCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
      double &green_buffer[], double &fade_buffer[], double &fake_buffer[], double &squat_buffer[])
  {
   if(rates_total < 2)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double mfi_buffer[]; // Temporary buffer for MFI values
   ArrayResize(mfi_buffer, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      //--- Initialize all buffers to empty for this bar ---
      green_buffer[i] = EMPTY_VALUE;
      fade_buffer[i] = EMPTY_VALUE;
      fake_buffer[i] = EMPTY_VALUE;
      squat_buffer[i] = EMPTY_VALUE;

      //--- Step 1: Calculate MFI value ---
      double range = m_high[i] - m_low[i];
      long vol = volume[i];

      if(vol > 0)
         mfi_buffer[i] = range / (double)vol;
      else
         mfi_buffer[i] = 0;

      //--- Step 2: Determine the color and place value in the correct buffer ---
      bool mfi_up = mfi_buffer[i] > mfi_buffer[i-1];
      bool vol_up = volume[i] > volume[i-1];

      if(mfi_up && vol_up)       // MFI up, Volume up
         green_buffer[i] = mfi_buffer[i];
      else
         if(!mfi_up && !vol_up)// MFI down, Volume down
            fade_buffer[i] = mfi_buffer[i];
         else
            if(mfi_up && !vol_up) // MFI up, Volume down
               fake_buffer[i] = mfi_buffer[i];
            else                       // MFI down, Volume up
               squat_buffer[i] = mfi_buffer[i];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMarketFacilitationIndexCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMarketFacilitationIndexCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayCopy(m_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_low, ha_low, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
