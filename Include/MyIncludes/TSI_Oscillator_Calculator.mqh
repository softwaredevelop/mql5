//+------------------------------------------------------------------+
//|                                      TSI_Oscillator_Calculator.mqh|
//|    Wrapper for the TSI_Engine to produce Oscillator output.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\TSI_Engine.mqh>

//--- Base class for polymorphism
class CTSICalculatorOscillator
  {
public:
   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma)=0;
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[])=0;
  };

//--- Standard version
class CTSICalculatorOscillator_Std : public CTSICalculatorOscillator
  {
protected:
   CTSICalculator    *m_engine;
public:
                     CTSICalculatorOscillator_Std(void) { m_engine = new CTSICalculator(); }
                    ~CTSICalculatorOscillator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override { return m_engine.Init(slow_p, fast_p, signal_p, signal_ma); }
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double tsi_values[], signal_values[];
      ArrayResize(tsi_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, price_type, open, high, low, close, tsi_values, signal_values);

      int start_pos = m_engine.GetPeriodSlow() + m_engine.GetPeriodFast() + m_engine.GetPeriodSignal() - 1;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = tsi_values[i] - signal_values[i];
        }
     }
  };

//--- HA version
class CTSICalculatorOscillator_HA : public CTSICalculatorOscillator
  {
protected:
   CTSICalculator    *m_engine;
public:
                     CTSICalculatorOscillator_HA(void) { m_engine = new CTSICalculator_HA(); }
                    ~CTSICalculatorOscillator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override { return m_engine.Init(slow_p, fast_p, signal_p, signal_ma); }
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double tsi_values[], signal_values[];
      ArrayResize(tsi_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, price_type, open, high, low, close, tsi_values, signal_values);

      int start_pos = m_engine.GetPeriodSlow() + m_engine.GetPeriodFast() + m_engine.GetPeriodSignal() - 1;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = tsi_values[i] - signal_values[i];
        }
     }
  };
//+------------------------------------------------------------------+
