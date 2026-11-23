//+------------------------------------------------------------------+
//|                                        Cyber_Cycle_Calculator.mqh|
//|      DSP Engine for John Ehlers' Resonant Cyber Cycle Filter     |
//|      VERSION 4.00: 2026 Enterprise Edition with Precomputed      |
//|                    DSP Coefficients & CalculateOnArray Pipeline  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "4.00"

#ifndef CYBER_CYCLE_CALCULATOR_MQH
#define CYBER_CYCLE_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

#define INV_6 0.16666666666666666666666666666667

//--- Enum for Signal Line Type
#ifndef ENUM_CYBER_SIGNAL_TYPE_DEFINED
#define ENUM_CYBER_SIGNAL_TYPE_DEFINED
enum ENUM_CYBER_SIGNAL_TYPE
  {
   SIGNAL_DELAY_1BAR, // Classic Ehlers (Cycle[i-1])
   SIGNAL_MA          // Custom Moving Average
  };
#endif

//+==================================================================+
//|           CLASS 1: CCyberCycleCalculator (Base Class)            |
//+==================================================================+
class CCyberCycleCalculator
  {
protected:
   double                 m_alpha;

   //--- Precomputed Analytical Filter Coefficients
   double                 m_coeff_smooth;
   double                 m_coeff_c1;
   double                 m_coeff_c2;

   //--- Signal Settings
   ENUM_CYBER_SIGNAL_TYPE m_signal_type;
   int                    m_signal_period;
   ENUM_MA_TYPE           m_signal_method;

   //--- Smoothing Engine
   CMovingAverageCalculator *m_signal_engine;

   //--- Persistent Working Buffers
   double                 m_price[];
   double                 m_smooth[]; // 4-bar FIR pre-smoothing buffer
   double                 m_cycle[];  // Resonant 2-pole cycle buffer

   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);

   void                   PrecomputeCoefficients(void);

