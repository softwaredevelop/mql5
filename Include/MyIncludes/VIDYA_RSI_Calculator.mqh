//+------------------------------------------------------------------+
//|                                         VIDYA_RSI_Calculator.mqh |
//|      VERSION 2.00: Integrated with RSI Engine.                   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\RSI_Pro_Calculator.mqh>

//+==================================================================+
//|             CLASS 1: CVIDYARSICalculator (Base Class)            |
//+==================================================================+
class CVIDYARSICalculator
  {
protected:
   int               m_rsi_period, m_ema_period;

   //--- Composition: Use dedicated RSI engine
   CRSIProCalculator *m_rsi_calculator;

   //--- Persistent Buffers
   double            m_price[];
   double            m_rsi_buffer[]; // Internal buffer for RSI values

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

   //--- Factory Method for RSI Engine
   virtual void      CreateRSIEngine(void);

public:
                     CVIDYARSICalculator(void);
   virtual          ~CVIDYARSICalculator(void);

   bool              Init(int rsi_p, int ema_p);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &vidya_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVIDYARSICalculator::CVIDYARSICalculator(void)
  {
   m_rsi_calculator = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVIDYARSICalculator::~CVIDYARSICalculator(void)
  {
   if(CheckPointer(m_rsi_calculator) != POINTER_INVALID)
      delete m_rsi_calculator;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CVIDYARSICalculator::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CRSIProCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVIDYARSICalculator::Init(int rsi_p, int ema_p)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ema_period = (ema_p < 1) ? 1 : ema_p;

   CreateRSIEngine();
// Init RSI with dummy MA params (1, SMA, 2.0) as we only need the RSI line
   if(CheckPointer(m_rsi_calculator) == POINTER_INVALID || !m_rsi_calculator.Init(m_rsi_period, 1, SMA, 2.0))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CVIDYARSICalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                    double &vidya_buffer[])
  {
   int start_pos = m_rsi_period + m_ema_period;
   if(rates_total <= start_pos)
      return;

   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);
   if(ArraySize(m_rsi_buffer) != rates_total)
      ArrayResize(m_rsi_buffer, rates_total);

// 1. Prepare Price (for VIDYA calculation)
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Calculate RSI (Delegated to Engine)
// Note: RSI engine handles its own price preparation internally!
// We pass the raw OHLC arrays and price_type.
   double dummy1[], dummy2[], dummy3[];
   m_rsi_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                              m_rsi_buffer, dummy1, dummy2, dummy3);

// 3. Calculate VIDYA (Incremental Loop)
   double alpha = 2.0 / (m_ema_period + 1.0);
   int loop_start = MathMax(start_pos, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      if(i == start_pos) // Initialization
        {
         double sum=0;
         for(int j=0; j<m_ema_period; j++)
            sum+=m_price[i-j];
         vidya_buffer[i]=sum/m_ema_period;
         continue;
        }

      // Use pre-calculated RSI from buffer
      // Volatility factor: distance from 50 (0..50), normalized to 0..1
      double rsi_volatility = MathAbs(m_rsi_buffer[i] - 50.0) / 50.0;

      // Recursive calculation uses vidya_buffer[i-1] which is persistent
      vidya_buffer[i] = m_price[i] * alpha * rsi_volatility + vidya_buffer[i-1] * (1 - alpha * rsi_volatility);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CVIDYARSICalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
//|             CLASS 2: CVIDYARSICalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CVIDYARSICalculator_HA : public CVIDYARSICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
   virtual void      CreateRSIEngine(void) override;
  };

//+------------------------------------------------------------------+
//| Factory Method for HA RSI Engine                                 |
//+------------------------------------------------------------------+
void CVIDYARSICalculator_HA::CreateRSIEngine(void)
  {
   m_rsi_calculator = new CRSIProCalculator_HA();
  }

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CVIDYARSICalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

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
//+------------------------------------------------------------------+
