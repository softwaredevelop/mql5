//+------------------------------------------------------------------+
//|                                        Cyber_Cycle_Calculator.mqh|
//|      Calculation engine for the John Ehlers' Cyber Cycle.        |
//|      VERSION 3.00: Added flexible Signal Line support.           |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for Signal Line Type
enum ENUM_CYBER_SIGNAL_TYPE
  {
   SIGNAL_DELAY_1BAR, // Classic Ehlers (Cycle[i-1])
   SIGNAL_MA          // Custom Moving Average
  };

//+==================================================================+
//|           CLASS 1: CCyberCycleCalculator (Base Class)            |
//+==================================================================+
class CCyberCycleCalculator
  {
protected:
   double            m_alpha;

   //--- Signal Settings
   ENUM_CYBER_SIGNAL_TYPE m_signal_type;
   int                    m_signal_period;
   ENUM_MA_TYPE           m_signal_method;

   //--- Engines
   CMovingAverageCalculator *m_signal_engine;

   //--- Persistent Buffers
   double            m_price[];
   double            m_smooth[]; // Pre-smoothing buffer
   double            m_cycle[];  // Internal cycle buffer

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CCyberCycleCalculator(void);
   virtual          ~CCyberCycleCalculator(void);

   bool              Init(double alpha, ENUM_CYBER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method);

   //--- Standard Calculation (OHLC)
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &cycle_out[], double &signal_out[]);

   //--- Calculation on Custom Array
   void              CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &cycle_out[], double &signal_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCyberCycleCalculator::CCyberCycleCalculator(void)
  {
   m_signal_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCyberCycleCalculator::~CCyberCycleCalculator(void)
  {
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::Init(double alpha, ENUM_CYBER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method)
  {
   m_alpha = alpha;
   m_signal_type = sig_type;
   m_signal_period = sig_period;
   m_signal_method = sig_method;

   if(m_signal_type == SIGNAL_MA)
     {
      if(!m_signal_engine.Init(m_signal_period, m_signal_method))
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Wrapper for OHLC)                              |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 7)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

// Delegate to generic array calculation
   CalculateOnArray(rates_total, prev_calculated, m_price, cycle_out, signal_out);
  }

//+------------------------------------------------------------------+
//| Calculate On Array (Core Logic)                                  |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::CalculateOnArray(int rates_total, int prev_calculated, const double &src_buffer[], double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 7)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize internal buffers
   if(ArraySize(m_smooth) != rates_total)
     {
      ArrayResize(m_smooth, rates_total);
      ArrayResize(m_cycle, rates_total);
     }

// Main Loop
   int loop_start = MathMax(6, start_index);

// Initialization
   if(loop_start == 6)
     {
      for(int k=0; k<6; k++)
        {
         m_smooth[k] = src_buffer[k];
         m_cycle[k] = 0;
         cycle_out[k] = 0;
         // Signal init handled later or by engine
        }
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // Step 1: Pre-smoothing (4-bar FIR filter)
      m_smooth[i] = (src_buffer[i] + 2.0 * src_buffer[i-1] + 2.0 * src_buffer[i-2] + src_buffer[i-3]) / 6.0;

      // Step 2: Calculate Cyber Cycle
      double term1 = (1.0 - 0.5 * m_alpha) * (1.0 - 0.5 * m_alpha) * (m_smooth[i] - 2.0 * m_smooth[i-1] + m_smooth[i-2]);
      double term2 = 2.0 * (1.0 - m_alpha) * m_cycle[i-1];
      double term3 = (1.0 - m_alpha) * (1.0 - m_alpha) * m_cycle[i-2];

      m_cycle[i] = term1 + term2 - term3;

      // Output
      cycle_out[i] = m_cycle[i];
     }

// Step 3: Signal Line
   if(m_signal_type == SIGNAL_DELAY_1BAR)
     {
      for(int i = loop_start; i < rates_total; i++)
         signal_out[i] = m_cycle[i-1];
     }
   else // SIGNAL_MA
     {
      // Use MA Engine on the Cycle Line
      // Offset: Cyber Cycle needs ~6 bars to start, so offset 6 is safe
      m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_cycle, signal_out, 6);
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard)                                         |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (high[i] + low[i]) / 2.0;
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CCyberCycleCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CCyberCycleCalculator_HA : public CCyberCycleCalculator
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
bool CCyberCycleCalculator_HA::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
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
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
