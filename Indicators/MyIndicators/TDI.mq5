//+------------------------------------------------------------------+
//|                                                          TDI.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Trader's Dynamic Index (TDI) - The Market in One Window"

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 32.0
#property indicator_level2 50.0
#property indicator_level3 68.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: RSI Price Line (Fast)
#property indicator_label1  "Price Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Trade Signal Line (Slow)
#property indicator_label2  "Signal Line"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Market Base Line (Trend)
#property indicator_label3  "Base Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Plot 4: Upper Volatility Band
#property indicator_label4  "Upper Band"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DASHDOT
#property indicator_width4  1

//--- Plot 5: Lower Volatility Band
#property indicator_label5  "Lower Band"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_DASHDOT
#property indicator_width5  1

//--- Input Parameters ---
input int    InpRsiPeriod      = 13;    // RSI Period
input int    InpPriceLinePeriod  = 2;     // RSI Price Line (Fast MA)
input int    InpSignalLinePeriod = 7;     // Trade Signal Line (Slow MA)
input int    InpBaseLinePeriod   = 34;    // Market Base Line (Trend MA)
input double InpBandsDeviation   = 1.618; // Volatility Bands Deviation
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE; // Source Price

//--- Indicator Buffers ---
double    BufferPriceLine[];
double    BufferSignalLine[];
double    BufferBaseLine[];
double    BufferUpperBand[];
double    BufferLowerBand[];

