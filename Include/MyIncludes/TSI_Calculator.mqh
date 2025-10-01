//+------------------------------------------------------------------+
//|                                               TSI_Calculator.mqh |
//|           Wrapper for the TSI_Engine to produce TSI output.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\TSI_Engine.mqh>

//--- Abstract base class for polymorphism
class CTSICalculatorBase
  {
public:
   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma)=0;
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[])=0;
   virtual          ~CTSICalculatorBase() {}; // Virtual destructor
  };

//--- Standard version
class CTSICalculator_Std : public CTSICalculatorBase
  {
protected:
   CTSICalculator    *m_engine;
public:
                     CTSICalculator_Std(void) { m_engine = new CTSICalculator(); }
                    ~CTSICalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return false;
      return m_engine.Init(slow_p, fast_p, signal_p, signal_ma);
     }
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, price_type, open, high, low, close, tsi_buffer, signal_buffer);
     }
  };

//--- HA version
class CTSICalculator_HA_Wrapper : public CTSICalculatorBase // Use a unique name to avoid conflict
  {
protected:
   CTSICalculator_HA *m_engine; // Use the HA engine type
public:
                     CTSICalculator_HA_Wrapper(void) { m_engine = new CTSICalculator_HA(); }
                    ~CTSICalculator_HA_Wrapper(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int slow_p, int fast_p, int signal_p, ENUM_MA_METHOD signal_ma) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return false;
      return m_engine.Init(slow_p, fast_p, signal_p, signal_ma);
     }
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &tsi_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, price_type, open, high, low, close, tsi_buffer, signal_buffer);
     }
  };
//+------------------------------------------------------------------+
