//+------------------------------------------------------------------+
//|                                                  ADX_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.30" // Refactored to utilize centralized CDataSync helper class and clean OnTimerUpdate daemon
#property description "Vertical Welles Wilder ADX & DMI (Multi-Timeframe)."
#property description "Displays HTF ADX, +DI and -DI lines cleanly on current chart without live-bar warping."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Levels (Wilder's Standard Constant Boundaries)
#property indicator_level1 25.0
#property indicator_level2 40.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: ADX line (Main trend strength)
#property indicator_label1  "ADX MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: +DI line (Positive Directional Indicator)
#property indicator_label2  "+DI MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOliveDrab
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: -DI line (Negative Directional Indicator)
#property indicator_label3  "-DI MTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MyIncludes\ADX_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh> // Integrated dynamic central data synchronization tools

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES   InpTimeframe      = PERIOD_H1;       // Target Higher Timeframe

input group "ADX Settings"
input int               InpPeriodADX      = 14;              // Period for ADX calculations
input ENUM_CANDLE_SOURCE InpCandleSource  = CANDLE_STANDARD; // Candle source

//--- Buffers
double    BufferADX_MTF[];
double    BufferPDI_MTF[];
double    BufferNDI_MTF[];

//--- Internal HTF Data Caches
double    h_res_adx[];   // HTF ADX Results cached
double    h_res_pdi[];   // HTF +DI Results cached
double    h_res_ndi[];   // HTF -DI Results cached
datetime  h_time[];      // HTF Time index
double    h_open[], h_high[], h_low[], h_close[]; // HTF Price Data

//--- Global variables ---
CADXCalculator *g_calculator;

bool            g_is_mtf_mode         = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_data_synced = false;
   g_htf_count = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- 2. Setup Buffers
   SetIndexBuffer(0, BufferADX_MTF, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPDI_MTF, INDICATOR_DATA);
   SetIndexBuffer(2, BufferNDI_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferADX_MTF, false);
   ArraySetAsSeries(BufferPDI_MTF, false);
   ArraySetAsSeries(BufferNDI_MTF, false);

//--- 3. Initialize Calculator (Factory Logic)
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CADXCalculator_HA();
         break;
      default: // CANDLE_STANDARD
         g_calculator = new CADXCalculator();
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodADX))
     {
      Print("Failed to create or initialize ADX Calculator object.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADX Pro%s%s(%d)", type, tf_str, InpPeriodADX));

// Draw begin logic
   int draw_begin = InpPeriodADX * 2 - 1;
   if(g_is_mtf_mode)
      draw_begin = 0;

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, draw_begin);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_is_mtf_mode ? 0 : InpPeriodADX);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_is_mtf_mode ? 0 : InpPeriodADX);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- Initialize 1-second timer for weekend/async chart refreshes (Only if MTF mode is active)
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;
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
   if(rates_total < 2)
      return(0);

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return(0);

//--- Force strict chronological indexing for state-safety on input price arrays
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferADX_MTF, BufferPDI_MTF, BufferNDI_MTF);
      return(rates_total);
     }

//================================================================
// MODE 2: Multi-Timeframe (MTF Engine)
//================================================================

//--- Ensure target timeframe history is ready (Polymorphically calling CDataSync helper)
   int required_bars = InpPeriodADX * 2 + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- 1. Check if a new HTF bar has formed
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

      ArrayResize(h_time,  g_htf_count);
      ArrayResize(h_open,  g_htf_count);
      ArrayResize(h_high,  g_htf_count);
      ArrayResize(h_low,   g_htf_count);
      ArrayResize(h_close, g_htf_count);

      ArrayResize(h_res_adx, g_htf_count);
      ArrayResize(h_res_pdi, g_htf_count);
      ArrayResize(h_res_ndi, g_htf_count);

      // Force chronological array alignment on HTF caches after resize
      ArraySetAsSeries(h_time,  false);
      ArraySetAsSeries(h_open,  false);
      ArraySetAsSeries(h_high,  false);
      ArraySetAsSeries(h_low,   false);
      ArraySetAsSeries(h_close, false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      //--- Calculate ADX & DMI on HTF (Closed bars and forming bar initialized)
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_adx, h_res_pdi, h_res_ndi);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriodADX * 2 - 1)
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

         // Incremental recalculation on the live HTF index in O(1)
         // Passed g_htf_count as prev_calculated to preserve state safety (wilder's smoothing)
         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_adx, h_res_pdi, h_res_ndi);
        }
     }

//--- 3. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
//--- This forces the entire forming LTF step block to remain perfectly flat, updating on every tick!
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // This is the start of the forming step on lower TF chart

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 4. Incremental Mapping of HTF results to Current Chart Timeframe (O(1) per tick)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferADX_MTF[i] = h_res_adx[idx_htf];
            BufferPDI_MTF[i] = h_res_pdi[idx_htf];
            BufferNDI_MTF[i] = h_res_ndi[idx_htf];
           }
         else
           {
            BufferADX_MTF[i] = EMPTY_VALUE;
            BufferPDI_MTF[i] = EMPTY_VALUE;
            BufferNDI_MTF[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferADX_MTF[i] = EMPTY_VALUE;
         BufferPDI_MTF[i] = EMPTY_VALUE;
         BufferNDI_MTF[i] = EMPTY_VALUE;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//| Handles loading checks and force-redraws                         |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Centralized high performance OnTimer updates via CDataSync daemon
   int required_bars = InpPeriodADX * 2 + 5;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
