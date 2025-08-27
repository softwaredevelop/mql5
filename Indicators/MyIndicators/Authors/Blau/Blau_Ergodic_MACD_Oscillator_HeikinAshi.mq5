//+------------------------------------------------------------------+
//|                          Blau_Ergodic_MACD_Oscillator_HeikinAshi.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.00"
#property description "Ergodic MACD Oscillator on Heikin Ashi data"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_separate_window
#property indicator_buffers 1 // Only the histogram
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label1  "HA_Ergodic_MACD_Osc"
#property indicator_level1  0.0
#property indicator_levelstyle STYLE_DOT

//--- Enum for selecting Heikin Ashi price source ---
enum ENUM_HA_APPLIED_PRICE
  {
   HA_PRICE_CLOSE, HA_PRICE_OPEN, HA_PRICE_HIGH, HA_PRICE_LOW
  };

//--- Input Parameters ---
input group                 "Classic MACD Settings"
input int                   InpFastEMAPeriod   = 12;
input int                   InpSlowEMAPeriod   = 26;
input int                   InpSignalEMAPeriod = 9;
input ENUM_HA_APPLIED_PRICE InpAppliedPrice    = HA_PRICE_CLOSE;
input group                 "Ergodic Smoothing Settings"
input int                   InpSlowSmoothPeriod = 20;
input int                   InpFastSmoothPeriod = 5;

//--- Indicator Buffers ---
double    BufferOscillator[];

//--- Global Objects and Variables ---
int                       g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA, g_ExtSlowSmooth, g_ExtFastSmooth;
CHeikinAshi_Calculator   *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ExtFastEMA      = (InpFastEMAPeriod < 1) ? 1 : InpFastEMAPeriod;
   g_ExtSlowEMA      = (InpSlowEMAPeriod < 1) ? 1 : InpSlowEMAPeriod;
   g_ExtSignalEMA    = (InpSignalEMAPeriod < 1) ? 1 : InpSignalEMAPeriod;
   g_ExtSlowSmooth   = (InpSlowSmoothPeriod < 1) ? 1 : InpSlowSmoothPeriod;
   g_ExtFastSmooth   = (InpFastSmoothPeriod < 1) ? 1 : InpFastSmoothPeriod;

   if(g_ExtFastEMA > g_ExtSlowEMA)
     {
      int temp = g_ExtFastEMA;
      g_ExtFastEMA = g_ExtSlowEMA;
      g_ExtSlowEMA = temp;
     }

   SetIndexBuffer(0, BufferOscillator, INDICATOR_DATA);
   ArraySetAsSeries(BufferOscillator, false);

   int draw_begin = g_ExtSlowEMA + g_ExtSignalEMA + g_ExtSlowSmooth + g_ExtFastSmooth - 3;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);

// --- FIX: Corrected StringFormat call with all parameters ---
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("HA_Ergodic_MACD_Osc(%d,%d,%d,%d,%d)",
                      g_ExtFastEMA, g_ExtSlowEMA, g_ExtSignalEMA, g_ExtSlowSmooth, g_ExtFastSmooth));

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Ergodic MACD Oscillator on Heikin Ashi calculation function.     |
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
   int start_pos = g_ExtSlowEMA + g_ExtSignalEMA + g_ExtSlowSmooth + g_ExtFastSmooth - 3;
   if(rates_total <= start_pos)
      return(0);

//--- Intermediate Heikin Ashi Buffers
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(ha_high, rates_total);
   ArrayResize(ha_low, rates_total);
   ArrayResize(ha_close, rates_total);

