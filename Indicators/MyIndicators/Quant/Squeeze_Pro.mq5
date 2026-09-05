//+------------------------------------------------------------------+
//|                                                  Squeeze_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with 4-Color TTM Linear Regression Momentum
#property description "Professional Volatility Squeeze Indicator (TTM Squeeze Model) with Native & MTF Support."
#property description "Combines Bollinger Bands and Keltner Channels with 4-Color Linear Regression Momentum."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: TTM Linear Regression Momentum Histogram
#property indicator_label1  "Momentum"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Swapped Thermal 4-Color Palette:
// 0: Bullish Expanding    (LightSkyBlue)
// 1: Bullish Decelerating (DeepSkyBlue)
// 2: Bearish Expanding    (OrangeRed)
// 3: Bearish Decelerating (Coral)
#property indicator_color1  clrLightSkyBlue, clrDeepSkyBlue, clrOrangeRed, clrCoral
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Squeeze State Dots (On Zero Baseline)
#property indicator_label2  "Squeeze State"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrLime, clrRed // 0=Lime (Fired / No Squeeze), 1=Red (Squeeze Active)
#property indicator_width2  2

//--- Included Engines & Core Tools
#include <MyIncludes\Squeeze_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Squeeze Core Settings ---"
input int                       InpPeriod         = 20;                // Combined Lookback Period (BB & KC)
input double                    InpBBMult         = 2.0;               // Bollinger Bands Multiplier (Sigma)
input double                    InpKCMult         = 1.5;               // Keltner Channel Multiplier (ATR)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Momentum Settings (Linear Regression) ---"
input int                       InpMomPeriod      = 20;                // Linear Regression Momentum Period

input group "--- Visual Settings - Momentum Histogram ---"
input color                     InpColorBullExp   = clrLightSkyBlue;   // Bullish Expanding Color
input color                     InpColorBullDec   = clrDeepSkyBlue;    // Bullish Decelerating Color
input color                     InpColorBearExp   = clrOrangeRed;      // Bearish Expanding Color
input color                     InpColorBearDec   = clrCoral;          // Bearish Decelerating Color

input group "--- Visual Settings - Squeeze Dots ---"
input color                     InpColorSqzOff    = clrLime;           // Squeeze Fired / OFF Color (Action)
input color                     InpColorSqzOn     = clrRed;            // Squeeze Active / ON Color (Compression)
input int                       InpDotSize        = 2;                 // Zero Dot Size

//--- Indicator Buffers ---
double BufferMom[];
double BufferMomColor[];
double BufferSqueeze[];
double BufferSqueezeColors[];

//--- Internal HTF Data Caches (Chronological Arrays)
double h_open[], h_high[], h_low[], h_close[];
double h_res_mom[], h_res_mom_col[];
double h_res_sqz_val[], h_res_sqz_col[];
datetime h_time[];

//--- Global Objects & State Management
CSqueezeCalculator *g_calculator = NULL;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return INIT_PARAMETERS_INCORRECT;
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

// 2. Bind Buffers
   SetIndexBuffer(0, BufferMom,           INDICATOR_DATA);
   SetIndexBuffer(1, BufferMomColor,      INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSqueeze,       INDICATOR_DATA);
   SetIndexBuffer(3, BufferSqueezeColors, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferMom,           false);
   ArraySetAsSeries(BufferMomColor,      false);
   ArraySetAsSeries(BufferSqueeze,       false);
   ArraySetAsSeries(BufferSqueezeColors, false);

   ArrayInitialize(BufferMom,           0.0);
   ArrayInitialize(BufferMomColor,      0.0);
   ArrayInitialize(BufferSqueeze,       0.0);
   ArrayInitialize(BufferSqueezeColors, 0.0);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorBullExp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorBullDec);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorBearExp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, InpColorBearDec);

   PlotIndexSetInteger(1, PLOT_ARROW, 159); // Solid circle/dot character
   PlotIndexSetInteger(1, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, InpColorSqzOff);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 1, InpColorSqzOn);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpDotSize);

   int warmup = MathMax(InpPeriod, InpMomPeriod) + 5;
   int draw_begin = warmup;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

// 4. Initialize Core Squeeze Engine
   g_calculator = new CSqueezeCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpBBMult, InpKCMult, InpMomPeriod, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Squeeze Calculator Engine.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Squeeze Pro%s%s(%d, BB:%.1f, KC:%.1f)",
                                    ha_tag, tf_str,
                                    InpPeriod, InpBBMult, InpKCMult);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Momentum");
   PlotIndexSetString(1, PLOT_LABEL, "Squeeze State");

// 5. Initialize Background Synchronization Timer (Only for MTF mode)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
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
//| Custom Indicator Calculation Loop                                |
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
   int warmup = MathMax(InpPeriod, InpMomPeriod) + 5;
   if(rates_total < warmup || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close,
                             BufferMom, BufferMomColor, BufferSqueeze, BufferSqueezeColors);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   int required_bars = warmup + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays
      ArrayResize(h_time,        g_htf_count);
      ArrayResize(h_open,        g_htf_count);
      ArrayResize(h_high,        g_htf_count);
      ArrayResize(h_low,         g_htf_count);
      ArrayResize(h_close,       g_htf_count);
      ArrayResize(h_res_mom,     g_htf_count);
      ArrayResize(h_res_mom_col, g_htf_count);
      ArrayResize(h_res_sqz_val, g_htf_count);
      ArrayResize(h_res_sqz_col, g_htf_count);

      ArraySetAsSeries(h_time,        false);
      ArraySetAsSeries(h_open,        false);
      ArraySetAsSeries(h_high,        false);
      ArraySetAsSeries(h_low,         false);
      ArraySetAsSeries(h_close,       false);
      ArraySetAsSeries(h_res_mom,     false);
      ArraySetAsSeries(h_res_mom_col, false);
      ArraySetAsSeries(h_res_sqz_val, false);
      ArraySetAsSeries(h_res_sqz_col, false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Compute HTF Squeeze Values
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close,
                             h_res_mom, h_res_mom_col, h_res_sqz_val, h_res_sqz_col);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      datetime t_bar[1];

      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyTime(_Symbol,  g_calc_timeframe, shift, 1, t_bar) == 1 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o)     == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h)     == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l)     == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c)     == 1)
        {
         h_time[live_idx]  = t_bar[0];
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Mock update on live HTF bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close,
                                h_res_mom, h_res_mom_col, h_res_sqz_val, h_res_sqz_col);
        }
     }

// 6. Forming LTF Block Flat-Force Anchor (The Staircase Solution)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++;

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// 7. Chronological Mapping Loop to Chart Timeframe (4 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferMom[i]           = h_res_mom[idx_htf];
            BufferMomColor[i]      = h_res_mom_col[idx_htf];
            BufferSqueeze[i]       = 0.0;
            BufferSqueezeColors[i] = h_res_sqz_col[idx_htf];
           }
         else
           {
            BufferMom[i]           = 0.0;
            BufferMomColor[i]      = 0.0;
            BufferSqueeze[i]       = 0.0;
            BufferSqueezeColors[i] = 0.0;
           }
        }
      else
        {
         BufferMom[i]           = 0.0;
         BufferMomColor[i]      = 0.0;
         BufferSqueeze[i]       = 0.0;
         BufferSqueezeColors[i] = 0.0;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = MathMax(InpPeriod, InpMomPeriod) + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, warmup, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
