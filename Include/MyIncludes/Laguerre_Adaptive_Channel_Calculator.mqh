//+------------------------------------------------------------------+
//|                             Laguerre_Adaptive_Channel_Calculator.mqh |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10" // Upgraded with dedicated ENUM_CHANNEL_WIDTH_METHOD for strict type safety
#property description "Stateful calculator implementing volatility bands around Adaptive Laguerre Filter."

#ifndef LAGUERRE_ADAPTIVE_CHANNEL_CALCULATOR_MQH
#define LAGUERRE_ADAPTIVE_CHANNEL_CALCULATOR_MQH

#include <MyIncludes\Laguerre_Adaptive_Filter_Calculator.mqh>
#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Dedicated Channel Volatility Width enum to prevent dimensionless metrics (like ER) from causing UI confusion
enum ENUM_CHANNEL_WIDTH_METHOD
  {
   WIDTH_METHOD_ATR,              // Average True Range (ATR Keltner-style)
   WIDTH_METHOD_STAND_DEV         // Standard Deviation (StDev Bollinger-style)
  };

//+==================================================================+
//|             CLASS: CLaguerreAdaptiveChannelCalculator            |
//+==================================================================+
class CLaguerreAdaptiveChannelCalculator
  {
private:
   ENUM_CHANNEL_WIDTH_METHOD          m_width_method;
   int                                m_width_period;
   double                             m_multiplier;
   bool                               m_is_ha;

   CLaguerreAdaptiveFilterCalculator *m_baseline_calc;
   CATRCalculator                    *m_atr_calc;

   //--- Persistent State Registers
   double                             m_baseline_buffer[];
   double                             m_vol_buffer[];
   double                             m_price[];

   bool                               PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CLaguerreAdaptiveChannelCalculator(void);
                    ~CLaguerreAdaptiveChannelCalculator(void);

   bool                               Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
                                           ENUM_CHANNEL_WIDTH_METHOD width_method, int width_period, double multiplier, bool is_ha);

   void                               Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
         const double &open[], const double &high[], const double &low[], const double &close[],
         double &baseline_buffer[], double &upper_buffer[], double &lower_buffer[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLaguerreAdaptiveChannelCalculator::CLaguerreAdaptiveChannelCalculator(void)
   : m_width_method(WIDTH_METHOD_ATR),
     m_width_period(10),
     m_multiplier(2.0),
     m_is_ha(false),
     m_baseline_calc(NULL),
     m_atr_calc(NULL)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLaguerreAdaptiveChannelCalculator::~CLaguerreAdaptiveChannelCalculator(void)
  {
   if(CheckPointer(m_baseline_calc) != POINTER_INVALID)
      delete m_baseline_calc;
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
      delete m_atr_calc;
  }

//+------------------------------------------------------------------+
//| Init (Strict Type Safety Enforced)                               |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveChannelCalculator::Init(ENUM_ADAPTIVE_METHOD method, int adaptive_period, double gamma_min, double gamma_max,
      ENUM_CHANNEL_WIDTH_METHOD width_method, int width_period, double multiplier, bool is_ha)
  {
   m_width_method = width_method;
   m_width_period = (width_period < 2) ? 2 : width_period;
   m_multiplier   = (multiplier <= 0.0) ? 1.0 : multiplier;
   m_is_ha        = is_ha;

   if(CheckPointer(m_baseline_calc) != POINTER_INVALID)
     {
      delete m_baseline_calc;
      m_baseline_calc = NULL;
     }
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

// Instantiate Baseline Calculator
   m_baseline_calc = new CLaguerreAdaptiveFilterCalculator();
   if(CheckPointer(m_baseline_calc) == POINTER_INVALID ||
      !m_baseline_calc.Init(method, adaptive_period, gamma_min, gamma_max, m_is_ha))
      return false;

// Instantiate ATR Width Calculator if selected
   if(m_width_method == WIDTH_METHOD_ATR)
     {
      if(m_is_ha)
         m_atr_calc = new CATRCalculator_HA();
      else
         m_atr_calc = new CATRCalculator();

      if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_width_period, ATR_POINTS))
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
void CLaguerreAdaptiveChannelCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[],
      double &baseline_buffer[], double &upper_buffer[], double &lower_buffer[])
  {
   int required_bars = MathMax(m_width_period * 2, 20) + 5;
   if(rates_total < required_bars)
      return;

//--- Resize state buffers and enforce chronological safety
   if(ArraySize(m_baseline_buffer) != rates_total)
     {
      ArrayResize(m_baseline_buffer, rates_total);
      ArrayResize(m_vol_buffer,      rates_total);
      ArrayResize(m_price,           rates_total);

      ArraySetAsSeries(m_baseline_buffer, false);
      ArraySetAsSeries(m_vol_buffer,      false);
      ArraySetAsSeries(m_price,           false);
     }

//--- 1. Calculate Adaptive Baseline (Filter Mean)
   m_baseline_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_baseline_buffer);

