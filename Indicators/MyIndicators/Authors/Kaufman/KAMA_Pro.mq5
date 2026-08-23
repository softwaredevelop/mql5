//+------------------------------------------------------------------+
//|                                                         KAMA_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.30" // Unified Native & MTF High-Performance Engine
#property description "Professional Kaufman's Adaptive Moving Average with Native Multi-Timeframe (MTF) Support."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Definition
#property indicator_label1  "KAMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include <MyIncludes\KAMA_Calculator.mqh>

//--- Input Parameters ---
input group                     "Timeframe Settings"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or Higher)

input group                     "KAMA Core Settings"
input int                       InpErPeriod       = 10;                // Efficiency Ratio Period
input int                       InpFastEmaPeriod  = 2;                 // Fastest EMA Period
input int                       InpSlowEmaPeriod  = 30;                // Slowest EMA Period
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group                     "Visual Settings"
input color                     InpColorKAMA      = clrCrimson;        // Line Color
input ENUM_LINE_STYLE           InpStyleKAMA      = STYLE_SOLID;       // Line Style
input int                       InpWidthKAMA      = 1;                 // Line Width

//--- Indicator Buffers ---
double BufferKAMA[];

//--- Global Engine & MTF Tracking ---
CKamaCalculator *g_calculator = NULL;
bool             g_is_mtf_mode = false;
ENUM_TIMEFRAMES  g_calc_timeframe;
int              g_htf_prev_calculated = 0;

//--- HTF Dynamic Data Caches (Chronological Arrays)
double           g_htf_open[];
double           g_htf_high[];
double           g_htf_low[];
double           g_htf_close[];
double           g_htf_kama[];

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// 1. Timeframe Resolution & Validation
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Error: Selected timeframe (%s) cannot be lower than chart timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Setup Indicator Buffer
   SetIndexBuffer(0, BufferKAMA, INDICATOR_DATA);
   ArraySetAsSeries(BufferKAMA, false);
   ArrayInitialize(BufferKAMA, EMPTY_VALUE);

// Configure Visuals
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleKAMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthKAMA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpErPeriod);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 3. Initialize MTF Caches (Chronological Order)
   if(g_is_mtf_mode)
     {
      ArraySetAsSeries(g_htf_open, false);
      ArraySetAsSeries(g_htf_high, false);
      ArraySetAsSeries(g_htf_low, false);
      ArraySetAsSeries(g_htf_close, false);
      ArraySetAsSeries(g_htf_kama, false);
     }

// 4. Initialize Engine
   g_calculator = new CKamaCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod, InpSourcePrice))
     {
      Print("Error: Failed to initialize KAMA Calculator.");
      return INIT_FAILED;
     }

// 5. Shortname Construction
   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_tag = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("KAMA%s%s(%d,%d,%d)", ha_tag, tf_tag, InpErPeriod, InpFastEmaPeriod, InpSlowEmaPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

// 6. Asynchronous Data Guard (Enabled only when MTF is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID)
     {
      delete g_calculator;
      g_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| OnTimer (Asynchronous History Data Synchronization Guard)        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_is_mtf_mode)
      return;

   int htf_bars = iBars(_Symbol, g_calc_timeframe);
   if(htf_bars > InpErPeriod && g_htf_prev_calculated == 0)
     {
      ChartSetSymbolPeriod(0, _Symbol, Period()); // Refresh chart
     }
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   if(rates_total <= InpErPeriod || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Chronological Safety
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

//================================================================
// PIPELINE 1: Direct Calculation (Native Timeframe - O(1))
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferKAMA);
      return rates_total;
     }

//================================================================
// PIPELINE 2: Multi-Timeframe (MTF) Synchronized Engine
//================================================================

// 1. Check Available HTF Bars
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total <= InpErPeriod)
      return 0;

// 2. Fetch HTF Price Data into Chronological Caches
   if(CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_htf_open) <= 0 ||
      CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_htf_high) <= 0 ||
      CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_htf_low) <= 0 ||
      CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_htf_close) <= 0)
     {
      return 0; // History sync pending
     }

// 3. Resize HTF Output Buffer
   if(ArraySize(g_htf_kama) != htf_rates_total)
     {
      ArrayResize(g_htf_kama, htf_rates_total);
      ArraySetAsSeries(g_htf_kama, false);
     }

// 4. Compute HTF KAMA Values (Incremental O(1))
   int htf_start = (prev_calculated == 0) ? 0 : g_htf_prev_calculated - 1;
   if(htf_start < 0)
      htf_start = 0;

   g_calculator.Calculate(htf_rates_total, htf_start, g_htf_open, g_htf_high, g_htf_low, g_htf_close, g_htf_kama);
   g_htf_prev_calculated = htf_rates_total;

// 5. Forming LTF Block Flat-Force Anchor (The Staircase Solution)
   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // Dynamic anchor start

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// 6. Chronological Mapping Loop
   for(int i = start; i < rates_total; i++)
     {
      int htf_bar = iBarShift(_Symbol, g_calc_timeframe, time[i], false);
      if(htf_bar >= 0 && htf_bar < htf_rates_total)
        {
         int htf_idx = htf_rates_total - 1 - htf_bar;
         BufferKAMA[i] = g_htf_kama[htf_idx];
        }
      else
        {
         BufferKAMA[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
