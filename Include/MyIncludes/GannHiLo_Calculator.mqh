//+------------------------------------------------------------------+
//|                                           Gann_HiLo_Calculator.mqh|
//|      Calculation engine for Standard and Heikin Ashi Gann HiLo.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CGannHiLoCalculator (Base Class)              |
//|                                                                  |
//+==================================================================+
class CGannHiLoCalculator
  {
protected:
   int               m_period;
   ENUM_MA_METHOD    m_ma_method;

   double            m_src_high[], m_src_low[], m_src_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CGannHiLoCalculator(void) {};
   virtual          ~CGannHiLoCalculator(void) {};

   bool              Init(int period, ENUM_MA_METHOD ma_method);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &hilo_buffer[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| CGannHiLoCalculator: Initialization                              |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator::Init(int period, ENUM_MA_METHOD ma_method)
  {
   m_period    = (period < 1) ? 1 : period;
   m_ma_method = ma_method;
   return true;
  }

//+------------------------------------------------------------------+
//| CGannHiLoCalculator: Main Calculation Method (Shared Logic)      |
//+------------------------------------------------------------------+
void CGannHiLoCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &hilo_buffer[], double &color_buffer[])
  {
   if(rates_total <= m_period)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double hi_avg[], lo_avg[], trend[];
   ArrayResize(hi_avg, rates_total);
   ArrayResize(lo_avg, rates_total);
   ArrayResize(trend, rates_total);

   for(int i = 1; i < rates_total; i++)
     {
      if(i < m_period - 1)
         continue;

      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_period - 1)
              {
               double sum_h=0, sum_l=0;
               for(int j=0; j<m_period; j++)
                 {
                  sum_h+=m_src_high[i-j];
                  sum_l+=m_src_low[i-j];
                 }
               hi_avg[i]=sum_h/m_period;
               lo_avg[i]=sum_l/m_period;
              }
            else
              {
               if(m_ma_method==MODE_EMA)
                 {
                  double pr=2.0/(m_period+1.0);
                  hi_avg[i]=m_src_high[i]*pr+hi_avg[i-1]*(1.0-pr);
                  lo_avg[i]=m_src_low[i]*pr+lo_avg[i-1]*(1.0-pr);
                 }
               else
                 {
                  hi_avg[i]=(hi_avg[i-1]*(m_period-1)+m_src_high[i])/m_period;
                  lo_avg[i]=(lo_avg[i-1]*(m_period-1)+m_src_low[i])/m_period;
                 }
              }
            break;
         case MODE_LWMA:
           {double wh=0,wl=0,ws=0; for(int j=0; j<m_period; j++) {int w=m_period-j; wh+=m_src_high[i-j]*w; wl+=m_src_low[i-j]*w; ws+=w;} if(ws>0) {hi_avg[i]=wh/ws; lo_avg[i]=wl/ws;}}
         break;
         default:
           {double sh=0,sl=0; for(int j=0; j<m_period; j++) {sh+=m_src_high[i-j]; sl+=m_src_low[i-j];} hi_avg[i]=sh/m_period; lo_avg[i]=sl/m_period;}
         break;
        }

      if(i < m_period)
         continue;

      if(m_src_close[i] > hi_avg[i-1])
         trend[i] = 1;
      else
         if(m_src_close[i] < lo_avg[i-1])
            trend[i] = -1;
         else
            trend[i] = trend[i-1];

      if(trend[i] == 1)
        {
         hilo_buffer[i] = lo_avg[i];
         color_buffer[i] = 0;
         if(trend[i-1] == -1)
            hilo_buffer[i-1] = lo_avg[i];
        }
      else
        {
         hilo_buffer[i] = hi_avg[i];
         color_buffer[i] = 1;
         if(trend[i-1] == 1)
            hilo_buffer[i-1] = hi_avg[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| CGannHiLoCalculator: Prepares the standard source data series.   |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CGannHiLoCalculator_HA (Heikin Ashi)          |
//|                                                                  |
//+==================================================================+
class CGannHiLoCalculator_HA : public CGannHiLoCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CGannHiLoCalculator_HA: Prepares the Heikin Ashi source data.    |
//+------------------------------------------------------------------+
bool CGannHiLoCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(m_src_high, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayResize(m_src_close, rates_total);

   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_src_high, m_src_low, m_src_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
