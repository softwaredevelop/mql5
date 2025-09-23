//+------------------------------------------------------------------+
//|                                                    RSI_Pro.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10"
#property description "A professional RSI with a choice of a flexible MA signal line or Bollinger Bands."

#property indicator_separate_window
#property indicator_buffers 4 // RSI, MA, Upper Band, Lower Band
#property indicator_plots   4
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30.0
#property indicator_level2 50.0
#property indicator_level3 70.0

//--- Plot 1: RSI
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal Line (MA)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 3: Upper Bollinger Band
#property indicator_label3  "Upper Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Plot 4: Lower Bollinger Band
#property indicator_label4  "Lower Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGray
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Enum for Display Mode
enum ENUM_DISPLAY_MODE
  {
   DISPLAY_RSI_ONLY,
   DISPLAY_RSI_AND_MA,
   DISPLAY_RSI_AND_BANDS
  };

//--- Input Parameters ---
input group "RSI Settings"
input int                InpPeriodRSI    = 14;
input ENUM_APPLIED_PRICE InpSourcePrice  = PRICE_CLOSE;

input group "Overlay Settings"
input ENUM_DISPLAY_MODE  InpDisplayMode  = DISPLAY_RSI_AND_BANDS;
input int                InpPeriodMA     = 20;
input ENUM_MA_METHOD     InpMethodMA     = MODE_SMA;
input double             InpBandsDev     = 2.0;

//--- Indicator Buffers ---
double    BufferRSI[];
double    BufferSignalMA[];
double    BufferUpperBand[];
double    BufferLowerBand[];

//+------------------------------------------------------------------+
//| CLASS: CRSIProCalculator                                         |
//+------------------------------------------------------------------+
class CRSIProCalculator
  {
private:
   int               m_rsi_period;
   int               m_ma_period;
   double            m_deviation;
   ENUM_MA_METHOD    m_ma_method;

   double            m_rsi_buffer[];
   double            m_ma_buffer[];
   double            m_upper_band[];
   double            m_lower_band[];

public:
                     CRSIProCalculator(void) {};
                    ~CRSIProCalculator(void) {};

   bool              Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m, double dev);
   void              Calculate(int rates_total, const double &price[],
                               double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[]);
  };

//+------------------------------------------------------------------+
//| CRSIProCalculator: Initialization                                |
//+------------------------------------------------------------------+
bool CRSIProCalculator::Init(int rsi_p, int ma_p, ENUM_MA_METHOD ma_m, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_ma_period = (ma_p < 1) ? 1 : ma_p;
   m_ma_method = ma_m;
   m_deviation = dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CRSIProCalculator: Main Calculation Method                       |
//+------------------------------------------------------------------+
void CRSIProCalculator::Calculate(int rates_total, const double &price[],
                                  double &rsi_out[], double &ma_out[], double &upper_out[], double &lower_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

   ArrayResize(m_rsi_buffer, rates_total);
   ArrayResize(m_ma_buffer, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);

//--- Step 1: Calculate base RSI (Wilder's smoothing)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = price[i] - price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;

      if(i >= m_rsi_period)
        {
         if(sum_neg > 0)
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + (sum_pos / sum_neg)));
         else
            m_rsi_buffer[i] = 100.0;
        }
     }

//--- Step 2: Calculate Moving Average on RSI with full MA type support
   int ma_start_pos = m_rsi_period + m_ma_period - 1;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(m_ma_method)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos) // Robust initialization for recursive MAs
              {
               double sum = 0;
               for(int j = 0; j < m_ma_period; j++)
                  sum += m_rsi_buffer[i-j];
               m_ma_buffer[i] = sum / m_ma_period;
              }
            else
              {
               if(m_ma_method == MODE_EMA)
                 {
                  double pr = 2.0 / (m_ma_period + 1.0);
                  m_ma_buffer[i] = m_rsi_buffer[i] * pr + m_ma_buffer[i-1] * (1.0 - pr);
                 }
               else // SMMA
                 {
                  m_ma_buffer[i] = (m_ma_buffer[i-1] * (m_ma_period - 1) + m_rsi_buffer[i]) / m_ma_period;
                 }
              }
            break;

         case MODE_LWMA:
           {
            double lwma_sum = 0, weight_sum = 0;
            for(int j = 0; j < m_ma_period; j++)
              {
               int weight = m_ma_period - j;
               lwma_sum += m_rsi_buffer[i-j] * weight;
               weight_sum += weight;
              }
            if(weight_sum > 0)
               m_ma_buffer[i] = lwma_sum / weight_sum;
            break;
           }

         default: // MODE_SMA
           {
            double sum = 0;
            for(int j = 0; j < m_ma_period; j++)
               sum += m_rsi_buffer[i-j];
            m_ma_buffer[i] = sum / m_ma_period;
            break;
           }
        }
     }

//--- Step 3: Calculate Bollinger Bands on the MA line
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      double std_dev_val = 0, sum_sq = 0;
      for(int j = 0; j < m_ma_period; j++)
        {
         sum_sq += pow(m_rsi_buffer[i-j] - m_ma_buffer[i], 2);
        }
      std_dev_val = sqrt(sum_sq / m_ma_period);

      m_upper_band[i] = m_ma_buffer[i] + m_deviation * std_dev_val;
      m_lower_band[i] = m_ma_buffer[i] - m_deviation * std_dev_val;
     }

   ArrayCopy(rsi_out, m_rsi_buffer, 0, 0, rates_total);
   ArrayCopy(ma_out, m_ma_buffer, 0, 0, rates_total);
   ArrayCopy(upper_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_out, m_lower_band, 0, 0, rates_total);
  }

//--- Global calculator object ---
CRSIProCalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRSI,       INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalMA,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferUpperBand, INDICATOR_DATA);
   SetIndexBuffer(3, BufferLowerBand, INDICATOR_DATA);

   ArraySetAsSeries(BufferRSI,       false);
   ArraySetAsSeries(BufferSignalMA,  false);
   ArraySetAsSeries(BufferUpperBand, false);
   ArraySetAsSeries(BufferLowerBand, false);

   g_calculator = new CRSIProCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriodRSI, InpPeriodMA, InpMethodMA, InpBandsDev))
     {
      Print("Failed to initialize RSI Pro Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpPeriodRSI + InpPeriodMA - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodRSI);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RSI Pro(%d)", InpPeriodRSI));

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
      // The calculator needs the raw price array, not a pre-calculated one
      // We will use the 'close' array directly as the default
      g_calculator.Calculate(rates_total, close, BufferRSI, BufferSignalMA, BufferUpperBand, BufferLowerBand);

      for(int i = 0; i < rates_total; i++)
        {
         if(InpDisplayMode == DISPLAY_RSI_ONLY)
           {
            BufferSignalMA[i] = EMPTY_VALUE;
            BufferUpperBand[i] = EMPTY_VALUE;
            BufferLowerBand[i] = EMPTY_VALUE;
           }
         else
            if(InpDisplayMode == DISPLAY_RSI_AND_MA)
              {
               BufferUpperBand[i] = EMPTY_VALUE;
               BufferLowerBand[i] = EMPTY_VALUE;
              }
            else
               if(InpDisplayMode == DISPLAY_RSI_AND_BANDS)
                 {
                  // By default, we show the MA as the centerline for the bands.
                 }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
