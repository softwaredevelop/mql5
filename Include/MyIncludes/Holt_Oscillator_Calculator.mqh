//+------------------------------------------------------------------+
//|                                     Holt_Oscillator_Calculator.mqh|
//|      Wrapper for the Holt_Engine to produce Oscillator output.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Holt_Engine.mqh>

//--- Base class for polymorphism
class CHoltOscillatorCalculator
  {
public:
   virtual bool      Init(int period, double alpha, double beta)=0;
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &osc_buffer[])=0;
  };

//--- Standard version
class CHoltOscillatorCalculator_Std : public CHoltOscillatorCalculator
  {
protected:
   CHoltEngine       *m_engine;
public:
                     CHoltOscillatorCalculator_Std(void) { m_engine = new CHoltEngine(); }
                    ~CHoltOscillatorCalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int period, double alpha, double beta) override { return m_engine.Init(period, alpha, beta, 1); } // Forecast period is not used
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double dummy_forecast[], dummy_level[], dummy_upper[], dummy_lower[];
      ArrayResize(dummy_forecast, rates_total);
      ArrayResize(dummy_level, rates_total);
      ArrayResize(dummy_upper, rates_total);
      ArrayResize(dummy_lower, rates_total);

      // Pass the osc_buffer to the correct 'trend_out' parameter
      m_engine.Calculate(rates_total, price_type, open, high, low, close, dummy_forecast, osc_buffer, dummy_level, dummy_upper, dummy_lower);
     }
  };

//--- HA version
class CHoltOscillatorCalculator_HA : public CHoltOscillatorCalculator
  {
protected:
   CHoltEngine       *m_engine;
public:
                     CHoltOscillatorCalculator_HA(void) { m_engine = new CHoltEngine_HA(); }
                    ~CHoltOscillatorCalculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int period, double alpha, double beta) override { return m_engine.Init(period, alpha, beta, 1); } // Forecast period is not used
   virtual void      Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &osc_buffer[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      double dummy_forecast[], dummy_level[], dummy_upper[], dummy_lower[];
      ArrayResize(dummy_forecast, rates_total);
      ArrayResize(dummy_level, rates_total);
      ArrayResize(dummy_upper, rates_total);
      ArrayResize(dummy_lower, rates_total);

      // Pass the osc_buffer to the correct 'trend_out' parameter
      m_engine.Calculate(rates_total, price_type, open, high, low, close, dummy_forecast, osc_buffer, dummy_level, dummy_upper, dummy_lower);
     }
  };
//+------------------------------------------------------------------+
