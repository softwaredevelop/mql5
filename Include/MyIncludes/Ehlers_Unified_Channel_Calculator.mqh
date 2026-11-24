//+------------------------------------------------------------------+
//|                            Ehlers_Unified_Channel_Calculator.mqh |
//|      Composition Facade Engine for Ehlers Volatility Envelopes   |
//|      VERSION 2.00: Single Source of Truth Delegation via         |
//|                    Ehlers_Bands & Ehlers_Channel Calculators     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef EHLERS_UNIFIED_CHANNEL_CALCULATOR_MQH
#define EHLERS_UNIFIED_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\Ehlers_Bands_Calculator.mqh>
#include <MyIncludes\Ehlers_Channel_Calculator.mqh>

//--- Unified Envelope Volatility Mode Enum
#ifndef ENUM_EHLERS_ENVELOPE_MODE_DEFINED
#define ENUM_EHLERS_ENVELOPE_MODE_DEFINED
enum ENUM_EHLERS_ENVELOPE_MODE
  {
   ENVELOPE_KELTNER_ATR,       // Keltner Style (ATR Volatility Channel)
   ENVELOPE_BOLLINGER_RMS,     // Bollinger Style (RMS Tracking Residual)
   ENVELOPE_BOLLINGER_STDEV    // Bollinger Style (Classic StDev around Filter)
  };
#endif

//+==================================================================+
//| CLASS: CEhlersUnifiedChannelCalculator (Pure Composition Facade) |
//+==================================================================+
class CEhlersUnifiedChannelCalculator
  {
private:
   ENUM_EHLERS_ENVELOPE_MODE m_envelope_mode;
   int                       m_smooth_period;
   int                       m_vol_period;

   //--- Delegated Core Calculators (Pay Only For What You Use!)
   CEhlersBandsCalculator   *m_bands_calc;
   CEhlersChannelCalculator *m_channel_calc;

   void                      CleanupCalculators(void);

public:
                     CEhlersUnifiedChannelCalculator(void);
                    ~CEhlersUnifiedChannelCalculator(void);

   bool                      Init(const int smooth_period,
                                  const ENUM_SMOOTHER_TYPE smoother_type,
                                  const ENUM_EHLERS_ENVELOPE_MODE envelope_mode,
                                  const int vol_period,
                                  const double multiplier,
                                  const ENUM_ATR_SOURCE atr_source,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);

   void                      GetPriceBuffer(double &dest_array[]) const;

   int                       GetSmoothPeriod(void)  const { return m_smooth_period; }
   int                       GetVolPeriod(void)     const { return m_vol_period; }
   int                       GetWarmupBars(void)    const { return MathMax(m_smooth_period, m_vol_period); }
   ENUM_EHLERS_ENVELOPE_MODE GetEnvelopeMode(void)  const { return m_envelope_mode; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEhlersUnifiedChannelCalculator::CEhlersUnifiedChannelCalculator(void) :
   m_envelope_mode(ENVELOPE_KELTNER_ATR),
   m_smooth_period(20),
   m_vol_period(20),
   m_bands_calc(NULL),
   m_channel_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEhlersUnifiedChannelCalculator::~CEhlersUnifiedChannelCalculator(void)
  {
   CleanupCalculators();
  }

//+------------------------------------------------------------------+
//| Clean up dynamic calculator instances                            |
//+------------------------------------------------------------------+
void CEhlersUnifiedChannelCalculator::CleanupCalculators(void)
  {
   if(CheckPointer(m_bands_calc) != POINTER_INVALID && m_bands_calc != NULL)
     {
      delete m_bands_calc;
      m_bands_calc = NULL;
     }
   if(CheckPointer(m_channel_calc) != POINTER_INVALID && m_channel_calc != NULL)
     {
      delete m_channel_calc;
      m_channel_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Facade Initialization (Single Source of Truth Delegation)        |
//+------------------------------------------------------------------+
bool CEhlersUnifiedChannelCalculator::Init(const int smooth_period,
      const ENUM_SMOOTHER_TYPE smoother_type,
      const ENUM_EHLERS_ENVELOPE_MODE envelope_mode,
      const int vol_period,
      const double multiplier,
      const ENUM_ATR_SOURCE atr_source,
      const ENUM_APPLIED_PRICE_HA_ALL price_source)
  {
   m_smooth_period = MathMax(2, smooth_period);
   m_vol_period    = MathMax(2, vol_period);
   m_envelope_mode = envelope_mode;

   CleanupCalculators();

   if(m_envelope_mode == ENVELOPE_KELTNER_ATR)
     {
      m_channel_calc = new CEhlersChannelCalculator();
      if(CheckPointer(m_channel_calc) == POINTER_INVALID)
         return false;

      return m_channel_calc.Init(m_smooth_period, smoother_type, m_vol_period, multiplier, atr_source, price_source);
     }
   else // ENVELOPE_BOLLINGER_RMS or ENVELOPE_BOLLINGER_STDEV
     {
      m_bands_calc = new CEhlersBandsCalculator();
      if(CheckPointer(m_bands_calc) == POINTER_INVALID)
         return false;

      ENUM_EHLERS_BANDS_MODE b_mode = (m_envelope_mode == ENVELOPE_BOLLINGER_RMS) ? BANDS_RMS_RESIDUAL : BANDS_CLASSIC_STDEV;
      return m_bands_calc.Init(m_smooth_period, m_vol_period, multiplier, smoother_type, b_mode, price_source);
     }
  }

//+------------------------------------------------------------------+
//| Facade Execution Pipeline                                        |
//+------------------------------------------------------------------+
void CEhlersUnifiedChannelCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[],
      const double &low[], const double &close[],
      double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   if(m_envelope_mode == ENVELOPE_KELTNER_ATR)
     {
      if(CheckPointer(m_channel_calc) != POINTER_INVALID && m_channel_calc != NULL)
        {
         // Channel Calculator signature: (..., middle, upper, lower)
         m_channel_calc.Calculate(rates_total, prev_calculated, open, high, low, close,
                                  middle_buffer, upper_buffer, lower_buffer);
        }
     }
   else
     {
      if(CheckPointer(m_bands_calc) != POINTER_INVALID && m_bands_calc != NULL)
        {
         // Bands Calculator signature: (..., upper, lower, middle)
         m_bands_calc.Calculate(rates_total, prev_calculated, open, high, low, close,
                                upper_buffer, lower_buffer, middle_buffer);
        }
     }
  }

//+------------------------------------------------------------------+
//| Forward Price Buffer Export if using Bands Mode                  |
//+------------------------------------------------------------------+
void CEhlersUnifiedChannelCalculator::GetPriceBuffer(double &dest_array[]) const
  {
   if(CheckPointer(m_bands_calc) != POINTER_INVALID && m_bands_calc != NULL)
      m_bands_calc.GetPriceBuffer(dest_array);
  }

#endif // EHLERS_UNIFIED_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
