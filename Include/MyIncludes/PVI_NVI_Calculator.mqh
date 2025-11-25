//+------------------------------------------------------------------+
//|                                             PVI_NVI_Calculator.mqh |
//|      VERSION 1.20: Added signal lines & corrected calculation.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };

//+==================================================================+
class CPVINVICalculator
  {
protected:
   ENUM_APPLIED_VOLUME m_volume_type;
   int                 m_signal_period;
   ENUM_MA_TYPE        m_signal_ma_type;
   double              m_price[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);
   void              CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos);

public:
                     CPVINVICalculator(void) {};
   virtual          ~CPVINVICalculator(void) {};

   bool              Init(ENUM_APPLIED_VOLUME vol_type, int signal_p, ENUM_MA_TYPE signal_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &pvi_buffer[], double &nvi_buffer[], double &pvi_signal[], double &nvi_signal[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CPVINVICalculator_HA : public CPVINVICalculator
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
bool CPVINVICalculator::Init(ENUM_APPLIED_VOLUME vol_type, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_volume_type = vol_type;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPVINVICalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                                  double &pvi_buffer[], double &nvi_buffer[], double &pvi_signal[], double &nvi_signal[])
  {
   if(rates_total < 2)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   pvi_buffer[0] = 1000;
   nvi_buffer[0] = 1000;

   for(int i = 1; i < rates_total; i++)
     {
      double price_change = m_price[i] - m_price[i-1];

      if(volume[i] > volume[i-1])
        {
         pvi_buffer[i] = pvi_buffer[i-1] + price_change;
         nvi_buffer[i] = nvi_buffer[i-1];
        }
      else
         if(volume[i] < volume[i-1])
           {
            nvi_buffer[i] = nvi_buffer[i-1] + price_change;
            pvi_buffer[i] = pvi_buffer[i-1];
           }
         else
           {
            pvi_buffer[i] = pvi_buffer[i-1];
            nvi_buffer[i] = nvi_buffer[i-1];
           }
     }

   int signal_start = m_signal_period;
   CalculateMA(pvi_buffer, pvi_signal, m_signal_period, m_signal_ma_type, signal_start);
   CalculateMA(nvi_buffer, nvi_signal, m_signal_period, m_signal_ma_type, signal_start);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPVINVICalculator::CalculateMA(const double &source_array[], double &dest_array[], int period, ENUM_MA_TYPE method, int start_pos)
  {
   for(int i = start_pos; i < ArraySize(source_array); i++)
     {
      switch(method)
        {
         case EMA:
         case SMMA:
            if(i == start_pos)
              {
               double sum=0;
               int count=0;
               for(int j=0; j<period; j++)
                 {
                  if(source_array[i-j] != EMPTY_VALUE)
                    {
                     sum+=source_array[i-j];
                     count++;
                    }
                 }
               if(count > 0)
                  dest_array[i]=sum/count;
              }
            else
              {
               if(method==EMA)
                 {
                  double pr=2.0/(period+1.0);
                  dest_array[i]=source_array[i]*pr+dest_array[i-1]*(1.0-pr);
                 }
               else
                  dest_array[i]=(dest_array[i-1]*(period-1)+source_array[i])/period;
              }
            break;
         case LWMA:
           {
            double sum=0, w_sum=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] == EMPTY_VALUE)
                  continue;
               int w=period-j;
               sum+=source_array[i-j]*w;
               w_sum+=w;
              }
            if(w_sum>0)
               dest_array[i]=sum/w_sum;
           }
         break;
         default: // SMA
           {
            double sum=0;
            int count=0;
            for(int j=0; j<period; j++)
              {
               if(source_array[i-j] != EMPTY_VALUE)
                 {
                  sum+=source_array[i-j];
                  count++;
                 }
              }
            if(count > 0)
               dest_array[i]=sum/count;
           }
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPVINVICalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, close, 0, 0, rates_total);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPVINVICalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_price, rates_total);
   ArrayCopy(m_price, ha_close, 0, 0, rates_total);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
