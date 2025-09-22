//+------------------------------------------------------------------+
//|                                                    Holt_MA.mq5   |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.00"
#property description "Holt's Linear Trend Method (Double Exponential Smoothing)."
#property description "Provides a smoothed line with a 1-bar forecast."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Holt MA Forecast Line
#property indicator_label1  "Holt MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int              InpPeriod      = 20;    // Period for initialization
input double           InpAlpha       = 0.1;   // Alpha (Level smoothing factor, 0 < a < 1)
input double           InpBeta        = 0.05;  // Beta (Trend smoothing factor, 0 < b < 1)
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE; // Source Price

//--- Indicator Buffers ---
double    BufferHoltMA[];

//+------------------------------------------------------------------+
//| CLASS: CHoltMACalculator                                         |
//| Encapsulates the Double Exponential Smoothing logic.             |
//+------------------------------------------------------------------+
class CHoltMACalculator
  {
private:
   //--- Parameters
   int               m_period;
   double            m_alpha;
   double            m_beta;

   //--- Internal calculation buffers
   double            m_price[];
   double            m_level[];
   double            m_trend[];
   double            m_forecast[];

public:
                     CHoltMACalculator(void);
                    ~CHoltMACalculator(void) {};

   bool              Init(int period, double alpha, double beta);
   void              Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                  double &holt_ma_out[]);
  };

//+------------------------------------------------------------------+
//| CHoltMACalculator: Constructor                                   |
//+------------------------------------------------------------------+
CHoltMACalculator::CHoltMACalculator(void) : m_period(0), m_alpha(0.1), m_beta(0.05)
  {
  }

//+------------------------------------------------------------------+
//| CHoltMACalculator: Initialization                                |
//+------------------------------------------------------------------+
bool CHoltMACalculator::Init(int period, double alpha, double beta)
  {
   m_period = (period < 2) ? 2 : period;

//--- Constrain alpha and beta to be between 0 and 1
   m_alpha = (alpha <= 0) ? 0.0001 : (alpha >= 1) ? 0.9999 : alpha;
   m_beta  = (beta <= 0) ? 0.0001 : (beta >= 1) ? 0.9999 : beta;

   return true;
  }

//+------------------------------------------------------------------+
//| CHoltMACalculator: Main Calculation Method                       |
//+------------------------------------------------------------------+
void CHoltMACalculator::Calculate(int rates_total, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &holt_ma_out[])
  {
   if(rates_total < m_period)
      return;

//--- Resize internal buffers
   ArrayResize(m_price, rates_total);
   ArrayResize(m_level, rates_total);
   ArrayResize(m_trend, rates_total);
   ArrayResize(m_forecast, rates_total);

//--- Step 1: Prepare the source price series
   PriceSeries(price_type, rates_total, open, high, low, close, m_price);

//--- Step 2: Robust Initialization of the first Level and Trend
   m_level[0] = m_price[0];
   m_trend[0] = m_price[1] - m_price[0]; // Initial trend estimate
   m_forecast[0] = m_level[0] + m_trend[0];
   m_forecast[1] = m_forecast[0]; // To avoid zero value at the start

//--- Step 3: Recursive calculation for the rest of the series
   for(int i = 2; i < rates_total; i++)
     {
      //--- Calculate Level
      m_level[i] = m_alpha * m_price[i] + (1 - m_alpha) * (m_level[i-1] + m_trend[i-1]);

      //--- Calculate Trend
      m_trend[i] = m_beta * (m_level[i] - m_level[i-1]) + (1 - m_beta) * m_trend[i-1];

      //--- Calculate 1-bar ahead Forecast (this is the plotted line)
      m_forecast[i] = m_level[i] + m_trend[i];
     }

//--- Copy final results to the output buffer
   ArrayCopy(holt_ma_out, m_forecast, 0, 0, rates_total);
  }

//+------------------------------------------------------------------+
//| Helper function to get the selected price series.                |
//+------------------------------------------------------------------+
void PriceSeries(ENUM_APPLIED_PRICE type, int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dest_buffer[])
  {
   switch(type)
     {
      case PRICE_CLOSE:
         ArrayCopy(dest_buffer, close, 0, 0, rates_total);
         break;
      case PRICE_OPEN:
         ArrayCopy(dest_buffer, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(dest_buffer, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(dest_buffer, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            dest_buffer[i] = (high[i]+low[i]+close[i]+close[i])/4.0;
         break;
     }
  }


//--- Global calculator object ---
CHoltMACalculator *g_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferHoltMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferHoltMA, false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 2); // Start drawing from the 3rd bar
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Holt MA(%d, %.2f, %.2f)", InpPeriod, InpAlpha, InpBeta));

   g_calculator = new CHoltMACalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpAlpha, InpBeta))
     {
      Print("Failed to initialize Holt MA Calculator.");
      return(INIT_FAILED);
     }
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
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      g_calculator.Calculate(rates_total, InpSourcePrice, open, high, low, close, BufferHoltMA);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
