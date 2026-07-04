//+------------------------------------------------------------------+
//|                                 Fisher_Transform_Calculator.mqh  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.12" // Fully corrected class implementation and dynamic initialization

#ifndef FISHER_TRANSFORM_CALCULATOR_MQH
#define FISHER_TRANSFORM_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Enum for Signal Line Type
enum ENUM_FISHER_SIGNAL_TYPE
  {
   SIGNAL_DELAY_1BAR, // Classic Ehlers (1-Bar Delay)
   SIGNAL_MA          // Custom Moving Average (Supports VWMA)
  };

//+==================================================================+
//|           CLASS 1: CFisherTransformCalculator (Base Class)       |
//+==================================================================+
class CFisherTransformCalculator
  {
protected:
   int               m_period;
   double            m_alpha;

   //--- Signal Settings
   ENUM_FISHER_SIGNAL_TYPE m_signal_type;
   int                     m_signal_period;
   ENUM_MA_TYPE            m_signal_method;

   //--- Composition
   CMovingAverageCalculator *m_signal_engine;

   //--- Persistent Buffers for Incremental Calculation
   double            m_price[];
   double            m_volume[]; // Local volume double buffer for VWMA support
   double            m_value1[]; // Smoothed normalized price
   double            m_fish[];   // Fisher Transform value

   //--- Updated: Accepts start_index
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CFisherTransformCalculator(void);
   virtual          ~CFisherTransformCalculator(void);

   bool              Init(int period, double alpha, ENUM_FISHER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method);

   //--- Standard Calculate (Without volume data) - Redirects to overloaded with dummy volume fallback
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &fisher_buffer[], double &signal_buffer[]);

   //--- Overloaded Calculate with Volume (Specifically for VWMA support)
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &fisher_buffer[], double &signal_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFisherTransformCalculator::CFisherTransformCalculator(void)
  {
   m_signal_engine = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFisherTransformCalculator::~CFisherTransformCalculator(void)
  {
   if(CheckPointer(m_signal_engine) != POINTER_INVALID)
      delete m_signal_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::Init(int period, double alpha, ENUM_FISHER_SIGNAL_TYPE sig_type, int sig_period, ENUM_MA_TYPE sig_method)
  {
   m_period = (period < 2) ? 2 : period;
   m_alpha  = alpha;
   m_signal_type = sig_type;
   m_signal_period = (sig_period < 1) ? 1 : sig_period;
   m_signal_method = sig_method;

   if(m_signal_type == SIGNAL_MA)
     {
      m_signal_engine = new CMovingAverageCalculator();
      if(CheckPointer(m_signal_engine) == POINTER_INVALID || !m_signal_engine.Init(m_signal_period, m_signal_method))
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard OHLC) - Dummy Volume Fallback Pattern        |
//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      double &fisher_buffer[], double &signal_buffer[])
  {
   long dummy_vol[];
   ArrayResize(dummy_vol, rates_total);
   ArrayInitialize(dummy_vol, 1);
   Calculate(rates_total, prev_calculated, open, high, low, close, dummy_vol, fisher_buffer, signal_buffer);
  }

//+------------------------------------------------------------------+
//| Overloaded Calculate (OHLC) with Volume                          |
//+------------------------------------------------------------------+
void CFisherTransformCalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[],
      const long &volume[],
      double &fisher_buffer[], double &signal_buffer[])
  {
   if(rates_total < m_period)
      return;

//--- 1. Determine Start Index
   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

//--- 2. Resize Buffers & force strict chronological sorting
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      ArrayResize(m_volume, rates_total);
      ArrayResize(m_value1, rates_total);
      ArrayResize(m_fish, rates_total);

      ArraySetAsSeries(m_price, false);
      ArraySetAsSeries(m_volume, false);
      ArraySetAsSeries(m_value1, false);
      ArraySetAsSeries(m_fish, false);
     }

//--- 3. Prepare Price (Optimized)
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
      m_volume[i] = (double)volume[i];

//--- 4. Calculate Fisher Transform (Incremental Loop)
   int loop_start = MathMax(m_period - 1, start_index);

   for(int i = loop_start; i < rates_total; i++)
     {
      // Find Highest High and Lowest Low over period
      int high_idx = ArrayMaximum(m_price, i - m_period + 1, m_period);
      int low_idx  = ArrayMinimum(m_price, i - m_period + 1, m_period);
      double maxH = m_price[high_idx];
      double minL = m_price[low_idx];

      double norm_price = 0.0;
      if(maxH - minL != 0)
         norm_price = 2.0 * ((m_price[i] - minL) / (maxH - minL) - 0.5);

      // Recursive smoothing using persistent buffer [i-1]
      double value1_prev = (i > 0) ? m_value1[i-1] : 0;
      m_value1[i] = m_alpha * norm_price + (1.0 - m_alpha) * value1_prev;

      // Clamp value to avoid log error
      if(m_value1[i] > 0.999)
         m_value1[i] = 0.999;
      if(m_value1[i] < -0.999)
         m_value1[i] = -0.999;

      // Fisher calculation
      double fish_prev = (i > 0) ? m_fish[i-1] : 0;
      m_fish[i] = 0.5 * log((1.0 + m_value1[i]) / (1.0 - m_value1[i])) + 0.5 * fish_prev;

      fisher_buffer[i] = m_fish[i];
     }

//--- 5. Calculate Signal Line
   if(m_signal_type == SIGNAL_DELAY_1BAR)
     {
      for(int i = loop_start; i < rates_total; i++)
         signal_buffer[i] = m_fish[i-1];
     }
   else // SIGNAL_MA (Smoothed Moving Average supporting Volume-Weighting / VWMA)
     {
      if(CheckPointer(m_signal_engine) != POINTER_INVALID)
        {
         // Map calculated m_fish buffer as close source, and m_volume double buffer as volume source
         m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_fish, m_volume, signal_buffer, m_period - 1);
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // Ehlers uses (High+Low)/2
      m_price[i] = (high[i] + low[i]) / 2.0;
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CFisherTransformCalculator_HA               |
//+==================================================================+
class CFisherTransformCalculator_HA : public CFisherTransformCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CFisherTransformCalculator_HA::PreparePriceSeries(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open, false);
      ArraySetAsSeries(m_ha_high, false);
      ArraySetAsSeries(m_ha_low, false);
      ArraySetAsSeries(m_ha_close, false);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_price[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
     }
   return true;
  }
#endif // FISHER_TRANSFORM_CALCULATOR_MQH
//+------------------------------------------------------------------+