//--- STEP 1: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- STEP 2: Calculate Classic MACD Line and Signal Line on HA data
   double classic_macd_line[], classic_signal_line[];
   ArrayResize(classic_macd_line, rates_total);
   ArrayResize(classic_signal_line, rates_total);

     {
      double ha_price_source[];
      ArrayResize(ha_price_source, rates_total);
      switch(InpAppliedPrice)
        {
         case HA_PRICE_OPEN:
            ArrayCopy(ha_price_source, ha_open);
            break;
         case HA_PRICE_HIGH:
            ArrayCopy(ha_price_source, ha_high);
            break;
         case HA_PRICE_LOW:
            ArrayCopy(ha_price_source, ha_low);
            break;
         default:
            ArrayCopy(ha_price_source, ha_close);
            break;
        }

      double fast_ema[], slow_ema[];
      ArrayResize(fast_ema, rates_total);
      ArrayResize(slow_ema, rates_total);

      double pr_fast = 2.0/(g_ExtFastEMA+1.0);
      for(int i=g_ExtFastEMA-1; i<rates_total; i++)
        {
         if(i==g_ExtFastEMA-1)
           {
            double sum=0;
            for(int j=0;j<g_ExtFastEMA;j++)
               sum+=ha_price_source[i-j];
            fast_ema[i]=sum/g_ExtFastEMA;
           }
         else
            fast_ema[i] = ha_price_source[i]*pr_fast + fast_ema[i-1]*(1.0-pr_fast);
        }

      double pr_slow = 2.0/(g_ExtSlowEMA+1.0);
      for(int i=g_ExtSlowEMA-1; i<rates_total; i++)
        {
         if(i==g_ExtSlowEMA-1)
           {
            double sum=0;
            for(int j=0;j<g_ExtSlowEMA;j++)
               sum+=ha_price_source[i-j];
            slow_ema[i]=sum/g_ExtSlowEMA;
           }
         else
            slow_ema[i] = ha_price_source[i]*pr_slow + slow_ema[i-1]*(1.0-pr_slow);
        }

      for(int i=g_ExtSlowEMA-1; i<rates_total; i++)
         classic_macd_line[i] = fast_ema[i] - slow_ema[i];

      double pr_signal = 2.0/(g_ExtSignalEMA+1.0);
      int signal_start = g_ExtSlowEMA + g_ExtSignalEMA - 2;
      for(int i=signal_start; i<rates_total; i++)
        {
         if(i==signal_start)
           {
            double sum=0;
            for(int j=0;j<g_ExtSignalEMA;j++)
               sum+=classic_macd_line[i-j];
            classic_signal_line[i]=sum/g_ExtSignalEMA;
           }
         else
            classic_signal_line[i] = classic_macd_line[i]*pr_signal + classic_signal_line[i-1]*(1.0-pr_signal);
        }
     }

//--- STEP 3: First Ergodic Smoothing (Slow Period) on Classic Lines
   double ema1_macd[], ema1_signal[];
   ArrayResize(ema1_macd, rates_total);
   ArrayResize(ema1_signal, rates_total);
   double pr_slow_smooth = 2.0 / (g_ExtSlowSmooth + 1.0);
   int ema1_start_pos = g_ExtSlowEMA + g_ExtSignalEMA + g_ExtSlowSmooth - 3;

   for(int i = ema1_start_pos; i < rates_total; i++)
     {
      if(i == ema1_start_pos)
        {
         double sum_macd=0, sum_signal=0;
         for(int j=0; j<g_ExtSlowSmooth; j++)
           {
            sum_macd += classic_macd_line[i-j];
            sum_signal += classic_signal_line[i-j];
           }
         ema1_macd[i] = sum_macd / g_ExtSlowSmooth;
         ema1_signal[i] = sum_signal / g_ExtSlowSmooth;
        }
      else
        {
         ema1_macd[i] = classic_macd_line[i] * pr_slow_smooth + ema1_macd[i-1] * (1.0 - pr_slow_smooth);
         ema1_signal[i] = classic_signal_line[i] * pr_slow_smooth + ema1_signal[i-1] * (1.0 - pr_slow_smooth);
        }
     }

//--- STEP 4: Second Ergodic Smoothing (Fast Period) on EMA1
   double ergodic_macd[], ergodic_signal[];
   ArrayResize(ergodic_macd, rates_total);
   ArrayResize(ergodic_signal, rates_total);
   double pr_fast_smooth = 2.0 / (g_ExtFastSmooth + 1.0);
   int ema2_start_pos = ema1_start_pos + g_ExtFastSmooth - 1;

   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      if(i == ema2_start_pos)
        {
         double sum_macd=0, sum_signal=0;
         for(int j=0; j<g_ExtFastSmooth; j++)
           {
            sum_macd += ema1_macd[i-j];
            sum_signal += ema1_signal[i-j];
           }
         ergodic_macd[i] = sum_macd / g_ExtFastSmooth;
         ergodic_signal[i] = sum_signal / g_ExtFastSmooth;
        }
      else
        {
         ergodic_macd[i] = ema1_macd[i] * pr_fast_smooth + ergodic_macd[i-1] * (1.0 - pr_fast_smooth);
         ergodic_signal[i] = ema1_signal[i] * pr_fast_smooth + ergodic_signal[i-1] * (1.0 - pr_fast_smooth);
        }
     }

//--- STEP 5: Calculate the final Oscillator value ---
   for(int i = ema2_start_pos; i < rates_total; i++)
     {
      BufferOscillator[i] = ergodic_macd[i] - ergodic_signal[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
