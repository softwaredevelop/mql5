//+------------------------------------------------------------------+
//|                                                    Sine_WMA.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.01"
#property description "Sine Weighted Moving Average. A zero-lag smoothing filter."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Sine WMA Line
#property indicator_label1  "Sine WMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpPeriod      = 21;
input ENUM_APPLIED_PRICE InpSourcePrice = PRICE_CLOSE;

//--- Indicator Buffers ---
double    BufferWMA[];
double    BufferPrice[];

//+------------------------------------------------------------------+
//| CLASS: CSineWMACalculator                                        |
//| Encapsulates the logic for Sine weighting.                       |
//+------------------------------------------------------------------+
class CSineWMACalculator
  {
private:
   int               m_period;
   double            m_weights[];
   double            m_weight_sum;

public:
                     CSineWMACalculator(void);
                    ~CSineWMACalculator(void) {};

   bool              Init(int period);
   void              Calculate(int rates_total, const double &price_src[], double &wma_out[]);
  };

//+------------------------------------------------------------------+
//| CSineWMACalculator: Constructor                                  |
//+------------------------------------------------------------------+
CSineWMACalculator::CSineWMACalculator(void) : m_period(0), m_weight_sum(0)
  {
  }

//+------------------------------------------------------------------+
//| CSineWMACalculator: Initialization and Weight Generation         |
//+------------------------------------------------------------------+
bool CSineWMACalculator::Init(int period)
  {
   m_period = (period < 2) ? 2 : period;

   ArrayResize(m_weights, m_period);
   m_weight_sum = 0;

   for(int i = 0; i < m_period; i++)
     {
      m_weights[i] = MathSin(M_PI * (i + 1.0) / (m_period + 1.0));
      m_weight_sum += m_weights[i];
     }

   return (m_weight_sum != 0);
  }

//+------------------------------------------------------------------+
//| CSineWMACalculator: Main Calculation Method (No phase shift)     |
//+------------------------------------------------------------------+
void CSineWMACalculator::Calculate(int rates_total, const double &price_src[], double &wma_out[])
  {
   if(rates_total < m_period)
      return;

   for(int i = m_period - 1; i < rates_total; i++)
     {
      double weighted_sum = 0;
      for(int j = 0; j < m_period; j++)
        {
         //--- Symmetrical weighting, use weights as generated
         weighted_sum += price_src[i - j] * m_weights[j];
        }

      //--- No displacement, result is plotted at the current bar
      wma_out[i] = weighted_sum / m_weight_sum;
     }
  }

//--- Global calculator object ---
CSineWMACalculator *g_calculator;

//--- Forward declaration
int PriceSeries(ENUM_APPLIED_PRICE,int,const double&[],const double&[],const double&[],const double&[],double&[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferWMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferWMA, false);

   g_calculator = new CSineWMACalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod))
     {
      Print("Failed to initialize Sine WMA Calculator.");
      return(INIT_FAILED);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SineWMA(%d)", InpPeriod));

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
   ArrayResize(BufferPrice, rates_total);
   if(PriceSeries(InpSourcePrice, rates_total, open, high, low, close, BufferPrice) <= 0)
      return 0;

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      g_calculator.Calculate(rates_total, BufferPrice, BufferWMA);
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper function to get the selected price series.                |
//+------------------------------------------------------------------+
int PriceSeries(ENUM_APPLIED_PRICE type, int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], double &dest_buffer[])
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
      default:
         return 0;
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
