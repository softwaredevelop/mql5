//+------------------------------------------------------------------+
//|                                               DPO_Calculator.mqh |
//|      Engine for calculating the Detrended Price Oscillator.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
class CDPOCalculator
  {
protected:
   int               m_period;
   CMovingAverageCalculator *m_ma_calc;
   double            m_price[]; // Internal price buffer

   virtual bool      PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDPOCalculator(void);
   virtual          ~CDPOCalculator(void);

   bool              Init(int period, ENUM_MA_TYPE ma_type);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &dpo_buffer[]);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDPOCalculator_HA : public CDPOCalculator
  {
public:
                     CDPOCalculator_HA(void);
  };

//+==================================================================+
//|                 METHOD IMPLEMENTATIONS                           |
//+==================================================================+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDPOCalculator::CDPOCalculator(void) { m_ma_calc = new CMovingAverageCalculator(); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDPOCalculator::~CDPOCalculator(void) { if(CheckPointer(m_ma_calc) != POINTER_INVALID) delete m_ma_calc; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDPOCalculator_HA::CDPOCalculator_HA(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
   m_ma_calc = new CMovingAverageCalculator_HA();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDPOCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = period;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return false;
   return m_ma_calc.Init(period, ma_type);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDPOCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &dpo_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return;
   if(!PreparePriceSeries(rates_total, price_type, open, high, low, close))
      return;

//--- Step 1: Calculate the standard, lagging MA into an internal buffer ---
   double ma_buffer[];
   ArrayResize(ma_buffer, rates_total);
   m_ma_calc.Calculate(rates_total, price_type, open, high, low, close, ma_buffer);

//--- Step 2: Calculate DPO by subtracting the shifted MA from the price ---
   int shift = (m_period / 2) + 1;

   for(int i = 0; i < rates_total; i++)
     {
      int source_index = i - shift;
      if(source_index >= 0 && ma_buffer[source_index] != EMPTY_VALUE)
         dpo_buffer[i] = m_price[i] - ma_buffer[source_index];
      else
         dpo_buffer[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CDPOCalculator::PreparePriceSeries(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_price) != rates_total)
      if(ArrayResize(m_price, rates_total) != rates_total)
         return false;

   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
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
            m_price[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
      default:
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