//+------------------------------------------------------------------+
//| CLASS: CTDICalculator                                            |
//| Encapsulates the entire multi-stage TDI calculation.             |
//+------------------------------------------------------------------+
class CTDICalculator
  {
private:
   //--- Parameters
   int               m_rsi_period;
   int               m_price_period;
   int               m_signal_period;
   int               m_base_period;
   double            m_std_dev;

   //--- Internal calculation buffers
   double            m_rsi_buffer[];
   double            m_price_line[];
   double            m_signal_line[];
   double            m_base_line[];
   double            m_upper_band[];
   double            m_lower_band[];

   //--- Helper for SMA calculation
   double            CalculateSMA(int position, int period, const double &source_buffer[]);

public:
                     CTDICalculator(void) {};
                    ~CTDICalculator(void) {};

   bool              Init(int rsi_p, int price_p, int signal_p, int base_p, double dev);
   void              Calculate(int rates_total, const double &price[],
                  double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                  double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//| CTDICalculator: Initialization                                   |
//+------------------------------------------------------------------+
bool CTDICalculator::Init(int rsi_p, int price_p, int signal_p, int base_p, double dev)
  {
   m_rsi_period = (rsi_p < 1) ? 1 : rsi_p;
   m_price_period = (price_p < 1) ? 1 : price_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_base_period = (base_p < 1) ? 1 : base_p;
   m_std_dev = (dev <= 0) ? 1.618 : dev;
   return true;
  }

//+------------------------------------------------------------------+
//| CTDICalculator: Main Calculation Method                          |
//+------------------------------------------------------------------+
void CTDICalculator::Calculate(int rates_total, const double &price[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[])
  {
   if(rates_total <= m_rsi_period)
      return;

//--- Resize all internal buffers
   ArrayResize(m_rsi_buffer, rates_total);
   ArrayResize(m_price_line, rates_total);
   ArrayResize(m_signal_line, rates_total);
   ArrayResize(m_base_line, rates_total);
   ArrayResize(m_upper_band, rates_total);
   ArrayResize(m_lower_band, rates_total);

//--- Step 1: Calculate base RSI (Wilder's smoothing)
   double sum_pos = 0, sum_neg = 0;
   for(int i = 1; i < rates_total; i++)
     {
      double diff = price[i] - price[i-1];
      sum_pos = (sum_pos * (m_rsi_period - 1) + (diff > 0 ? diff : 0)) / m_rsi_period;
      sum_neg = (sum_neg * (m_rsi_period - 1) + (diff < 0 ? -diff : 0)) / m_rsi_period;

      if(i > m_rsi_period) // Start calculation after initial smoothing
        {
         if(sum_neg > 0)
           {
            double rs = sum_pos / sum_neg;
            m_rsi_buffer[i] = 100.0 - (100.0 / (1.0 + rs));
           }
         else
           {
            m_rsi_buffer[i] = 100.0;
           }
        }
     }

//--- Step 2: Calculate RSI Price Line (Green)
   for(int i = m_rsi_period + m_price_period; i < rates_total; i++)
     {
      m_price_line[i] = CalculateSMA(i, m_price_period, m_rsi_buffer);
     }

//--- Step 3: Calculate Trade Signal Line (Red)
   for(int i = m_rsi_period + m_price_period + m_signal_period; i < rates_total; i++)
     {
      m_signal_line[i] = CalculateSMA(i, m_signal_period, m_price_line);
     }

//--- Step 4: Calculate Market Base Line (Yellow)
   for(int i = m_rsi_period + m_price_period + m_base_period; i < rates_total; i++)
     {
      m_base_line[i] = CalculateSMA(i, m_base_period, m_price_line);
     }

//--- Step 5: Calculate Volatility Bands (Blue)
   for(int i = m_rsi_period + m_price_period + m_base_period; i < rates_total; i++)
     {
      double std_dev_val = 0;
      double sum_sq = 0;
      for(int j = 0; j < m_base_period; j++)
        {
         sum_sq += pow(m_price_line[i-j] - m_base_line[i], 2);
        }
      std_dev_val = sqrt(sum_sq / m_base_period);

      m_upper_band[i] = m_base_line[i] + m_std_dev * std_dev_val;
      m_lower_band[i] = m_base_line[i] - m_std_dev * std_dev_val;
     }

//--- Copy final results to the output buffers
   ArrayCopy(price_line_out, m_price_line, 0, 0, rates_total);
   ArrayCopy(signal_line_out, m_signal_line, 0, 0, rates_total);
   ArrayCopy(base_line_out, m_base_line, 0, 0, rates_total);
   ArrayCopy(upper_band_out, m_upper_band, 0, 0, rates_total);
   ArrayCopy(lower_band_out, m_lower_band, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Helper to calculate SMA on an internal buffer                    |
//+------------------------------------------------------------------+
double CTDICalculator::CalculateSMA(int position, int period, const double &source_buffer[])
  {
   double sum = 0;
   for(int i = 0; i < period; i++)
     {
      sum += source_buffer[position - i];
     }
   return (period > 0) ? sum / period : 0;
  }


//--- Global calculator object ---
CTDICalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferPriceLine,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignalLine, INDICATOR_DATA);
   SetIndexBuffer(2, BufferBaseLine,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferUpperBand,  INDICATOR_DATA);
   SetIndexBuffer(4, BufferLowerBand,  INDICATOR_DATA);

   ArraySetAsSeries(BufferPriceLine,  false);
   ArraySetAsSeries(BufferSignalLine, false);
   ArraySetAsSeries(BufferBaseLine,   false);
   ArraySetAsSeries(BufferUpperBand,  false);
   ArraySetAsSeries(BufferLowerBand,  false);

   g_calculator = new CTDICalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpRsiPeriod, InpPriceLinePeriod, InpSignalLinePeriod, InpBaseLinePeriod, InpBandsDeviation))
     {
      Print("Failed to initialize TDI Calculator.");
      return(INIT_FAILED);
     }

   int draw_begin = InpRsiPeriod + InpPriceLinePeriod + InpBaseLinePeriod;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, draw_begin);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("TDI(%d)", InpRsiPeriod));

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
      //--- The TDI is always calculated on the Close price
      g_calculator.Calculate(rates_total, close, BufferPriceLine, BufferSignalLine, BufferBaseLine, BufferUpperBand, BufferLowerBand);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
