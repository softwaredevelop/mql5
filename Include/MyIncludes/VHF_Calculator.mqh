//+------------------------------------------------------------------+
//|                                            VHF_Calculator.mqh    |
//|      Engine for Vertical Horizontal Filter (Adam White).         |
//|      Algorithm: Selectable (Standard Close vs High-Low Range).   |
//|                                        Copyright 2026, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"

enum ENUM_VHF_MODE
  {
   VHF_MODE_CLOSE_ONLY, // Adam White Classic (Highest Close - Lowest Close)
   VHF_MODE_HIGH_LOW    // Professional (Highest High - Lowest Low)
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVHFCalculator
  {
protected:
   int               m_period;
   ENUM_VHF_MODE     m_mode;

   // Data Buffers
   double            m_price[]; // Close/Source Price (Denominator)
   double            m_high[];  // High Prices (Numerator High-Low Mode)
   double            m_low[];   // Low Prices (Numerator High-Low Mode)

   virtual bool      PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type,
                                 const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CVHFCalculator(void) : m_mode(VHF_MODE_CLOSE_ONLY) {};
   virtual          ~CVHFCalculator(void) {};

   bool              Init(int period, ENUM_VHF_MODE mode);

   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[]);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CVHFCalculator::Init(int period, ENUM_VHF_MODE mode)
  {
   m_period = (period < 1) ? 1 : period;
   m_mode = mode;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CVHFCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               double &out_vhf[])
  {
   if(rates_total <= m_period)
      return;

   int start_index = (prev_calculated > m_period) ? prev_calculated - 1 : m_period;

// Resize internal buffers
   if(ArraySize(m_price) != rates_total)
     {
      ArrayResize(m_price, rates_total);
      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         ArrayResize(m_high, rates_total);
         ArrayResize(m_low, rates_total);
        }
     }

   if(!PrepareData(rates_total, (prev_calculated>0?prev_calculated-1:0), price_type, open, high, low, close))
      return;

   for(int i = start_index; i < rates_total; i++)
     {
      double max_p = -DBL_MAX;
      double min_p = DBL_MAX;
      double sum_change = 0;

      // 1. Numerator (Range)
      if(m_mode == VHF_MODE_CLOSE_ONLY)
        {
         // Classic: Search within source price (usually Close)
         for(int k = 0; k < m_period; k++)
           {
            double p = m_price[i - k]; // i down to i-period+1 ? Standard VHF lookback is usually [i .. i-period+1]
            // Actually, Adam White lookback N means Highest over N bars. [i-N+1 ... i]
            if(p > max_p)
               max_p = p;
            if(p < min_p)
               min_p = p;
           }
        }
      else // VHF_MODE_HIGH_LOW
        {
         // Pro: Search within TRUE High/Low arrays
         // Note: m_high/m_low are populated in PrepareData
         for(int k = 0; k < m_period; k++)
           {
            int idx = i - k; // Simple loop back
            if(m_high[idx] > max_p)
               max_p = m_high[idx];
            if(m_low[idx] < min_p)
               min_p = m_low[idx];
           }
        }

      // 2. Denominator (Noise)
      // Sum of Abs Changes of the SOURCE PRICE (Close) over Period
      // usually Change[i] ... Change[i-N+1]
      for(int k = 0; k < m_period; k++)
        {
         int idx = i - k;
         double p_curr = m_price[idx];
         double p_prev = m_price[idx-1]; // Safe if i >= period >= 1
         sum_change += MathAbs(p_curr - p_prev);
        }

      if(sum_change > 1.0e-9) // Determine VHF
         out_vhf[i] = (max_p - min_p) / sum_change;
      else
         out_vhf[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Data                                                     |
//+------------------------------------------------------------------+
bool CVHFCalculator::PrepareData(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      // 1. Prepare Denominator Base (Close/Selected)
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
            m_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_price[i] = (high[i]+low[i]+2*close[i])/4.0;
            break;
         default:
            m_price[i] = close[i];
            break;
        }

      // 2. Prepare Numerator Base (High/Low) - Only if needed
      if(m_mode == VHF_MODE_HIGH_LOW)
        {
         m_high[i] = high[i];
         m_low[i]  = low[i];
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
