//+------------------------------------------------------------------+
//|                                                  ZScore_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.01" // Fixed buffer variable naming mismatch in mapping loop
#property description "Statistical Z-Score Oscillator (Multi-Timeframe) with dynamic Signal Line."
#property description "Displays HTF deviations from any selected Moving Average in Sigma units cleanly."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

//--- Institutional Levels Configuration (6 Sigma boundaries)
#property indicator_level1 2.0
#property indicator_level2 -2.0
#property indicator_level3 2.5
#property indicator_level4 -2.5
#property indicator_level5 3.0
#property indicator_level6 -3.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Z-Score Histogram (Swapped Bull/Bear Thermal Palette)
#property indicator_label1  "Z-Score MTF"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
// Swapped Palette:
// 0: Noise/Neutral     (Gray)
// 1: Bullish Flow      (LightSkyBlue)
// 2: Bullish Climax    (DeepSkyBlue)
// 3: Bearish Flow      (Coral)
// 4: Bearish Climax    (OrangeRed)
#property indicator_color1  clrGray, clrLightSkyBlue, clrDeepSkyBlue, clrCoral, clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Optional Signal Line (Wyckoff Reversal Trigger)
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrFireBrick
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\ZScore_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpTimeframe   = PERIOD_H1;       // Target Higher Timeframe
input int                       InpPeriod      = 20;              // Z-Score Lookback Period
input ENUM_MA_TYPE              InpMAType      = SMA;             // Z-Score MA Type
input ENUM_APPLIED_PRICE        InpPrice       = PRICE_CLOSE;     // Z-Score Applied Price

//--- Signal Line Parameters
input bool                      InpShowSignal  = true;            // Show Signal Line?
input int                       InpSignalPeriod= 5;               // Signal Line Period
input ENUM_MA_TYPE              InpSignalType  = SMA;             // Signal Line MA Type

//--- Buffers ---
double BufferZ[];
double BufferColors[];
double BufferSignal[];

//--- Internal HTF Data Caches
double h_res[], h_sig[]; // HTF Results cached
datetime h_time[];
double h_open[], h_high[], h_low[], h_close[];
long   h_vol[]; // HTF raw volume cache
double h_vol_double[]; // HTF volume cast to double to support VWMA Signal line

//--- Global HTF State Tracking
CZScoreCalculator        *g_calculator;
CMovingAverageCalculator *g_signal_calculator;
datetime                 g_last_htf_time     = 0;
int                      g_htf_count         = 0;
bool                     g_data_ready        = false;
bool                     g_data_synced       = false;

//+------------------------------------------------------------------+
//| EnsureHTFDataReady                                               |
//+------------------------------------------------------------------+
bool EnsureHTFDataReady(const string symbol, const ENUM_TIMEFRAMES timeframe, const int required_bars)
  {
   ResetLastError();
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      SymbolSelect(symbol, true);
     }
   datetime times[];
   int copied = CopyTime(symbol, timeframe, 0, required_bars, times);
   return (copied >= required_bars);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready = false;
   g_data_synced = false;
   g_last_htf_time = 0;
   g_htf_count = 0;

   if(InpTimeframe <= Period() && InpTimeframe != PERIOD_CURRENT)
     {
      Print("Warning: Target Timeframe should be > Current Timeframe.");
     }

//--- Bind Buffers
   SetIndexBuffer(0, BufferZ,      INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignal, INDICATOR_DATA);

   ArraySetAsSeries(BufferZ,      false);
   ArraySetAsSeries(BufferColors, false);
   ArraySetAsSeries(BufferSignal, false);

//--- Configure Core Z-Score Calculator
   g_calculator = new CZScoreCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Error: Failed to initialize ZScore Calculator Engine.");
      return INIT_FAILED;
     }

//--- Configure Optional Signal Line Calculator
   if(InpShowSignal)
     {
      // Explicitly restore DRAW_LINE & Label in case it was previously disabled
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetString(1, PLOT_LABEL, "Signal");

      g_signal_calculator = new CMovingAverageCalculator();
      if(CheckPointer(g_signal_calculator) == POINTER_INVALID || !g_signal_calculator.Init(InpSignalPeriod, InpSignalType))
        {
         Print("Error: Failed to initialize Signal Line Calculator Engine.");
         return INIT_FAILED;
        }
     }
   else
     {
      // Set DRAW_NONE and clear Label to fully purge it from the MT5 Data Window
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetString(1, PLOT_LABEL, NULL);
     }

//--- Dynamically set the indicator short name
   string tf_name = StringSubstr(EnumToString(InpTimeframe), 7);
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);

   string short_name = "";
   if(InpShowSignal)
     {
      string sig_name = EnumToString(InpSignalType);
      StringToUpper(sig_name);
      short_name = StringFormat("ZScore MTF %s(%d, %s) %s(%d)", tf_name, InpPeriod, ma_name, sig_name, InpSignalPeriod);
     }
   else
     {
      short_name = StringFormat("ZScore MTF %s(%d, %s)", tf_name, InpPeriod, ma_name);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, "Z-Score MTF");
   PlotIndexSetString(1, PLOT_LABEL, "Signal MTF");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

//--- Initialize 1-second timer for weekend/async chart refreshes
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
   if(CheckPointer(g_signal_calculator) != POINTER_INVALID)
      delete g_signal_calculator;
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
//--- Ensure target timeframe history is ready
   int required_bars = InpPeriod + 10;
   if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history load
     }

   g_data_synced = true;

