//+------------------------------------------------------------------+
//|                                     KeltnerChannel_Calculator.mqh|
//| Calculation engine for Standard and Heikin Ashi Keltner Channels.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Re-use the enum from the main file
enum ENUM_ATR_SOURCE
  {
   ATR_SOURCE_STANDARD,    // Calculate ATR from standard candles
   ATR_SOURCE_HEIKIN_ASHI  // Calculate ATR from Heikin Ashi candles
  };

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CKeltnerChannelCalculator (Base Class)        |
//|                                                                  |
//+==================================================================+
class CKeltnerChannelCalculator
  {
protected:
   int               m_ma_period, m_atr_period;
   ENUM_MA_METHOD    m_ma_method;
   double            m_multiplier;
   ENUM_ATR_SOURCE   m_atr_source;

   double            m_ma_price[];

   virtual bool      PrepareMAPriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
                     CKeltnerChannelCalculator(void) {};
   virtual          ~CKeltnerChannelCalculator(void) {};

   bool              Init(int ma_p, ENUM_MA_METHOD ma_m, int atr_p, double mult, ENUM_ATR_SOURCE atr_src);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
                               double &middle_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| CKeltnerChannelCalculator: Initialization                        |
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator::Init(int ma_p, ENUM_MA_METHOD ma_m, int atr_p, double mult, ENUM_ATR_SOURCE atr_src)
  {
   m_ma_period  = (ma_p < 1) ? 1 : ma_p;
   m_ma_method  = ma_m;
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_multiplier = (mult <= 0) ? 2.0 : mult;
   m_atr_source = atr_src;
   return true;
  }

//+------------------------------------------------------------------+
//| CKeltnerChannelCalculator: Main Calculation Method (Shared Logic)|
//+------------------------------------------------------------------+
void CKeltnerChannelCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type,
      double &middle_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int start_pos = MathMax(m_ma_period, m_atr_period);
   if(rates_total <= start_pos)
      return;

   if(!PrepareMAPriceSeries(rates_total, open, high, low, close, price_type))
      return;

   double atr_buffer[], tr[];
   ArrayResize(atr_buffer, rates_total);
   ArrayResize(tr, rates_total);

//--- STEP 1: Calculate True Range based on the selected ATR source
   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
     {
      CHeikinAshi_Calculator ha_calc;
      double ha_open[], ha_high[], ha_low[], ha_close[];
      ArrayResize(ha_open, rates_total);
      ArrayResize(ha_high, rates_total);
      ArrayResize(ha_low, rates_total);
      ArrayResize(ha_close, rates_total);
      ha_calc.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
      for(int i = 1; i < rates_total; i++)
         tr[i] = MathMax(ha_high[i], ha_close[i-1]) - MathMin(ha_low[i], ha_close[i-1]);
     }
   else // ATR_SOURCE_STANDARD
     {
      for(int i = 1; i < rates_total; i++)
         tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);
     }

   for(int i = 1; i < rates_total; i++)
     {
      //--- STEP 2: Calculate ATR (Wilder's smoothing)
      if(i == m_atr_period)
        {
         double sum=0;
         for(int j=1; j<=m_atr_period; j++)
            sum+=tr[j];
         atr_buffer[i]=sum/m_atr_period;
        }
      else
         if(i > m_atr_period)
            atr_buffer[i] = (atr_buffer[i-1]*(m_atr_period-1)+tr[i])/m_atr_period;

      //--- STEP 3: Calculate Middle Line (MA)
      if(i >= m_ma_period - 1)
        {
         switch(m_ma_method)
           {
            case MODE_EMA:
            case MODE_SMMA:
               if(i==m_ma_period-1)
                 {
                  double sum=0;
                  for(int j=0; j<m_ma_period; j++)
                     sum+=m_ma_price[i-j];
                  middle_buffer[i]=sum/m_ma_period;
                 }
               else
                 {
                  if(m_ma_method==MODE_EMA)
                    {
                     double pr=2.0/(m_ma_period+1.0);
                     middle_buffer[i]=m_ma_price[i]*pr+middle_buffer[i-1]*(1.0-pr);
                    }
                  else
                     middle_buffer[i]=(middle_buffer[i-1]*(m_ma_period-1)+m_ma_price[i])/m_ma_period;
                 }
               break;
            case MODE_LWMA:
              {double sum=0,w_sum=0; for(int j=0; j<m_ma_period; j++) {int w=m_ma_period-j; sum+=m_ma_price[i-j]*w; w_sum+=w;} if(w_sum>0) middle_buffer[i]=sum/w_sum;}
            break;
            default:
              {double sum=0; for(int j=0; j<m_ma_period; j++) sum+=m_ma_price[i-j]; middle_buffer[i]=sum/m_ma_period;}
            break;
           }
        }

      //--- STEP 4: Calculate Bands
      if(i >= start_pos)
        {
         upper_buffer[i] = middle_buffer[i] + (atr_buffer[i] * m_multiplier);
         lower_buffer[i] = middle_buffer[i] - (atr_buffer[i] * m_multiplier);
        }
     }
  }

//+------------------------------------------------------------------+
//| CKeltnerChannelCalculator: Prepares the standard MA source price.|
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator::PrepareMAPriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_ma_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_ma_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_ma_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_ma_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_ma_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|       CLASS 2: CKeltnerChannelCalculator_HA                      |
//|                                                                  |
//+==================================================================+
class CKeltnerChannelCalculator_HA : public CKeltnerChannelCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareMAPriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CKeltnerChannelCalculator_HA: Prepares the Heikin Ashi MA source.|
//+------------------------------------------------------------------+
bool CKeltnerChannelCalculator_HA::PrepareMAPriceSeries(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

   ArrayResize(m_ma_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_ma_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_ma_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_ma_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_ma_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default:
         ArrayCopy(m_ma_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
