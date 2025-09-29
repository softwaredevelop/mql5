//+------------------------------------------------------------------+
//|                                               CCI_Calculator.mqh |
//|         Wrapper for the CCI_Engine to produce CCI output.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CCI_Engine.mqh>

//--- This class is an abstract base for polymorphism
class CCCI_Calculator
  {
public:
   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m)=0;
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &cci_buffer[], double &signal_buffer[])=0;
  };

//--- Standard version uses the standard engine
class CCCI_Calculator_Std : public CCCI_Calculator
  {
protected:
   CCCI_Engine       *m_engine;
public:
                     CCCI_Calculator_Std(void) { m_engine = new CCCI_Engine(); }
                    ~CCCI_Calculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(cci_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &cci_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, open, high, low, close, price_type, cci_buffer, signal_buffer);
     }
  };

//--- HA version uses the HA engine
class CCCI_Calculator_HA : public CCCI_Calculator
  {
protected:
   CCCI_Engine       *m_engine;
public:
                     CCCI_Calculator_HA(void) { m_engine = new CCCI_Engine_HA(); }
                    ~CCCI_Calculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int cci_p, int ma_p, ENUM_MA_METHOD ma_m) override { return m_engine.Init(cci_p, ma_p, ma_m); }
   virtual void      Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type, double &cci_buffer[], double &signal_buffer[]) override
     {
      if(CheckPointer(m_engine)!=POINTER_INVALID)
         m_engine.Calculate(rates_total, open, high, low, close, price_type, cci_buffer, signal_buffer);
     }
  };
//+------------------------------------------------------------------+
