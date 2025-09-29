//+------------------------------------------------------------------+
//|                                     CCI_Oscillator_Calculator.mqh|
//|    Wrapper for the CCI_Engine to produce Oscillator output.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CCI_Engine.mqh>

//--- Base class for polymorphism
class CCCI_OscillatorCalculator
  {
public:
   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m)=0;
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[])=0;
  };

//--- Standard version
class CCCI_OscillatorCalculator_Std : public CCCI_OscillatorCalculator
  {
protected:
   CCCI_Engine       *m_engine;
public:
                     CCCI_OscillatorCalculator_Std(void) { m_engine = new CCCI_Engine(); }
                    ~CCCI_OscillatorCalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(cci_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double cci_values[], signal_values[];
      ArrayResize(cci_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, open, high, low, close, price_type, cci_values, signal_values);

      int start_pos = m_engine.GetPeriodCCI() + m_engine.GetPeriodMA() - 2;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = cci_values[i] - signal_values[i];
        }
     }
  };

//--- HA version
class CCCI_OscillatorCalculator_HA : public CCCI_OscillatorCalculator
  {
protected:
   CCCI_Engine       *m_engine;
public:
                     CCCI_OscillatorCalculator_HA(void) { m_engine = new CCCI_Engine_HA(); }
                    ~CCCI_OscillatorCalculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(cci_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double cci_values[], signal_values[];
      ArrayResize(cci_values, rates_total);
      ArrayResize(signal_values, rates_total);

      m_engine.Calculate(rates_total, open, high, low, close, price_type, cci_values, signal_values);

      int start_pos = m_engine.GetPeriodCCI() + m_engine.GetPeriodMA() - 2;
      for(int i = start_pos; i < rates_total; i++)
        {
         osc_buffer[i] = cci_values[i] - signal_values[i];
        }
     }
  };
//+------------------------------------------------------------------+
