//+------------------------------------------------------------------+
//|                                        Velocity_Calculator.mqh   |
//|      Engine for Kinematic Velocity Vector & Speed Envelopes      |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Performance-optimized Kinematic Velocity & Speed Engine

#ifndef VELOCITY_CALCULATOR_MQH
#define VELOCITY_CALCULATOR_MQH

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|             CLASS: CVelocityCalculator                           |
//+==================================================================+
class CVelocityCalculator
  {
private:
   int                       m_vel_period;
   int                       m_atr_period;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;
   ENUM_ATR_SOURCE           m_atr_source;

   //--- Composition Engines
   CATRCalculator           *m_atr_calc;
   CHeikinAshi_Calculator    m_ha_engine;

   //--- Persistent State Buffers
   double                    m_atr_buf[];
   double                    m_price_buf[];
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

   bool                      PreparePriceSeries(const int rates_total, const int start_index,
         const double &open[], const double &high[],
         const double &low[], const double &close[]);

public:
                     CVelocityCalculator(void);
                    ~CVelocityCalculator(void);

   bool                      Init(const int vel_p, const int atr_p,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source,
                                  const ENUM_ATR_SOURCE atr_source);

   void                      Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[],
                                       const double &low[], const double &close[],
                                       double &vel_buffer[], double &color_buffer[],
                                       double &speed_pos[], double &speed_neg[],
                                       const double th_low, const double th_high);

   int                       GetRequiredWarmup(void) const { return m_atr_period + m_vel_period; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVelocityCalculator::CVelocityCalculator(void) : m_vel_period(3),
   m_atr_period(14),
   m_source_price(PRICE_CLOSE_STD),
   m_atr_source(ATR_SOURCE_STANDARD),
   m_atr_calc(NULL)
  {
   ArraySetAsSeries(m_atr_buf,   false);
   ArraySetAsSeries(m_price_buf, false);
   ArraySetAsSeries(m_ha_open,   false);
   ArraySetAsSeries(m_ha_high,   false);
   ArraySetAsSeries(m_ha_low,    false);
   ArraySetAsSeries(m_ha_close,  false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVelocityCalculator::~CVelocityCalculator(void)
  {
   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CVelocityCalculator::Init(const int vel_p, const int atr_p,
                               const ENUM_APPLIED_PRICE_HA_ALL price_source,
                               const ENUM_ATR_SOURCE atr_source)
  {
   m_vel_period   = (vel_p < 1) ? 1 : vel_p;
   m_atr_period   = (atr_p < 1) ? 1 : atr_p;
   m_source_price = price_source;
   m_atr_source   = atr_source;

   if(CheckPointer(m_atr_calc) != POINTER_INVALID)
     {
      delete m_atr_calc;
      m_atr_calc = NULL;
     }

   if(m_atr_source == ATR_SOURCE_HEIKIN_ASHI)
      m_atr_calc = new CATRCalculator_HA();
   else
      m_atr_calc = new CATRCalculator();

   if(CheckPointer(m_atr_calc) == POINTER_INVALID || !m_atr_calc.Init(m_atr_period, ATR_POINTS))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Prepare Price Series                                             |
//+------------------------------------------------------------------+
bool CVelocityCalculator::PreparePriceSeries(const int rates_total, const int start_index,
      const double &open[], const double &high[],
      const double &low[], const double &close[])
  {
   if(ArraySize(m_price_buf) != rates_total)
     {
      ArrayResize(m_price_buf, rates_total);
      ArraySetAsSeries(m_price_buf, false);
     }

   bool is_heikin_ashi = (m_source_price <= PRICE_HA_CLOSE);

   if(is_heikin_ashi)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);

         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      m_ha_engine.Calculate(rates_total, start_index, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);

      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_HA_OPEN:
               m_price_buf[i] = m_ha_open[i];
               break;
            case PRICE_HA_HIGH:
               m_price_buf[i] = m_ha_high[i];
               break;
            case PRICE_HA_LOW:
               m_price_buf[i] = m_ha_low[i];
               break;
            case PRICE_HA_MEDIAN:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i]) / 2.0;
               break;
            case PRICE_HA_TYPICAL:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
               break;
            case PRICE_HA_WEIGHTED:
               m_price_buf[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) / 4.0;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price_buf[i] = m_ha_close[i];
               break;
           }
        }
     }
   else
     {
      for(int i = start_index; i < rates_total; i++)
        {
         switch(m_source_price)
           {
            case PRICE_OPEN_STD:
               m_price_buf[i] = open[i];
               break;
            case PRICE_HIGH_STD:
               m_price_buf[i] = high[i];
               break;
            case PRICE_LOW_STD:
               m_price_buf[i] = low[i];
               break;
            case PRICE_MEDIAN_STD:
               m_price_buf[i] = (high[i] + low[i]) / 2.0;
               break;
            case PRICE_TYPICAL_STD:
               m_price_buf[i] = (high[i] + low[i] + close[i]) / 3.0;
               break;
            case PRICE_WEIGHTED_STD:
               m_price_buf[i] = (high[i] + low[i] + 2.0 * close[i]) / 4.0;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price_buf[i] = close[i];
               break;
           }
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Main Incremental Calculation Loop                                |
//+------------------------------------------------------------------+
void CVelocityCalculator::Calculate(const int rates_total, const int prev_calculated,
                                    const double &open[], const double &high[],
                                    const double &low[], const double &close[],
                                    double &vel_buffer[], double &color_buffer[],
                                    double &speed_pos[], double &speed_neg[],
                                    const double th_low, const double th_high)
  {
   int warmup = GetRequiredWarmup();
   if(rates_total <= warmup || CheckPointer(m_atr_calc) == POINTER_INVALID)
      return;

// Safe allocation of internal ATR buffer
   if(ArraySize(m_atr_buf) != rates_total)
     {
      ArrayResize(m_atr_buf, rates_total);
      ArraySetAsSeries(m_atr_buf, false);
     }

// 1. Prepare Price Series & Compute ATR
   int start_index = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
   if(!PreparePriceSeries(rates_total, start_index, open, high, low, close))
      return;

   m_atr_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_atr_buf);

// 2. Clean warmup period on fresh run
   if(prev_calculated == 0)
     {
      for(int i = 0; i < warmup; i++)
        {
         vel_buffer[i]   = 0.0;
         color_buffer[i] = 0.0;
         speed_pos[i]    = EMPTY_VALUE;
         speed_neg[i]    = EMPTY_VALUE;
        }
     }

   int start = (prev_calculated > warmup) ? (prev_calculated - 1) : warmup;
   if(start < warmup)
      start = warmup;

// 3. Kinematic Vector & Scalar Envelope Loop
   for(int i = start; i < rates_total; i++)
     {
      double atr = m_atr_buf[i];
      if(atr <= 1.0e-9)
        {
         vel_buffer[i]   = 0.0;
         color_buffer[i] = 0.0;
         speed_pos[i]    = 0.0;
         speed_neg[i]    = 0.0;
         continue;
        }

      // Velocity Vector (Directional Normalized Displacement)
      double displacement = m_price_buf[i] - m_price_buf[i - m_vel_period];
      double vel = displacement / (atr * (double)m_vel_period);
      vel_buffer[i] = vel;

      // Swapped Thermal 5-Zone Palette Classification
      if(vel >= th_high)
         color_buffer[i] = 2.0; // Index 2: DeepSkyBlue (Bull Climax)
      else
         if(vel >= th_low)
            color_buffer[i] = 1.0; // Index 1: LightSkyBlue (Bull Flow)
         else
            if(vel <= -th_high)
               color_buffer[i] = 4.0; // Index 4: OrangeRed (Bear Climax)
            else
               if(vel <= -th_low)
                  color_buffer[i] = 3.0; // Index 3: Coral (Bear Flow)
               else
                  color_buffer[i] = 0.0; // Index 0: Gray (Neutral Noise)

      // Speed Scalar (Cumulative Path Length / ATR)
      double path_length = 0.0;
      for(int k = 0; k < m_vel_period; k++)
         path_length += MathAbs(m_price_buf[i - k] - m_price_buf[i - k - 1]);

      double speed = (path_length / (double)m_vel_period) / atr;
      speed_pos[i] = speed;
      speed_neg[i] = -speed;
     }
  }

#endif // VELOCITY_CALCULATOR_MQH
//+------------------------------------------------------------------+