//--- 2. Calculate Channel Volatility Width (ATR or Standard Deviation)
   if(m_width_method == WIDTH_METHOD_ATR)
     {
      // Refactored CATRCalculator v3.00 call
      m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_vol_buffer);
     }
   else // WIDTH_METHOD_STAND_DEV (Bollinger Band Style volatility width)
     {
      int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
         return;

      int loop_start = MathMax(m_width_period - 1, start_index);
      if(loop_start == m_width_period - 1)
        {
         for(int i = 0; i < loop_start; i++)
            m_vol_buffer[i] = 0.0;
        }

      for(int i = loop_start; i < rates_total; i++)
        {
         double sum = 0.0;
         for(int j = 0; j < m_width_period; j++)
            sum += m_price[i - j];
         double mean = sum / m_width_period;

         double sum_sq = 0.0;
         for(int j = 0; j < m_width_period; j++)
            sum_sq += pow(m_price[i - j] - mean, 2);

         m_vol_buffer[i] = sqrt(sum_sq / m_width_period);
        }
     }

//--- 3. Calculate Upper and Lower bands around Baseline
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
     {
      baseline_buffer[i] = m_baseline_buffer[i];
      upper_buffer[i]    = m_baseline_buffer[i] + m_multiplier * m_vol_buffer[i];
      lower_buffer[i]    = m_baseline_buffer[i] - m_multiplier * m_vol_buffer[i];
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price Series                                             |
//+------------------------------------------------------------------+
bool CLaguerreAdaptiveChannelCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
      const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(m_is_ha)
     {
      static CHeikinAshi_Calculator ha_calc;
      static double ha_open[], ha_high[], ha_low[], ha_close[];
      if(ArraySize(ha_open) != rates_total)
        {
         ArrayResize(ha_open,  rates_total);
         ArrayResize(ha_high,  rates_total);
         ArrayResize(ha_low,   rates_total);
         ArrayResize(ha_close, rates_total);
         ArraySetAsSeries(ha_open,  false);
         ArraySetAsSeries(ha_high,  false);
         ArraySetAsSeries(ha_low,   false);
         ArraySetAsSeries(ha_close, false);
        }

      ha_calc.Calculate(rates_total, start_index, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(price_type)
           {
            case PRICE_OPEN:
               m_price[i] = ha_open[i];
               break;
            case PRICE_HIGH:
               m_price[i] = ha_high[i];
               break;
            case PRICE_LOW:
               m_price[i] = ha_low[i];
               break;
            case PRICE_MEDIAN:
               m_price[i] = (ha_high[i] + ha_low[i]) * 0.5;
               break;
            case PRICE_TYPICAL:
               m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (ha_high[i] + ha_low[i] + ha_close[i] * 2.0) * 0.25;
               break;
            default:
               m_price[i] = ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(price_type)
           {
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
               m_price[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED:
               m_price[i] = (high[i] + low[i] + close[i] * 2.0) * 0.25;
               break;
            default:
               m_price[i] = close[i];
               break;
           }
        }
     }
   return true;
  }

#endif // LAGUERRE_ADAPTIVE_CHANNEL_CALCULATOR_MQH
//+------------------------------------------------------------------+
