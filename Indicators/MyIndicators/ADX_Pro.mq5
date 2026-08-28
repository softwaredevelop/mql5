//+------------------------------------------------------------------+
//|                                                       ADX_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.00" // Unified Native & MTF Release with Dynamic Levels
#property description "Professional ADX & DMI Suite by Welles Wilder with Native & MTF Support."
#property description "Features state-safe incremental calculation and selectable candle source."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: ADX line (Main Trend Strength)
#property indicator_label1  "ADX"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: +DI line (Positive Directional Indicator)
#property indicator_label2  "+DI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOliveDrab
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: -DI line (Negative Directional Indicator)
#property indicator_label3  "-DI"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\ADX_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Enum for selecting candle source ---
#ifndef ENUM_CANDLE_SOURCE_DEFINED
#define ENUM_CANDLE_SOURCE_DEFINED
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };
#endif

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- ADX Core Settings ---"
input int                       InpPeriodADX      = 14;                // Period for ADX calculations
input ENUM_CANDLE_SOURCE        InpCandleSource   = CANDLE_STANDARD;   // Candle source (Standard / HA)

input group "--- Indicator Levels ---"
input double                    InpLevelTrend     = 25.0;              // Trend Strength Threshold
input double                    InpLevelExtreme   = 40.0;              // Strong Trend / Exhaustion Threshold
input color                     InpLevelColor     = clrSilver;         // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;         // Level Lines Style

input group "--- Visual Settings ---"
input color                     InpColorADX       = clrDodgerBlue;     // ADX Line Color
input ENUM_LINE_STYLE           InpStyleADX       = STYLE_SOLID;       // ADX Line Style
input int                       InpWidthADX       = 2;                 // ADX Line Width

input color                     InpColorPDI       = clrOliveDrab;      // +DI Line Color
input ENUM_LINE_STYLE           InpStylePDI       = STYLE_SOLID;       // +DI Line Style
input int                       InpWidthPDI       = 1;                 // +DI Line Width

input color                     InpColorNDI       = clrTomato;         // -DI Line Color
input ENUM_LINE_STYLE           InpStyleNDI       = STYLE_SOLID;       // -DI Line Style
input int                       InpWidthNDI       = 1;                 // -DI Line Width

//--- Indicator Buffers ---
double    BufferADX[];
double    BufferPDI[];
double    BufferNDI[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_res_adx[], h_res_pdi[], h_res_ndi[];
datetime  h_time[];

//--- Global Objects & State Management
CADXCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufferADX, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPDI, INDICATOR_DATA);
   SetIndexBuffer(2, BufferNDI, INDICATOR_DATA);

   ArraySetAsSeries(BufferADX, false);
   ArraySetAsSeries(BufferPDI, false);
   ArraySetAsSeries(BufferNDI, false);

   ArrayInitialize(BufferADX, EMPTY_VALUE);
   ArrayInitialize(BufferPDI, EMPTY_VALUE);
   ArrayInitialize(BufferNDI, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorADX);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleADX);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthADX);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorPDI);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStylePDI);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthPDI);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorNDI);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleNDI);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthNDI);

// Configure Horizontal Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelTrend);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelExtreme);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   int draw_begin = InpPeriodADX * 2 - 1;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpPeriodADX);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpPeriodADX);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core ADX Calculator
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CADXCalculator_HA();
   else
      g_calculator = new CADXCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodADX))
     {
      Print("Critical Error: Failed to create or initialize ADX Calculator object.");
      return INIT_FAILED;
     }

   string ha_tag    = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str    = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("ADX Pro%s%s(%d)", ha_tag, tf_str, InpPeriodADX);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

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
   int required_bars = InpPeriodADX * 2 + 10;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
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
                             BufferADX, BufferPDI, BufferNDI);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
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
      ArrayResize(h_time,      g_htf_count);
      ArrayResize(h_open,      g_htf_count);
      ArrayResize(h_high,      g_htf_count);
      ArrayResize(h_low,       g_htf_count);
      ArrayResize(h_close,     g_htf_count);
      ArrayResize(h_res_adx,   g_htf_count);
      ArrayResize(h_res_pdi,   g_htf_count);
      ArrayResize(h_res_ndi,   g_htf_count);

      ArraySetAsSeries(h_time,      false);
      ArraySetAsSeries(h_open,      false);
      ArraySetAsSeries(h_high,      false);
      ArraySetAsSeries(h_low,       false);
      ArraySetAsSeries(h_close,     false);
      ArraySetAsSeries(h_res_adx,   false);
      ArraySetAsSeries(h_res_pdi,   false);
      ArraySetAsSeries(h_res_ndi,   false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Compute HTF ADX Values
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close,
                             h_res_adx, h_res_pdi, h_res_ndi);
      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

// 5. Stateful live-bar update for active forming HTF candle
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Mock update on live HTF bar
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close,
                                h_res_adx, h_res_pdi, h_res_ndi);
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

// 7. Chronological Mapping Loop to Chart Timeframe (3 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferADX[i] = h_res_adx[idx_htf];
            BufferPDI[i] = h_res_pdi[idx_htf];
            BufferNDI[i] = h_res_ndi[idx_htf];
           }
         else
           {
            BufferADX[i] = EMPTY_VALUE;
            BufferPDI[i] = EMPTY_VALUE;
            BufferNDI[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferADX[i] = EMPTY_VALUE;
         BufferPDI[i] = EMPTY_VALUE;
         BufferNDI[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpPeriodADX * 2 + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
