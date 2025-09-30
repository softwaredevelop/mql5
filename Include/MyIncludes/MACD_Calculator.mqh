//+------------------------------------------------------------------+
//|                                               MACD_Calculator.mqh|
//|         Calculation engine for Standard and Heikin Ashi MACD.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CMACDCalculator (Base Class)                |
//|                                                                  |
//+==================================================================+
class CMACDCalculator
  {
protected:
   int               m_fast_period, m_slow_period, m_signal_period;
   ENUM_MA_METHOD    m_source_ma_type, m_signal_ma_type;
   double            m_price[];

   //--- Virtual method for preparing the price series.
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CMACDCalculator(void) {};
   virtual          ~CMACDCalculator(void) {};

   bool              Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &macd_line[], double &signal_line[], double &histogram[]);
  };

//+------------------------------------------------------------------+
//| CMACDCalculator: Initialization                                  |
//+------------------------------------------------------------------+
bool CMACDCalculator::Init(int fast_p, int slow_p, int signal_p, ENUM_MA_METHOD src_ma, ENUM_MA_METHOD sig_ma)
  {
   m_fast_period = (fast_p < 1) ? 1 : fast_p;
   m_slow_period = (slow_p < 1) ? 1 : slow_p;
   if(m_fast_period > m_slow_period)
     {
      int temp=m_fast_period;
      m_fast_period=m_slow_period;
      m_slow_period=temp;
     }
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_source_ma_type = src_ma;
   m_signal_ma_type = sig_ma;
   return true;
  }

//+------------------------------------------------------------------+
//| CMACDCalculator: Main Calculation Method (CORRECTED LOGIC)       |
//+------------------------------------------------------------------+
void CMACDCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                                double &macd_line[], double &signal_line[], double &histogram[])
  {
   int start_pos = m_slow_period + m_signal_period - 2;
   if(rates_total <= start_pos)
      return;

   if(!PreparePriceSeries(rates_total, open, high, low, close, price_type))
      return;

   double fast_ma[], slow_ma[];
   ArrayResize(fast_ma, rates_total);
   ArrayResize(slow_ma, rates_total);

//--- STEP 1: Calculate Fast MA
   for(int i = m_fast_period - 1; i < rates_total; i++)
     {
      switch(m_source_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_fast_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_fast_period; j++)
                  sum+=m_price[i-j];
               fast_ma[i]=sum/m_fast_period;
              }
            else
              {
               if(m_source_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_fast_period+1.0);
                  fast_ma[i]=m_price[i]*pr+fast_ma[i-1]*(1.0-pr);
                 }
               else
                  fast_ma[i]=(fast_ma[i-1]*(m_fast_period-1)+m_price[i])/m_fast_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_fast_period; j++) {int w=m_fast_period-j; sum+=m_price[i-j]*w; w_sum+=w;} if(w_sum>0) fast_ma[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_fast_period; j++) sum+=m_price[i-j]; fast_ma[i]=sum/m_fast_period;}
         break;
        }
     }

//--- STEP 2: Calculate Slow MA
   for(int i = m_slow_period - 1; i < rates_total; i++)
     {
      switch(m_source_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_slow_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_slow_period; j++)
                  sum+=m_price[i-j];
               slow_ma[i]=sum/m_slow_period;
              }
            else
              {
               if(m_source_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_slow_period+1.0);
                  slow_ma[i]=m_price[i]*pr+slow_ma[i-1]*(1.0-pr);
                 }
               else
                  slow_ma[i]=(slow_ma[i-1]*(m_slow_period-1)+m_price[i])/m_slow_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_slow_period; j++) {int w=m_slow_period-j; sum+=m_price[i-j]*w; w_sum+=w;} if(w_sum>0) slow_ma[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_slow_period; j++) sum+=m_price[i-j]; slow_ma[i]=sum/m_slow_period;}
         break;
        }
     }

//--- STEP 3: Calculate MACD Line
   for(int i = m_slow_period - 1; i < rates_total; i++)
     {
      macd_line[i] = fast_ma[i] - slow_ma[i];
     }

//--- STEP 4: Calculate Signal Line
   int signal_start_pos = m_slow_period + m_signal_period - 2;
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      switch(m_signal_ma_type)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == signal_start_pos)
              {
               double sum=0;
               for(int j=0; j<m_signal_period; j++)
                  sum+=macd_line[i-j];
               signal_line[i]=sum/m_signal_period;
              }
            else
              {
               if(m_signal_ma_type==MODE_EMA)
                 {
                  double pr=2.0/(m_signal_period+1.0);
                  signal_line[i]=macd_line[i]*pr+signal_line[i-1]*(1.0-pr);
                 }
               else
                  signal_line[i]=(signal_line[i-1]*(m_signal_period-1)+macd_line[i])/m_signal_period;
              }
            break;
         case MODE_LWMA:
           {double sum=0,w_sum=0; for(int j=0; j<m_signal_period; j++) {int w=m_signal_period-j; sum+=macd_line[i-j]*w; w_sum+=w;} if(w_sum>0) signal_line[i]=sum/w_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_signal_period; j++) sum+=macd_line[i-j]; signal_line[i]=sum/m_signal_period;}
         break;
        }
     }

//--- STEP 5: Calculate Histogram
   for(int i = signal_start_pos; i < rates_total; i++)
     {
      histogram[i] = macd_line[i] - signal_line[i];
     }
  }

//+------------------------------------------------------------------+
//| CMACDCalculator: Prepares the standard source price series.      |
//+------------------------------------------------------------------+
bool CMACDCalculator::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_price, rates_total);
   switch(price_type)
     {
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
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CMACDCalculator_HA (Heikin Ashi)              |
//|                                                                  |
//+==================================================================+
class CMACDCalculator_HA : public CMACDCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CMACDCalculator_HA: Prepares the Heikin Ashi source price.       |
//+------------------------------------------------------------------+
bool CMACDCalculator_HA::PreparePriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
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
            m_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