//--- Determine best volume array (Use Real Volume if available, otherwise fallback to Tick Volume)
   long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

//--- 1. Check if a new HTF bar has formed
   datetime htf_time_current = iTime(_Symbol, InpTimeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, InpTimeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_vol,        g_htf_count);
      ArrayResize(h_vol_double, g_htf_count);

      ArrayResize(h_res,        g_htf_count);
      ArrayResize(h_sig,        g_htf_count);

      if(CopyTime(_Symbol,  InpTimeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  InpTimeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  InpTimeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   InpTimeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, InpTimeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // High-Performance dynamic volume routing on the HTF Timeline
      int copied_vol = 0;
      if(volume_limit > 0)
         copied_vol = CopyRealVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol);
      else
         copied_vol = CopyTickVolume(_Symbol, InpTimeframe, 0, g_htf_count, h_vol);

      if(copied_vol != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Convert HTF volume cache to double precision
      for(int j = 0; j < g_htf_count; j++)
         h_vol_double[j] = (double)h_vol[j];

      // Calculate Core Z-Score on HTF (Closed bars and forming bar initialized)
      if(volume_limit > 0)
         g_calculator.Calculate(g_htf_count, 0, InpPrice, h_open, h_high, h_low, h_close, h_vol, h_res);
      else
         g_calculator.Calculate(g_htf_count, 0, InpPrice, h_open, h_high, h_low, h_close, h_vol, h_res);

      // Calculate Optional Signal Line on HTF
      if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
        {
         g_signal_calculator.CalculateOnArray(g_htf_count, 0, h_res, h_vol_double, h_sig, InpPeriod - 1);
        }

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 2. Live Update for the Current Forming HTF Bar (Index: g_htf_count - 1) on every tick!
   int live_idx = g_htf_count - 1;
   if(live_idx >= InpPeriod)
     {
      double o[1], h[1], l[1], c[1];
      long vol[1];
      int shift = iBarShift(_Symbol, InpTimeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  InpTimeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  InpTimeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   InpTimeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, InpTimeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         // Copy live volume dynamically
         int copied = 0;
         if(volume_limit > 0)
            copied = CopyRealVolume(_Symbol, InpTimeframe, shift, 1, vol);
         else
            copied = CopyTickVolume(_Symbol, InpTimeframe, shift, 1, vol);

         if(copied == 1)
           {
            h_vol[live_idx] = vol[0];
            h_vol_double[live_idx] = (double)vol[0];
           }

         // Incremental recalculation on the live HTF index in O(1)
         if(volume_limit > 0)
            g_calculator.Calculate(g_htf_count, g_htf_count, InpPrice, h_open, h_high, h_low, h_close, h_vol, h_res);
         else
            g_calculator.Calculate(g_htf_count, g_htf_count, InpPrice, h_open, h_high, h_low, h_close, h_vol, h_res);

         // Recalculate Signal Line on HTF live index
         if(InpShowSignal && CheckPointer(g_signal_calculator) != POINTER_INVALID)
           {
            g_signal_calculator.CalculateOnArray(g_htf_count, g_htf_count, h_res, h_vol_double, h_sig, InpPeriod - 1);
           }
        }
     }

//--- 3. FIXED: Dynamically adjust 'start' to the beginning of the current forming HTF bar
//--- This forces the entire forming LTF step block to remain perfectly flat, updating on every tick!
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
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
      int shift_htf = iBarShift(_Symbol, InpTimeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            double z = h_res[idx_htf];

            BufferZ[i] = z; // FIXED: Corrected buffer array name

            if(InpShowSignal)
               BufferSignal[i] = h_sig[idx_htf]; // FIXED: Corrected buffer array name
            else
               BufferSignal[i] = EMPTY_VALUE; // FIXED: Corrected buffer array name

            // Swapped 5-Zone Color Logic (Blue for Bullish, Red/Coral for Bearish)
            if(z >= 2.5)
               BufferColors[i] = 2.0; // FIXED: Corrected buffer array name (Index 2: DeepSkyBlue Climax)
            else
               if(z >= 2.0)
                  BufferColors[i] = 1.0; // FIXED: Corrected buffer array name (Index 1: LightSkyBlue Flow)
               else
                  if(z <= -2.5)
                     BufferColors[i] = 4.0; // FIXED: Corrected buffer array name (Index 4: OrangeRed Climax)
                  else
                     if(z <= -2.0)
                        BufferColors[i] = 3.0; // FIXED: Corrected buffer array name (Index 3: Coral Flow)
                     else
                        BufferColors[i] = 0.0; // FIXED: Corrected buffer array name (Index 0: Gray Neutral)
           }
         else
           {
            BufferZ[i]      = EMPTY_VALUE; // FIXED: Corrected buffer array name
            BufferSignal[i] = EMPTY_VALUE; // FIXED: Corrected buffer array name
            BufferColors[i] = 0.0; // FIXED: Corrected buffer array name
           }
        }
      else
        {
         BufferZ[i]      = EMPTY_VALUE; // FIXED: Corrected buffer array name
         BufferSignal[i] = EMPTY_VALUE; // FIXED: Corrected buffer array name
         BufferColors[i] = 0.0; // FIXED: Corrected buffer array name
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
   if(!g_data_synced)
     {
      int required_bars = InpPeriod + 5;
      if(EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars))
        {
         g_data_synced = true;
         ChartRedraw(); // Force MT5 to invoke OnCalculate
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
