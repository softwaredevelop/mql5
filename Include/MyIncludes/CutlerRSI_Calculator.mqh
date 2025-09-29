//+------------------------------------------------------------------+
//|                                           CutlerRSI_Calculator.mqh|
//|      Wrapper for the CutlerRSI_Engine to produce RSI output.     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CutlerRSI_Engine.mqh>

//--- Abstract base class for polymorphism
class CCutlerRSICalculator
  {
public:
   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m)=0;
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[])=0;
  };

//--- Standard version uses the standard engine
class CCutlerRSICalculator_Std : public CCutlerRSICalculator
  {
protected:
   CCutlerRSI_Engine *m_engine;
public:
                     CCutlerRSICalculator_Std(void) { m_engine = new CCutlerRSI_Engine(); }
                    ~CCutlerRSICalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(rsi_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, open, high, low, close, price_type, rsi_buffer, signal_buffer);
     }
  };

//--- HA version uses the HA engine
class CCutlerRSICalculator_HA : public CCutlerRSICalculator
  {
protected:
   CCutlerRSI_Engine *m_engine;
public:
                     CCutlerRSICalculator_HA(void) { m_engine = new CCutlerRSI_Engine_HA(); }
                    ~CCutlerRSICalculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(rsi_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &rsi_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, open, high, low, close, price_type, rsi_buffer, signal_buffer);
     }
  };
//+------------------------------------------------------------------+
