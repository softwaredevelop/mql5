//+------------------------------------------------------------------+
//|                                          Chaikin_AD_Calculator.mqh |
//|      Engine for Chaikin's Accumulation/Distribution Line.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

// Enum from the main file
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };

//+==================================================================+
class CChaikinADCalculator
  {
protected:
   ENUM_APPLIED_VOLUME m_volume_type;
   double            m_high[], m_low[], m_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CChaikinADCalculator(void) {};
   virtual          ~CChaikinADCalculator(void) {};

   bool              Init(ENUM_APPLIED_VOLUME vol_type);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &ad_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CChaikinADCalculator_HA : public CChaikinADCalculator
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
bool CChaikinADCalculator::Init(ENUM_APPLIED_VOLUME vol_type)
  {
   m_volume_type = vol_type;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CChaikinADCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                                     double &ad_buffer[])
  {
   if(rates_total < 1)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double prev_ad = 0;
   for(int i = 0; i < rates_total; i++)
     {
      double money_flow_multiplier = 0;
      double range = m_high[i] - m_low[i];

      if(range > 0.000001)
        {
         money_flow_multiplier = ((m_close[i] - m_low[i]) - (m_high[i] - m_close[i])) / range;
        }

      double money_flow_volume = money_flow_multiplier * (double)volume[i];

      ad_buffer[i] = prev_ad + money_flow_volume;
      prev_ad = ad_buffer[i];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CChaikinADCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, high, 0, 0, rates_total);
   ArrayCopy(m_low, low, 0, 0, rates_total);
   ArrayCopy(m_close, close, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CChaikinADCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_high, rates_total);
   ArrayResize(m_low, rates_total);
   ArrayResize(m_close, rates_total);
   ArrayCopy(m_high, ha_high, 0, 0, rates_total);
   ArrayCopy(m_low, ha_low, 0, 0, rates_total);
   ArrayCopy(m_close, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
