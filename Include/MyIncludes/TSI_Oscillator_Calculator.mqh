//+------------------------------------------------------------------+
//|                                      TSI_Oscillator_Calculator.mqh|
//|    Wrapper for the TSI Calculator to produce Oscillator output.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\TSI_Calculator.mqh>

//--- Base class for polymorphism
class CTSICalculatorOscillator
  {
protected:
   //--- Persistent Buffers for Incremental Calculation
   double            m_tsi_buffer[];
   double            m_signal_buffer[];

public:
   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma)=0;

   //--- Updated: Accepts prev_calculated
   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[])=0;

   virtual          ~CTSICalculatorOscillator() {};
  };

//--- Standard version
class CTSICalculatorOscillator_Std : public CTSICalculatorOscillator
  {
protected:
   CTSICalculator    *m_engine;
public:
                     CTSICalculatorOscillator_Std(void) { m_engine = new CTSICalculator(); }
                    ~CTSICalculatorOscillator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override
     {
      return m_engine.Init(slow_p, fast_p, signal_p, signal_ma);
     }

   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      // Resize internal buffers
      if(ArraySize(m_tsi_buffer) != rates_total)
         ArrayResize(m_tsi_buffer, rates_total);
      if(ArraySize(m_signal_buffer) != rates_total)
         ArrayResize(m_signal_buffer, rates_total);

      // Calculate TSI and Signal (Incremental)
      m_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_tsi_buffer, m_signal_buffer);

      // Calculate Oscillator (Incremental Loop)
      int start_pos = m_engine.GetPeriodSlow() + m_engine.GetPeriodFast() + m_engine.GetPeriodSignal() - 1;
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      int loop_start = MathMax(start_pos, start_index);

      for(int i = loop_start; i < rates_total; i++)
        {
         osc_buffer[i] = m_tsi_buffer[i] - m_signal_buffer[i];
        }
     }
  };

//--- HA version
class CTSICalculatorOscillator_HA : public CTSICalculatorOscillator
  {
protected:
   CTSICalculator_HA *m_engine;
public:
                     CTSICalculatorOscillator_HA(void) { m_engine = new CTSICalculator_HA(); }
                    ~CTSICalculatorOscillator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override
     {
      return m_engine.Init(slow_p, fast_p, signal_p, signal_ma);
     }

   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      // Resize internal buffers
      if(ArraySize(m_tsi_buffer) != rates_total)
         ArrayResize(m_tsi_buffer, rates_total);
      if(ArraySize(m_signal_buffer) != rates_total)
         ArrayResize(m_signal_buffer, rates_total);

      // Calculate TSI and Signal (Incremental)
      m_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_tsi_buffer, m_signal_buffer);

      // Calculate Oscillator (Incremental Loop)
      int start_pos = m_engine.GetPeriodSlow() + m_engine.GetPeriodFast() + m_engine.GetPeriodSignal() - 1;
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      int loop_start = MathMax(start_pos, start_index);

      for(int i = loop_start; i < rates_total; i++)
        {
         osc_buffer[i] = m_tsi_buffer[i] - m_signal_buffer[i];
        }
     }
  };
//+------------------------------------------------------------------+
