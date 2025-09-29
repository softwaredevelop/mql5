//+------------------------------------------------------------------+
//|                                               CHO_Calculator.mqh |
//|         Calculation engine for Standard and Heikin Ashi CHO.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//--- Re-use the AD calculator we built previously ---
#include <MyIncludes\AD_Calculator.mqh>

//+==================================================================+
//|                                                                  |
//|             CLASS 1: CCHOCalculator (Base Class)                 |
//|                                                                  |
//+==================================================================+
class CCHOCalculator
  {
protected:
   int               m_fast_period;
   int               m_slow_period;
   ENUM_MA_METHOD    m_ma_method;
   ENUM_APPLIED_VOLUME m_volume_type;

   //--- It contains a pointer to a base AD calculator
   CADCalculator     *m_ad_calculator;

public:
                     CCHOCalculator(void);
   virtual          ~CCHOCalculator(void);

   //--- Public methods
   bool              Init(int fast_p, int slow_p, ENUM_MA_METHOD ma_m, ENUM_APPLIED_VOLUME vol_t);
   int               GetSlowPeriod(void) const { return m_slow_period; }
   //--- CORRECTED: Added 'open' array to the signature
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], double &cho_buffer[]);
  };

//+------------------------------------------------------------------+
//| CCHOCalculator: Constructor                                      |
//+------------------------------------------------------------------+
CCHOCalculator::CCHOCalculator(void)
  {
//--- The base class creates a standard AD calculator instance
   m_ad_calculator = new CADCalculator();
  }

//+------------------------------------------------------------------+
//| CCHOCalculator: Destructor                                       |
//+------------------------------------------------------------------+
CCHOCalculator::~CCHOCalculator(void)
  {
//--- Clean up the contained object
   if(CheckPointer(m_ad_calculator) != POINTER_INVALID)
      delete m_ad_calculator;
  }

//+------------------------------------------------------------------+
//| CCHOCalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CCHOCalculator::Init(int fast_p, int slow_p, ENUM_MA_METHOD ma_m, ENUM_APPLIED_VOLUME vol_t)
  {
   m_fast_period = (fast_p < 1) ? 1 : fast_p;
   m_slow_period = (slow_p < 1) ? 1 : slow_p;

   if(m_fast_period > m_slow_period)
     {
      int temp = m_fast_period;
      m_fast_period = m_slow_period;
      m_slow_period = temp;
     }

   m_ma_method = ma_m;
   m_volume_type = vol_t;

   return (CheckPointer(m_ad_calculator) != POINTER_INVALID);
  }

//+------------------------------------------------------------------+
//| CCHOCalculator: Main Calculation Method                          |
//+------------------------------------------------------------------+
void CCHOCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], double &cho_buffer[])
  {
   if(rates_total < m_slow_period || CheckPointer(m_ad_calculator) == POINTER_INVALID)
      return;

//--- Internal buffers
   double adl[], fast_ma[], slow_ma[];
   ArrayResize(adl, rates_total);
   ArrayResize(fast_ma, rates_total);
   ArrayResize(slow_ma, rates_total);

//--- STEP 1: Calculate ADL using the contained calculator
//--- CORRECTED: Pass the 'open' array to the AD calculator
   m_ad_calculator.Calculate(rates_total, open, high, low, close, tick_volume, volume, m_volume_type, adl);

//--- STEP 2: Calculate Fast MA on ADL
   for(int i = m_fast_period - 1; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_fast_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_fast_period; j++)
                  sum+=adl[i-j];
               fast_ma[i] = sum/m_fast_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_fast_period+1.0);
                  fast_ma[i] = adl[i]*pr + fast_ma[i-1]*(1.0-pr);
                 }
               else
                  fast_ma[i] = (fast_ma[i-1]*(m_fast_period-1)+adl[i])/m_fast_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_fast_period; j++) {int weight=m_fast_period-j; lwma_sum+=adl[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) fast_ma[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_fast_period; j++) sum+=adl[i-j]; fast_ma[i] = sum/m_fast_period;}
         break;
        }
     }

//--- STEP 3: Calculate Slow MA on ADL
   for(int i = m_slow_period - 1; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == m_slow_period - 1)
              {
               double sum=0;
               for(int j=0; j<m_slow_period; j++)
                  sum+=adl[i-j];
               slow_ma[i] = sum/m_slow_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr=2.0/(m_slow_period+1.0);
                  slow_ma[i] = adl[i]*pr + slow_ma[i-1]*(1.0-pr);
                 }
               else
                  slow_ma[i] = (slow_ma[i-1]*(m_slow_period-1)+adl[i])/m_slow_period;
              }
            break;
         case MODE_LWMA:
           {double lwma_sum=0, weight_sum=0; for(int j=0; j<m_slow_period; j++) {int weight=m_slow_period-j; lwma_sum+=adl[i-j]*weight; weight_sum+=weight;} if(weight_sum>0) slow_ma[i]=lwma_sum/weight_sum;}
         break;
         default:
           {double sum=0; for(int j=0; j<m_slow_period; j++) sum+=adl[i-j]; slow_ma[i] = sum/m_slow_period;}
         break;
        }
     }

//--- STEP 4: Calculate final Chaikin Oscillator value
   for(int i = m_slow_period - 1; i < rates_total; i++)
     {
      cho_buffer[i] = fast_ma[i] - slow_ma[i];
     }
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CCHOCalculator_HA (Heikin Ashi)               |
//|                                                                  |
//+==================================================================+
class CCHOCalculator_HA : public CCHOCalculator
  {
public:
                     CCHOCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//| CCHOCalculator_HA: Constructor                                   |
//+------------------------------------------------------------------+
CCHOCalculator_HA::CCHOCalculator_HA(void)
  {
//--- Clean up the base class's standard calculator first
   if(CheckPointer(m_ad_calculator) != POINTER_INVALID)
      delete m_ad_calculator;

//--- The derived class creates a Heikin Ashi AD calculator instance instead
   m_ad_calculator = new CADCalculator_HA();
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 3: CCHOCalculator_Std (Standard)                 |
//|                                                                  |
//+==================================================================+
// This is just for consistency in naming, it inherits everything from the base.
class CCHOCalculator_Std : public CCHOCalculator
  {
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
