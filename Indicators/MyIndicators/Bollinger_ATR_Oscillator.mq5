//+------------------------------------------------------------------+
//|                                     Bollinger_ATR_Oscillator.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Bollinger Bands ATR Oscillator by Jon Anderson."
#property description "Measures the ratio of ATR to Bollinger Bandwidth."

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Oscillator Line
#property indicator_label1  "BB ATR Ratio"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumTurquoise
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input Parameters ---
input int                InpAtrPeriod    = 22;
input int                InpBandsPeriod  = 55;
input double             InpBandsDev     = 2.0;
input ENUM_APPLIED_PRICE InpSourcePrice  = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferOscillator[];

//+------------------------------------------------------------------+
//| CLASS: CBollingerATROscillatorCalculator                         |
//+------------------------------------------------------------------+
class CBollingerATROscillatorCalculator
  {
private:
   int               m_atr_period;
   int               m_bb_period;
   double            m_bb_dev;

   double            m_price[];
   double            m_atr_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];

public:
                     CBollingerATROscillatorCalculator(void) {};
                    ~CBollingerATROscillatorCalculator(void) {};

   bool              Init(int atr_p, int bb_p, double bb_dev);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                  double &osc_out[]);
  };

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator: Initialization                |
//+------------------------------------------------------------------+
bool CBollingerATROscillatorCalculator::Init(int atr_p, int bb_p, double bb_dev)
  {
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_bb_period = (bb_p < 1) ? 1 : bb_p;
   m_bb_dev = bb_dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CBollingerATROscillatorCalculator: Main Calculation Method       |
//+------------------------------------------------------------------+
void CBollingerATROscillatorCalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &osc_out[])
  {
   int start_pos = MathMax(m_atr_period, m_bb_period);
   if(rates_total <= start_pos)
      return;

   ArrayResize(m_price, rates_total);
   ArrayResize(m_atr_buffer, rates_total);
   ArrayResize(m_ma_buffer, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);

//--- Prepare Source Price for Bollinger Bands
   switch(price_type)
     {
      case PRICE_CLOSE:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(m_price, open, 0, 0, rates_total);
         break;
      // ... add other price types if needed
      default:
         ArrayCopy(m_price, close, 0, 0, rates_total);
         break;
     }

//--- Step 1: Calculate ATR (Wilder's Smoothing)
   double tr[];
   ArrayResize(tr, rates_total);
   for(int i = 1; i < rates_total; i++)
      tr[i] = MathMax(high[i], close[i-1]) - MathMin(low[i], close[i-1]);

   for(int i = m_atr_period; i < rates_total; i++)
     {
      if(i == m_atr_period)
        {
         double sum=0;
         for(int j=1; j<=m_atr_period; j++)
            sum+=tr[j];
         m_atr_buffer[i]=sum/m_atr_period;
        }
      else
         m_atr_buffer[i] = (m_atr_buffer[i-1] * (m_atr_period - 1) + tr[i]) / m_atr_period;
     }

//--- Step 2: Calculate Bollinger Bands components
// MA centerline
   for(int i = m_bb_period - 1; i < rates_total; i++)
     {
      double sum = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum += m_price[i-j];
      m_ma_buffer[i] = sum / m_bb_period;
     }
// Bands
   for(int i = m_bb_period - 1; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_bb_period; j++)
         sum_sq += pow(m_price[i-j] - m_ma_buffer[i], 2);
      std_dev_val = sqrt(sum_sq / m_bb_period);

      m_upper_band[i] = m_ma_buffer[i] + m_bb_dev * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_bb_dev * std_dev_val;
     }

//--- Step 3: Calculate the final Oscillator value
   for(int i = start_pos; i < rates_total; i++)
     {
      double bb_diff = m_upper_band[i] - m_lower_band[i];
      if(bb_diff != 0)
        {
         osc_out[i] = m_atr_buffer[i] / bb_diff;
        }
     }
  }

//--- Global calculator object ---
CBollingerATROscillatorCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   g_calculator = new CBollingerATROscillatorCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpAtrPeriod, InpBandsPeriod, InpBandsDev))
     {
      Print("Failed to initialize Bollinger ATR Oscillator Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpAtrPeriod, InpBandsPeriod));
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("BB_ATR_Osc(%d, %d)", InpAtrPeriod, InpBandsPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime&[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      g_calculator.Calculate(rates_total, InpSourcePrice, open, high, low, close, BufferOscillator);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
