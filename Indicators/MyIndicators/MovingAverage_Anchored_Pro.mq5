//+------------------------------------------------------------------+
//|                                  MovingAverage_Anchored_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Unified Native & MTF Release with Enhanced Custom Session Handling
#property description "Universal Anchored Moving Average (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA)."
#property description "Resets its calculation baseline on specific calendar events with Native & MTF support."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MA Line (Odd Periods)
#property indicator_label1  "MA Anchored"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: MA Line (Even Periods)
#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Included Engines & Core Tools
#include <MyIncludes\MovingAverage_Anchored_Engine.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe    = PERIOD_CURRENT;    // Calculation Timeframe (Current or HTF)

input group "--- Moving Average Core Settings ---"
input int                       InpPeriod       = 20;                // Smoothing Period
input ENUM_MA_TYPE              InpMAType       = SMA;               // MA Type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA)
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;   // Price Source (Standard / HA)

input group "--- Anchor Settings ---"
input ENUM_ANCHOR_PERIOD        InpAnchor       = ANCHOR_SESSION;    // Reset Anchor Period
input int                       InpTzShift      = 0;                 // Timezone Shift in hours vs Broker Time
input string                    InpCustomStart  = "09:00";           // Custom Session Start (HH:MM)
input string                    InpCustomEnd    = "18:00";           // Custom Session End (HH:MM)

input group "--- Visual Settings ---"
input color                     InpColorMA      = clrDodgerBlue;     // Line Color
input ENUM_LINE_STYLE           InpStyleMA      = STYLE_SOLID;       // Line Style
input int                       InpWidthMA      = 2;                 // Line Width

//--- Indicator Buffers ---
double    BufferMA_Odd[];
double    BufferMA_Even[];

//--- Internal HTF Data Caches (Chronological Arrays)
double    h_open[], h_high[], h_low[], h_close[];
double    h_vol[];
double    h_res_odd[], h_res_even[];
datetime  h_time[];

//--- Global Objects & State Management
CMovingAverageAnchoredCalculator *g_calculator = NULL;

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
   SetIndexBuffer(0, BufferMA_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferMA_Even, INDICATOR_DATA);

   ArraySetAsSeries(BufferMA_Odd,  false);
   ArraySetAsSeries(BufferMA_Even, false);

   ArrayInitialize(BufferMA_Odd,  EMPTY_VALUE);
   ArrayInitialize(BufferMA_Even, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorMA);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleMA);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthMA);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorMA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleMA);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthMA);
   PlotIndexSetString(1,  PLOT_LABEL, "MA Anchored (Segment)");

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageAnchoredCalculator_HA();
   else
      g_calculator = new CMovingAverageAnchoredCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpPeriod, InpMAType, InpAnchor, InpCustomStart, InpCustomEnd, InpTzShift, InpSourcePrice))
     {
      Print("Critical Error: Failed to initialize Moving Average Anchored Calculator.");
      return INIT_FAILED;
     }

   string ma_name     = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string anchor_name = EnumToString(InpAnchor);
   string ha_tag      = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str      = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";

   string short_name = StringFormat("MA Anch%s%s(%s,%s,%d)",
                                    ha_tag, tf_str,
                                    ma_name, StringSubstr(anchor_name, 7), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);

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
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) :
                                   (ENUM_APPLIED_PRICE)InpSourcePrice;

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, volume, BufferMA_Odd, BufferMA_Even);
      else
         g_calculator.Calculate(rates_total, prev_calculated, price_type, time, open, high, low, close, tick_volume, BufferMA_Odd, BufferMA_Even);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (Warp-free Step Synchronization)
//===================================================================
   int required_bars = 10;
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
      ArrayResize(h_time,     g_htf_count);
      ArrayResize(h_open,     g_htf_count);
      ArrayResize(h_high,     g_htf_count);
      ArrayResize(h_low,      g_htf_count);
      ArrayResize(h_close,    g_htf_count);
      ArrayResize(h_vol,      g_htf_count);
      ArrayResize(h_res_odd,  g_htf_count);
      ArrayResize(h_res_even, g_htf_count);

      ArraySetAsSeries(h_time,     false);
      ArraySetAsSeries(h_open,     false);
      ArraySetAsSeries(h_high,     false);
      ArraySetAsSeries(h_low,      false);
      ArraySetAsSeries(h_close,    false);
      ArraySetAsSeries(h_vol,      false);
      ArraySetAsSeries(h_res_odd,  false);
      ArraySetAsSeries(h_res_even, false);

      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
        {
         long temp_vol[];
         if(CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_vol[i] = (double)temp_vol[i];
           }
        }
      else
        {
         long temp_vol[];
         if(CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_vol[i] = (double)temp_vol[i];
           }
        }

      // Compute HTF Anchored MA Values
      g_calculator.Calculate(g_htf_count, 0, price_type, h_time, h_open, h_high, h_low, h_close, h_vol, h_res_odd, h_res_even);
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
      long v[1];

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

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0 && CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
            h_vol[live_idx] = (double)v[0];
         else
            if(CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_vol[live_idx] = (double)v[0];

         // Mock update on live bar
         g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_time, h_open, h_high, h_low, h_close, h_vol, h_res_odd, h_res_even);
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

// 7. Chronological Mapping Loop to Chart Timeframe (2 Buffers)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufferMA_Odd[i]  = h_res_odd[idx_htf];
            BufferMA_Even[i] = h_res_even[idx_htf];
           }
         else
           {
            BufferMA_Odd[i]  = EMPTY_VALUE;
            BufferMA_Even[i] = EMPTY_VALUE;
           }
        }
      else
        {
         BufferMA_Odd[i]  = EMPTY_VALUE;
         BufferMA_Even[i] = EMPTY_VALUE;
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
