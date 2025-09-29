//+------------------------------------------------------------------+
//|                                 CutlerRSI_Oscillator_Calculator.mqh|
//|  Wrapper for the CutlerRSI_Engine to produce Oscillator output.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CutlerRSI_Engine.mqh>

//--- Base class for polymorphism
class CCutlerRSI_OscillatorCalculator
  {
public:
   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m)=0;
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[])=0;
  };

//--- Standard version
class CCutlerRSI_OscillatorCalculator_Std : public CCutlerRSI_OscillatorCalculator
  {
protected:
   CCutlerRSI_Engine *m_engine;
public:
                     CCutlerRSI_OscillatorCalculator_Std(void) { m_engine = new CCutlerRSI_Engine(); }
                    ~CCutlerRSI_OscillatorCalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(rsi_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double rsi_values[], signal_values[];
      ArrayResize(rsi_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, open, high, low, close, price_type, rsi_values, signal_values);

      int start_pos = m_engine.GetPeriodRSI() + m_engine.GetPeriodMA() - 1;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = rsi_values[i] - signal_values[i];
        }
     }
  };

//--- HA version
class CCutlerRSI_OscillatorCalculator_HA : public CCutlerRSI_OscillatorCalculator
  {
protected:
   CCutlerRSI_Engine *m_engine;
public:
                     CCutlerRSI_OscillatorCalculator_HA(void) { m_engine = new CCutlerRSI_Engine_HA(); }
                    ~CCutlerRSI_OscillatorCalculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(rsi_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double rsi_values[], signal_values[];
      ArrayResize(rsi_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, open, high, low, close, price_type, rsi_values, signal_values);

      int start_pos = m_engine.GetPeriodRSI() + m_engine.GetPeriodMA() - 1;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = rsi_values[i] - signal_values[i];
        }
     }
  };
//+------------------------------------------------------------------+
