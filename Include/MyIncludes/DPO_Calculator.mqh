//+------------------------------------------------------------------+
//|                                               DPO_Calculator.mqh |
//|      Engine for calculating the Detrended Price Oscillator.      |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CDPOCalculator (Base Class)                 |
//+==================================================================+
class CDPOCalculator
  {
protected:
   int               m_period;
   CMovingAverageCalculator *m_ma_calc;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_ma_buffer[];

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CDPOCalculator(void);
   virtual          ~CDPOCalculator(void);

   bool              Init(int period, ENUM_MA_TYPE ma_type);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &dpo_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDPOCalculator::CDPOCalculator(void)
  {
   m_ma_calc = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDPOCalculator::~CDPOCalculator(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CDPOCalculator::Init(int period, ENUM_MA_TYPE ma_type)
  {
   m_period = period;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return false;
   return m_ma_calc.Init(period, ma_type);
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CDPOCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &dpo_buffer[])
  {
   if(rates_total < m_period)
      return;
   if(CheckPointer(m_ma_calc) == POINTER_INVALID)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_ma_buffer, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- Step 1: Calculate the standard, lagging MA into an internal buffer (Incremental)
   m_ma_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_ma_buffer);

//--- Step 2: Calculate DPO (Incremental Loop)
   int shift = (m_period / 2) + 1;
   int loop_start = MathMax(shift, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      int source_index = i - shift;
      // Ensure we don't access out of bounds or empty values
      if(source_index >= 0 && m_ma_buffer[source_index] != EMPTY_VALUE && m_ma_buffer[source_index] != 0.0)
         dpo_buffer[i] = m_price[i] - m_ma_buffer[source_index];
      else
         dpo_buffer[i] = EMPTY_VALUE;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CDPOCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CDPOCalculator_HA (Heikin Ashi)             |
//+==================================================================+
class CDPOCalculator_HA : public CDPOCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

public:
                     CDPOCalculator_HA(void);
protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Constructor (HA)                                                 |
//+------------------------------------------------------------------+
CDPOCalculator_HA::CDPOCalculator_HA(void)
  {
   if(CheckPointer(m_ma_calc) != POINTER_INVALID)
      delete m_ma_calc;
// CRITICAL: Use HA Engine to calculate MA on HA prices
   m_ma_calc = new CMovingAverageCalculator_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CDPOCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

// Fill m_price with the selected HA price type
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