public:
                     CCyberCycleCalculator(void);
   virtual               ~CCyberCycleCalculator(void);

   bool                   Init(const double alpha, const ENUM_CYBER_SIGNAL_TYPE sig_type, const int sig_period, const ENUM_MA_TYPE sig_method);

   //--- Standard Calculate (Without Volume Data)
   void                   Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                    const double &open[], const double &high[], const double &low[], const double &close[],
                                    double &cycle_out[], double &signal_out[]);

   //--- Overloaded Calculate with Long Volume (Native Ticks/Real)
   void                   Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                    const double &open[], const double &high[], const double &low[], const double &close[],
                                    const long &volume[],
                                    double &cycle_out[], double &signal_out[]);

   //--- Overloaded Calculate with Double Volume (MTF Volume Routing)
   void                   Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                    const double &open[], const double &high[], const double &low[], const double &close[],
                                    const double &volume[],
                                    double &cycle_out[], double &signal_out[]);

   double                 GetAlpha(void)        const { return m_alpha; }
   ENUM_CYBER_SIGNAL_TYPE GetSignalType(void)   const { return m_signal_type; }
   int                    GetSignalPeriod(void) const { return m_signal_period; }
   int                    GetWarmupBars(void)   const { return 7 + (m_signal_type == SIGNAL_MA ? m_signal_period : 1); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCyberCycleCalculator::CCyberCycleCalculator(void) : m_alpha(0.07),
   m_coeff_smooth(0.931225),
   m_coeff_c1(1.86),
   m_coeff_c2(0.8649),
   m_signal_type(SIGNAL_DELAY_1BAR),
   m_signal_period(3),
   m_signal_method(SMA),
   m_signal_engine(NULL)
  {
   m_signal_engine = new CMovingAverageCalculator();

   ArraySetAsSeries(m_price,  false);
   ArraySetAsSeries(m_smooth, false);
   ArraySetAsSeries(m_cycle,  false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCyberCycleCalculator::~CCyberCycleCalculator(void)
  {
   if(CheckPointer(m_signal_engine) != POINTER_INVALID && m_signal_engine != NULL)
     {
      delete m_signal_engine;
      m_signal_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Precompute Filter Coefficients (Run Once in Init)                |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::PrecomputeCoefficients(void)
  {
   double half_alpha = 1.0 - 0.5 * m_alpha;
   m_coeff_smooth = half_alpha * half_alpha;

   double one_minus_alpha = 1.0 - m_alpha;
   m_coeff_c1 = 2.0 * one_minus_alpha;
   m_coeff_c2 = one_minus_alpha * one_minus_alpha;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::Init(const double alpha, const ENUM_CYBER_SIGNAL_TYPE sig_type, const int sig_period, const ENUM_MA_TYPE sig_method)
  {
   m_alpha         = (alpha <= 0.0) ? 0.07 : alpha;
   m_signal_type   = sig_type;
   m_signal_period = MathMax(1, sig_period);
   m_signal_method = sig_method;

   PrecomputeCoefficients();

   if(m_signal_type == SIGNAL_MA)
     {
      if(CheckPointer(m_signal_engine) == POINTER_INVALID || !m_signal_engine.Init(m_signal_period, m_signal_method))
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate (Standard - No Volume)                                 |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                      const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &cycle_out[], double &signal_out[])
  {
   if(rates_total < 7)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Allocate internal working registers with capacity reservation
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price,  rates_total, 2048);
      ArrayResize(m_smooth, rates_total, 2048);
      ArrayResize(m_cycle,  rates_total, 2048);

      ArraySetAsSeries(m_price,  false);
      ArraySetAsSeries(m_smooth, false);
      ArraySetAsSeries(m_cycle,  false);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

   int loop_start = MathMax(6, start_index);

// Deterministic seeding for bars 0 ... 5
   if(prev_calculated == 0)
     {
      for(int k = 0; k < 6; k++)
        {
         m_smooth[k]   = m_price[k];
         m_cycle[k]    = 0.0;
         cycle_out[k]  = 0.0;
         signal_out[k] = 0.0;
        }
      loop_start = 6;
     }

// Resonant Cyber Cycle Core Loop (Hardware-Pipelined FMA)
   for(int i = loop_start; i < rates_total; i++)
     {
      // Step 1: Pre-smoothing (4-bar FIR filter with reciprocal multiplication)
      m_smooth[i] = (m_price[i] + 2.0 * m_price[i - 1] + 2.0 * m_price[i - 2] + m_price[i - 3]) * INV_6;

      // Step 2: 2-Pole Resonant Cycle Equation
      double term1 = m_coeff_smooth * (m_smooth[i] - 2.0 * m_smooth[i - 1] + m_smooth[i - 2]);
      double term2 = m_coeff_c1 * m_cycle[i - 1];
      double term3 = m_coeff_c2 * m_cycle[i - 2];

      m_cycle[i]   = term1 + term2 - term3;
      cycle_out[i] = m_cycle[i];
     }

// Step 3: Trigger / Signal Line Generation
   if(m_signal_type == SIGNAL_DELAY_1BAR)
     {
      for(int i = loop_start; i < rates_total; i++)
         signal_out[i] = m_cycle[i - 1];
     }
   else // SIGNAL_MA
     {
      // Clean delegation via CalculateOnArray directly on m_cycle
      if(CheckPointer(m_signal_engine) != POINTER_INVALID)
         m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_cycle, signal_out, 6);
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Long Volume for Native Ticks/Real)  |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                      const double &open[], const double &high[], const double &low[], const double &close[],
                                      const long &volume[],
                                      double &cycle_out[], double &signal_out[])
  {
// Compute the base cycle curve
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, cycle_out, signal_out);

// If Signal Line uses volume (e.g. VWMA), recompute signal with volume vector
   if(m_signal_type == SIGNAL_MA && CheckPointer(m_signal_engine) != POINTER_INVALID)
     {
      double d_vol[];
      ArrayResize(d_vol, rates_total, 2048);
      ArraySetAsSeries(d_vol, false);

      int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int j = start_sync; j < rates_total; j++)
         d_vol[j] = (volume[j] < 1) ? 1.0 : (double)volume[j];

      m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_cycle, d_vol, signal_out, 6);
     }
  }

//+------------------------------------------------------------------+
//| Calculate (Overloaded - With Double Volume for MTF VWMA)         |
//+------------------------------------------------------------------+
void CCyberCycleCalculator::Calculate(const int rates_total, const int prev_calculated, const ENUM_APPLIED_PRICE price_type,
                                      const double &open[], const double &high[], const double &low[], const double &close[],
                                      const double &volume[],
                                      double &cycle_out[], double &signal_out[])
  {
// Compute base cycle curve
   Calculate(rates_total, prev_calculated, price_type, open, high, low, close, cycle_out, signal_out);

   if(m_signal_type == SIGNAL_MA && CheckPointer(m_signal_engine) != POINTER_INVALID)
      m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_cycle, volume, signal_out, 6);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - ALU Optimized)                         |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i] + low[i] + close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         default:
            m_price[i] = (high[i] + low[i]) * 0.5;
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|           CLASS 2: CCyberCycleCalculator_HA (Heikin Ashi)        |
//+==================================================================+
class CCyberCycleCalculator_HA : public CCyberCycleCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[]; // Only HA open requires persistent recursive state
   double                 m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool           PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - ALU Optimized)                      |
//+------------------------------------------------------------------+
bool CCyberCycleCalculator_HA::PreparePriceSeries(const int rates_total, const int start_index, const ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total, 2048);
      ArrayResize(m_ha_high,  rates_total, 2048);
      ArrayResize(m_ha_low,   rates_total, 2048);
      ArrayResize(m_ha_close, rates_total, 2048);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      switch(price_type)
        {
         case PRICE_CLOSE:
            m_price[i] = m_ha_close[i];
            break;
         case PRICE_OPEN:
            m_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) * 0.3333333333333333;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
        }
     }
   return true;
  }

#endif // CYBER_CYCLE_CALCULATOR_MQH
//+------------------------------------------------------------------+
