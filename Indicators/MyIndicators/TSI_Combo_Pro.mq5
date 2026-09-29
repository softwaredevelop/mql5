//+------------------------------------------------------------------+
//|                                                TSI_Combo_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.20" // Enterprise Refactor: Zero-Lag MTF Fast-Path & Atomic Multi-Stream Pipeline
#property description "William Blau's True Strength Index (TSI) - Combined Tri-Plot Suite with VWMA Support."
#property description "Displays Main TSI Line, Signal Line, and Oscillator Difference with Native & MTF support."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Histogram (Oscillator Difference)
#property indicator_label1  "Oscillator"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrSilver
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: TSI Line (Main Double-Smoothed Momentum)
#property indicator_label2  "TSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal Line
#property indicator_label3  "Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Included Engines & Core Tools
#include <MyIncludes\TSI_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- TSI Core Settings ---"
input int                       InpSlowPeriod     = 25;                // Slow Momentum Period (First Smoothing)
input ENUM_MA_TYPE              InpSlowMAType     = EMA;               // Slow Smoothing MA Type (Supports VWMA)
input int                       InpFastPeriod     = 13;                // Fast Momentum Period (Second Smoothing)
input ENUM_MA_TYPE              InpFastMAType     = EMA;               // Fast Smoothing MA Type (Supports VWMA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "--- Signal Line Settings ---"
input int                       InpSignalPeriod   = 13;                // Signal Line Period
input ENUM_MA_TYPE              InpSignalMAType   = EMA;               // Signal Line MA Type (Supports VWMA)

input group "--- Indicator Levels ---"
input double                    InpLevelWallHigh  = 50.0;              // Extreme Climax Overbought (+50)
input double                    InpLevelExtrHigh  = 37.5;              // Strong Trend Overbought (+37.5)
input double                    InpLevelOverbought= 25.0;              // Overbought Warning (+25)
input double                    InpLevelOversold  =-25.0;              // Oversold Warning (-25)
input double                    InpLevelExtrLow   =-37.5;              // Strong Trend Oversold (-37.5)
input double                    InpLevelWallLow   =-50.0;              // Extreme Climax Oversold (-50)
input color                     InpLevelColor     = clrSilver;         // Level Lines Color
input ENUM_LINE_STYLE           InpLevelStyle     = STYLE_DOT;         // Level Lines Style

input group "--- Visual Settings - TSI Line ---"
input color                     InpColorTSI       = clrDodgerBlue;     // TSI Line Color
input ENUM_LINE_STYLE           InpStyleTSI       = STYLE_SOLID;       // TSI Line Style
input int                       InpWidthTSI       = 2;                 // TSI Line Width

input group "--- Visual Settings - Signal Line ---"
input color                     InpColorSignal    = clrOrangeRed;      // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignal    = STYLE_SOLID;       // Signal Line Style
input int                       InpWidthSignal    = 1;                 // Signal Line Width

input group "--- Visual Settings - Histogram ---"
input color                     InpColorOsc       = clrSilver;         // Histogram Color
input ENUM_LINE_STYLE           InpStyleOsc       = STYLE_SOLID;       // Histogram Style
input int                       InpWidthOsc       = 1;                 // Histogram Width

//--- Indicator Buffers ---
double    BufferOsc[];
double    BufferTSI[];
double    BufferSignal[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_vol[];
double    h_res_tsi[], h_res_signal[], h_res_osc[];
datetime  h_time[];

//--- Global Objects & State Management
CTSICalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

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
   SetIndexBuffer(0, BufferOsc,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferTSI,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferOsc,    false);
   ArraySetAsSeries(BufferTSI,    false);
   ArraySetAsSeries(BufferSignal, false);

   ArrayInitialize(BufferOsc,    0.0);
   ArrayInitialize(BufferTSI,    EMPTY_VALUE);
   ArrayInitialize(BufferSignal, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorOsc);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleOsc);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthOsc);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorTSI);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleTSI);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthTSI);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorSignal);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpStyleSignal);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpWidthSignal);

// Configure Horizontal Levels
   IndicatorSetInteger(INDICATOR_LEVELS, 6);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelWallLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelExtrLow);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpLevelOversold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpLevelOverbought);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, InpLevelExtrHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 5, InpLevelWallHigh);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, InpLevelStyle);

   int warmup = InpSlowPeriod + InpFastPeriod + InpSignalPeriod;
   int draw_begin = warmup;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CTSICalculator_HA();
   else
      g_calculator = new CTSICalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpSlowPeriod, InpSlowMAType, InpFastPeriod, InpFastMAType, InpSignalPeriod, InpSignalMAType, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize TSI Calculator.");
      return INIT_FAILED;
     }

   string ha_tag     = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str     = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("TSI Combo%s%s(%d,%d,%d)",
                                    ha_tag, tf_str,
                                    InpSlowPeriod, InpFastPeriod, InpSignalPeriod);
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
   int warmup = InpSlowPeriod + InpFastPeriod + InpSignalPeriod;
   if(rates_total < warmup || !g_calculator)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume,
                                BufferTSI, BufferSignal, BufferOsc);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume,
                                BufferTSI, BufferSignal, BufferOsc);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
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

// A) HTF Bar Closure / Startup: Perform full history sync once
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
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_vol,        g_htf_count);
      ArrayResize(h_res_tsi,    g_htf_count);
      ArrayResize(h_res_signal, g_htf_count);
      ArrayResize(h_res_osc,    g_htf_count);

      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_vol,        false);
      ArraySetAsSeries(h_res_tsi,    false);
      ArraySetAsSeries(h_res_signal, false);
      ArraySetAsSeries(h_res_osc,    false);

      // Atomic bulk rates copy (Single API call replaces 6 calls!)
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
         h_vol[i]   = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? (double)htf_bulk_rates[i].real_volume : (double)htf_bulk_rates[i].tick_volume;
        }

      // Compute HTF TSI Values across history
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_tsi, h_res_signal, h_res_osc);
      g_data_ready = true;

      // Full Historical Projection to Chart Buffers (Only on new HTF candle)
      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);
         if(shift_htf >= 0)
           {
            int idx_htf = g_htf_count - 1 - shift_htf;
            if(idx_htf >= 0 && idx_htf < g_htf_count)
              {
               BufferOsc[i]    = h_res_osc[idx_htf];
               BufferTSI[i]    = h_res_tsi[idx_htf];
               BufferSignal[i] = h_res_signal[idx_htf];
              }
            else
              {
               BufferOsc[i] = 0.0;
               BufferTSI[i] = EMPTY_VALUE;
               BufferSignal[i] = EMPTY_VALUE;
              }
           }
         else
           {
            BufferOsc[i] = 0.0;
            BufferTSI[i] = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
           }
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update strictly forming block!
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      MqlRates htf_rate[1];
      // Single atomic API call instead of 6 separate copies!
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_vol[live_idx] = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (double)htf_rate[0].real_volume : (double)htf_rate[0].tick_volume;

         // Mock update strictly on forming candle
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol,
                                h_res_tsi, h_res_signal, h_res_osc);
        }
     }

// Instant Binary Search for Forming Block Start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

// Direct Vectorized Assignment (Zero API calls, Nanosecond Execution across 3 buffers)
   double osc_val = h_res_osc[live_idx];
   double tsi_val = h_res_tsi[live_idx];
   double sig_val = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferOsc[i]    = osc_val;
      BufferTSI[i]    = tsi_val;
      BufferSignal[i] = sig_val;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int warmup = InpSlowPeriod + InpFastPeriod + InpSignalPeriod;
   int required_bars = warmup + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
