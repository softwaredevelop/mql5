//+------------------------------------------------------------------+
//|                                              RSIH_Calculator.mqh |
//|    Calculation engine for Ehlers' RSI with Hann Windowing (RSIH) |
//|    and Noise Elimination Technology (NET).                       |
//|    VERSION 2.00: Optimized for incremental calculation.          |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\Windowed_MA_Calculator.mqh>

//+==================================================================+
//|             CLASS 1: CRSIHCalculator (Base Class)                |
//+==================================================================+
class CRSIHCalculator
  {
protected:
   int               m_period_rsi;
   int               m_period_net;

   //--- Composition: Windowed MA Engines for CU and CD
   CWindowedMACalculator *m_cu_engine;
   CWindowedMACalculator *m_cd_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_cu_raw[]; // Raw Closes Up
   double            m_cd_raw[]; // Raw Closes Down
   double            m_cu_smooth[]; // Smoothed CU
   double            m_cd_smooth[]; // Smoothed CD

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);
   virtual void      CreateEngines(void);

public:
                     CRSIHCalculator(void);
   virtual          ~CRSIHCalculator(void);

   bool              Init(int rsi_period, int net_period);
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &rsih_buffer[], double &net_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRSIHCalculator::CRSIHCalculator(void)
  {
   m_cu_engine = NULL;
   m_cd_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRSIHCalculator::~CRSIHCalculator(void)
  {
   if(CheckPointer(m_cu_engine) != POINTER_INVALID)
      delete m_cu_engine;
   if(CheckPointer(m_cd_engine) != POINTER_INVALID)
      delete m_cd_engine;
  }

//+------------------------------------------------------------------+
//| Factory Method                                                   |
//+------------------------------------------------------------------+
void CRSIHCalculator::CreateEngines(void)
  {
   m_cu_engine = new CWindowedMACalculator();
   m_cd_engine = new CWindowedMACalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CRSIHCalculator::Init(int rsi_period, int net_period)
  {
   m_period_rsi = (rsi_period < 2) ? 2 : rsi_period;
   m_period_net = (net_period < 2) ? 2 : net_period;

   CreateEngines();

// Initialize engines with SOURCE_PRICE (we pass raw CU/CD arrays)
   if(CheckPointer(m_cu_engine) == POINTER_INVALID || !m_cu_engine.Init(m_period_rsi, SOURCE_PRICE))
      return false;
   if(CheckPointer(m_cd_engine) == POINTER_INVALID || !m_cd_engine.Init(m_period_rsi, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CRSIHCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                double &rsih_buffer[], double &net_buffer[])
  {
   if(rates_total < m_period_rsi + 1)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_cu_raw, rates_total);
      ArrayResize(m_cd_raw, rates_total);
      ArrayResize(m_cu_smooth, rates_total);
      ArrayResize(m_cd_smooth, rates_total);
     }

// 1. Prepare Price
   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// 2. Calculate Raw CU and CD
   int loop_start = MathMax(1, start_index);
   for(int i = loop_start; i < rates_total; i++)
     {
      double diff = m_price[i] - m_price[i-1];
      m_cu_raw[i] = (diff > 0) ? diff : 0;
      m_cd_raw[i] = (diff < 0) ? -diff : 0;
     }

// 3. Smooth CU and CD using Windowed MA Engine
   m_cu_engine.CalculateOnArray(rates_total, prev_calculated, m_cu_raw, m_cu_smooth);
   m_cd_engine.CalculateOnArray(rates_total, prev_calculated, m_cd_raw, m_cd_smooth);

// 4. Calculate RSIH
   int rsih_start = MathMax(m_period_rsi, start_index);
   for(int i = rsih_start; i < rates_total; i++)
     {
      double sum = m_cu_smooth[i] + m_cd_smooth[i];
      if(sum > 0)
         rsih_buffer[i] = (m_cu_smooth[i] - m_cd_smooth[i]) / sum;
      else
         rsih_buffer[i] = (i > 0) ? rsih_buffer[i-1] : 0.0;
     }

// 5. Calculate NET (Noise Elimination Technology)
   if(m_period_net > 0)
     {
      double denominator = 0.5 * m_period_net * (m_period_net - 1);
      int net_start = MathMax(m_period_rsi + m_period_net, start_index);

      for(int i = net_start; i < rates_total; i++)
        {
         double numerator = 0;
         // Double loop for Kendall correlation
         for(int j = 1; j < m_period_net; j++)
           {
            for(int k = 0; k < j; k++)
              {
               // Sign(X[fresher] - X[older])
               double diff = rsih_buffer[i-k] - rsih_buffer[i-j];
               numerator += (diff > 0 ? 1 : (diff < 0 ? -1 : 0));
              }
           }
         net_buffer[i] = numerator / denominator;
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CRSIHCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2 * close[i]) / 4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CRSIHCalculator_HA (Heikin Ashi)              |
//+==================================================================+
class CRSIHCalculator_HA : public CRSIHCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi)                                      |
//+------------------------------------------------------------------+
bool CRSIHCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2 * m_ha_close[i]) / 4.0;
            break;
         default:
            m_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
