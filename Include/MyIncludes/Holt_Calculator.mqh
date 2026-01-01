//+------------------------------------------------------------------+
//|                                             Holt_Calculator.mqh  |
//|         Wrapper for the Holt_Engine to produce MA/Channel output.|
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Holt_Engine.mqh>

//--- Abstract base class for polymorphism
class CHoltMACalculator
  {
protected:
   //--- Dummy Buffers for unused outputs
   double            m_dummy_trend[];
   double            m_dummy_level[];

public:
   virtual bool      Init(int period, double alpha, double beta, int forecast_p)=0;
   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &forecast_out[], double &upper_band_out[], double &lower_band_out[])=0;
  };

//--- Standard version
class CHoltMACalculator_Std : public CHoltMACalculator
  {
protected:
   CHoltEngine       *m_engine;
public:
                     CHoltMACalculator_Std(void) { m_engine = new CHoltEngine(); }
                    ~CHoltMACalculator_Std(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int period, double alpha, double beta, int forecast_p) override { return m_engine.Init(period, alpha, beta, forecast_p); }
   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &forecast_out[], double &upper_band_out[], double &lower_band_out[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      if(ArraySize(m_dummy_trend) != rates_total)
        {
         ArrayResize(m_dummy_trend, rates_total);
         ArrayResize(m_dummy_level, rates_total);
        }

      // Pass dummy buffers for trend and level
      m_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                         forecast_out, m_dummy_trend, m_dummy_level, upper_band_out, lower_band_out);
     }
  };

//--- HA version
class CHoltMACalculator_HA : public CHoltMACalculator
  {
protected:
   CHoltEngine       *m_engine;
public:
                     CHoltMACalculator_HA(void) { m_engine = new CHoltEngine_HA(); }
                    ~CHoltMACalculator_HA(void) { if(CheckPointer(m_engine)!=POINTER_INVALID) delete m_engine; }

   virtual bool      Init(int period, double alpha, double beta, int forecast_p) override { return m_engine.Init(period, alpha, beta, forecast_p); }
   virtual void      Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &forecast_out[], double &upper_band_out[], double &lower_band_out[]) override
     {
      if(CheckPointer(m_engine)==POINTER_INVALID)
         return;

      if(ArraySize(m_dummy_trend) != rates_total)
        {
         ArrayResize(m_dummy_trend, rates_total);
         ArrayResize(m_dummy_level, rates_total);
        }

      m_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close,
                         forecast_out, m_dummy_trend, m_dummy_level, upper_band_out, lower_band_out);
     }
  };
//+------------------------------------------------------------------+
