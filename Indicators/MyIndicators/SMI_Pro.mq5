//+------------------------------------------------------------------+
//|                                                       SMI_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.20" // Upgraded with selectable MA smoothing types (including VWMA support)
#property description "Professional Stochastic Momentum Index (SMI) with dynamic MTF and MA selections."

//--- Indicator Window and Level Properties ---
#property indicator_separate_window
#property indicator_buffers 2 // SMI and Signal Line
#property indicator_plots   2
#property indicator_level1  80.0
#property indicator_level2  60.0
#property indicator_level3  40.0
#property indicator_level4  0.0
#property indicator_level5 -40.0
#property indicator_level6 -60.0
#property indicator_level7 -80.0
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum -100.0
#property indicator_maximum 100.0

//--- Plot 1: SMI line
#property indicator_label1  "SMI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSteelBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Signal line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Include the calculator engine ---
#include <MyIncludes\SMI_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh> // Centralized MTF synchronization daemon

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;       // Target Higher Timeframe

input group "--- SMI Settings ---"
input int                InpLengthK      = 10; // %K Length
input int                InpLengthD      = 3;  // %D Length (for double smoothing)
input ENUM_MA_TYPE       InpSlowingType  = EMA; // Double Smoothing MA Type
input int                InpLengthEMA    = 3;  // EMA Length (for signal line)
input ENUM_MA_TYPE       InpSignalType   = EMA; // Signal Line MA Type
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD;

//--- Indicator Buffers ---
double    BufferSMI[];
double    BufferSignal[];

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[], h_volume[];
double    h_res_smi[], h_res_sig[];
datetime  h_time[];

//--- Global Objects & Synchronizer State
CSMICalculator *g_calculator;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Map the buffers and set as non-timeseries
   SetIndexBuffer(0, BufferSMI,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   ArraySetAsSeries(BufferSMI,    false);
   ArraySetAsSeries(BufferSignal, false);

//--- 3. Factory Logic for Heikin Ashi price routing
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CSMICalculator_HA();
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CSMICalculator();
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpLengthK, InpLengthD, InpSlowingType, InpLengthEMA, InpSignalType))
     {
      Print("Critical Error: Failed to create or initialize SMI Calculator object.");
      return(INIT_FAILED);
     }

//--- 4. Dynamic Setup of Indicator Shortname and Plots
   string type = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("SMI%s%s(%d,%d,%d)", type, tf_str, InpLengthK, InpLengthD, InpLengthEMA));

//--- Drawing offset configuration
   int smi_draw_begin = InpLengthK + InpLengthD + InpLengthD - 3;
   int sig_draw_begin = smi_draw_begin + InpLengthEMA - 1;
   if(g_is_mtf_mode)
     {
      smi_draw_begin = 0;
      sig_draw_begin = 0;
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, smi_draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, sig_draw_begin);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- 5. Initialize Background Synchronization Timer Daemon (Only if MTF is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
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
   int required_bars = InpLengthK + InpLengthD + InpLengthD + InpLengthEMA + 10;
   if(rates_total < required_bars)
      return 0;

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

//--- Force chronological indexing on current timeframe arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//===================================================================
// MODE 1: Current Timeframe calculation (Standard ultra-high speed)
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      bool is_vwma = (InpSlowingType == VWMA || InpSignalType == VWMA);

      if(is_vwma)
        {
         if(volume_limit > 0)
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume, BufferSMI, BufferSignal);
         else
            g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume, BufferSMI, BufferSignal);
        }
      else
        {
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferSMI, BufferSignal);
        }

      return(rates_total);
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free step synchronization)
//===================================================================
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history synchronize
     }

   g_data_synced = true;

//--- Check if a new HTF candle has opened
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

      g_htf_count = MathMin(htf_bars, 3000); // Guard rails to prevent memory overload

      // Resize all HTF caching arrays
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_volume,     g_htf_count);
      ArrayResize(h_res_smi,    g_htf_count);
      ArrayResize(h_res_sig,    g_htf_count);

      // Force chronological structure on high-level arrays
      ArraySetAsSeries(h_time,    false);
      ArraySetAsSeries(h_open,    false);
      ArraySetAsSeries(h_high,    false);
      ArraySetAsSeries(h_low,     false);
      ArraySetAsSeries(h_close,   false);
      ArraySetAsSeries(h_volume,  false);
      ArraySetAsSeries(h_res_smi, false);
      ArraySetAsSeries(h_res_sig, false);

      // Copy basic pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Copy proper volume types for VWMA supporting
      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
        {
         long temp_vol[];
         if(CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }
      else
        {
         long temp_vol[];
         if(CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }

      //--- Calculate core indicators directly on high timeframe (Initial setup)
      bool is_vwma = (InpSlowingType == VWMA || InpSignalType == VWMA);
      if(is_vwma)
        {
         long h_vol_long[];
         ArrayResize(h_vol_long, g_htf_count);
         for(int i=0; i<g_htf_count; i++)
            h_vol_long[i] = (long)h_volume[i];
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol_long, h_res_smi, h_res_sig);
        }
      else
        {
         g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_smi, h_res_sig);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 5. Real-Time Update for the active forming HTF candle (Index: g_htf_count - 1) on every tick
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      long v[1];
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

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0)
           {
            if(CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }
         else
           {
            if(CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }

         // Stateful, O(1) mock update for the live HTF bar
         bool is_vwma = (InpSlowingType == VWMA || InpSignalType == VWMA);
         if(is_vwma)
           {
            long h_vol_long[];
            ArrayResize(h_vol_long, g_htf_count);
            for(int i=0; i<g_htf_count; i++)
               h_vol_long[i] = (long)h_volume[i];
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol_long, h_res_smi, h_res_sig);
           }
         else
           {
            g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_smi, h_res_sig);
           }
        }
     }

//--- 6. Warp-free step force (Staircase Solution anchor determination)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // Anchor set to start of current HTF period block

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 7. Map HTF Calculated results cleanly to the lower chart timeframe (O(1) complexity)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferSMI[i]    = h_res_smi[idx_htf];
            BufferSignal[i] = h_res_sig[idx_htf];
           }
         else
           {
            BufferSMI[i]    = EMPTY_VALUE;
            BufferSignal[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferSMI[i]    = EMPTY_VALUE;
         BufferSignal[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Delegate asynchronous history checking and forced redraws to DataSync daemon using correct lookback period
   int required_bars = InpLengthK + InpLengthD + InpLengthD + InpLengthEMA + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
