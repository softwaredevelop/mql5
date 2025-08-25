//+------------------------------------------------------------------+
//|                                                 CCI_Precise.mq5  |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Commodity Channel Index (Precise mathematical definition) with a signal line."

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // CCI and Signal Line
#property indicator_plots   2
#property indicator_level1 -100.0
#property indicator_level2  100.0
#property indicator_level3  0.0
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: CCI line
#property indicator_label1  "CCI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Input Parameters ---
input int                InpCCIPeriod    = 20;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_TYPICAL;
input group              "Signal Line Settings"
input int                InpMAPeriod     = 14;
input ENUM_MA_METHOD     InpMAMethod     = MODE_SMA;

//--- Indicator Buffers ---
double    BufferCCI[];
double    BufferSignal[];

//--- Global Variables ---
int       g_ExtCCIPeriod, g_ExtMAPeriod;
const double CCI_CONSTANT = 0.015;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtCCIPeriod = (InpCCIPeriod < 1) ? 1 : InpCCIPeriod;
   g_ExtMAPeriod  = (InpMAPeriod < 1) ? 1 : InpMAPeriod;

   SetIndexBuffer(0, BufferCCI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferCCI,    false);
   ArraySetAsSeries(BufferSignal, false);

   int cci_draw_begin = g_ExtCCIPeriod - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, cci_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, cci_draw_begin + g_ExtMAPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Precise(%d, %d)", g_ExtCCIPeriod, g_ExtMAPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Commodity Channel Index (Precise) calculation function.          |
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
   int start_pos = g_ExtCCIPeriod + g_ExtMAPeriod - 1;
   if(rates_total < start_pos)
      return(0);

//--- STEP 1: Prepare the source price array
   double price_source[];
   ArrayResize(price_source, rates_total);
   for(int i=0; i<rates_total; i++)
     {
      switch(InpAppliedPrice)
        {
         case PRICE_OPEN:
            price_source[i] = open[i];
            break;
         case PRICE_HIGH:
            price_source[i] = high[i];
            break;
         case PRICE_LOW:
            price_source[i] = low[i];
            break;
         case PRICE_MEDIAN:
            price_source[i] = (high[i] + low[i]) / 2.0;
            break;
         case PRICE_TYPICAL:
            price_source[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         case PRICE_WEIGHTED:
            price_source[i]= (high[i] + low[i] + 2*close[i]) / 4.0;
            break;
         default:
            price_source[i] = close[i];
            break;
        }
     }

//--- STEP 2: Calculate CCI using the precise definition
   for(int i = g_ExtCCIPeriod - 1; i < rates_total; i++)
     {
      // --- Calculate the SMA for the current position 'i' ---
      double sma = 0;
      for(int j=0; j<g_ExtCCIPeriod; j++)
        {
         sma += price_source[i-j];
        }
      sma /= g_ExtCCIPeriod;

      // --- Calculate the Mean Absolute Deviation for the current position 'i' ---
      double mad = 0;
      for(int j=0; j<g_ExtCCIPeriod; j++)
        {
         mad += MathAbs(price_source[i-j] - sma);
        }
      mad /= g_ExtCCIPeriod;

      // --- Calculate the final CCI value ---
      if(mad > 0)
        {
         BufferCCI[i] = (price_source[i] - sma) / (CCI_CONSTANT * mad);
        }
     }

//--- STEP 3: Calculate the Signal Line (MA of CCI)
   int ma_start_pos = g_ExtCCIPeriod + g_ExtMAPeriod - 2;
   for(int i = ma_start_pos; i < rates_total; i++)
     {
      switch(InpMAMethod)
        {
         case MODE_EMA:
         case MODE_SMMA:
            if(i == ma_start_pos)
              {
               double sum=0;
               for(int j=0; j<g_ExtMAPeriod; j++)
                  sum+=BufferCCI[i-j];
               BufferSignal[i] = sum/g_ExtMAPeriod;
              }
            else
              {
               if(InpMAMethod == MODE_EMA)
                 {
                  double pr=2.0/(g_ExtMAPeriod+1.0);
                  BufferSignal[i] = BufferCCI[i]*pr + BufferSignal[i-1]*(1.0-pr);
                 }
               else
                  BufferSignal[i] = (BufferSignal[i-1]*(g_ExtMAPeriod-1)+BufferCCI[i])/g_ExtMAPeriod;
              }
            break;
         case MODE_LWMA:
           {
            double lwma_sum=0, weight_sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
              {
               int weight=g_ExtMAPeriod-j;
               lwma_sum+=BufferCCI[i-j]*weight;
               weight_sum+=weight;
              }
            if(weight_sum>0)
               BufferSignal[i]=lwma_sum/weight_sum;
           }
         break;
         default: // MODE_SMA
           {
            double sum=0;
            for(int j=0; j<g_ExtMAPeriod; j++)
               sum+=BufferCCI[i-j];
            BufferSignal[i] = sum/g_ExtMAPeriod;
           }
         break;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
