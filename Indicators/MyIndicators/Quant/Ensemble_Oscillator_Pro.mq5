//+------------------------------------------------------------------+
//|                                    Ensemble_Oscillator_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.20" // Fixed: Invariant 2-Buffer Plot Allocation for Signal Line Integrity
#property description "Ensemble Consensus Oscillator with Line/Histogram views, Signal MA, MTF, and Universal Pricing."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_minimum -100.0
#property indicator_maximum  100.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Consensus (DRAW_COLOR_HISTOGRAM or DRAW_COLOR_LINE)
#property indicator_label1  "Consensus"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal MA Line
#property indicator_label2  "Signal MA"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Included Engines & Core Tools ---
#include <MyIncludes\Ensemble_Voting_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Display Mode Enum for Visual Representation
enum ENUM_ENSEMBLE_PLOT_MODE
  {
   PLOT_MODE_HISTOGRAM,      // Multi-Color Histogram
   PLOT_MODE_LINE            // Single-Color Line
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe             = PERIOD_CURRENT;       // Calculation Timeframe (Current or HTF)

input group "=== Universal Price Source ==="
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice           = PRICE_CLOSE_STD;      // Global Price Source (Standard / HA)

input group "=== Consensus Core & Visual Mode ==="
input ENUM_ENSEMBLE_PLOT_MODE   InpPlotMode              = PLOT_MODE_HISTOGRAM;  // Visual Mode (Histogram vs Line)
input color                     InpColorConsensusLine    = clrDodgerBlue;        // Line Mode: Consensus Line Color
input ENUM_LINE_STYLE           InpStyleConsensusLine    = STYLE_SOLID;          // Line Mode: Consensus Line Style
input int                       InpWidthConsensusLine    = 2;                    // Line Mode: Consensus Line Width
input color                     InpColorHistBull         = clrMediumSeaGreen;    // Histogram: Bullish Color (>0)
input color                     InpColorHistBear         = clrCrimson;           // Histogram: Bearish Color (<0)
input color                     InpColorHistNeutral      = clrDarkGray;          // Histogram: Neutral Color (=0)
input int                       InpWidthHist             = 2;                    // Histogram: Bar Width
input int                       InpSignalThreshold       = 20;                   // Buy / Sell Threshold Level
input int                       InpStrongThreshold       = 60;                   // Strong Consensus Threshold Level
input int                       InpConsensusSmoothing    = 3;                    // Consensus Smoothing (EMA Length)
input double                    InpNeutralZone           = 5.0;                  // Neutral Zone (Half-Width around 50)

input group "=== Signal Line Settings & Visuals ==="
input bool                      InpShowSignalLine        = true;                 // Enable Signal Line
input int                       InpSignalPeriod          = 9;                    // Signal MA Period
input ENUM_MA_TYPE              InpSignalMAType          = EMA;                  // Signal MA Algorithm (14 Pluggable Models)
input color                     InpColorSignalLine       = clrOrangeRed;         // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignalLine       = STYLE_DOT;            // Signal Line Style
input int                       InpWidthSignalLine       = 1;                    // Signal Line Width

input group "=== 1. Trend Components ==="
input bool                      InpMaCrossEnable         = true;                 // EMA Cross Voter
input double                    InpMaCrossWeight         = 1.0;                  // EMA Cross Weight
input int                       InpMaCrossFast           = 20;                   // Fast EMA Length
input int                       InpMaCrossSlow           = 50;                   // Slow EMA Length
input bool                      InpPriceMaEnable         = true;                 // Price vs SMA Voter
input double                    InpPriceMaWeight         = 1.0;                  // Price vs SMA Weight
input int                       InpPriceMaLength         = 200;                  // Trend SMA Length (Macro Baseline)

input group "=== 2. Momentum Components ==="
input bool                      InpRsiEnable             = true;                 // RSI Voter
input double                    InpRsiWeight             = 1.0;                  // RSI Weight
input int                       InpRsiLength             = 14;                   // RSI Lookback Length
input bool                      InpMacdEnable            = true;                 // MACD Voter
input double                    InpMacdWeight            = 1.0;                  // MACD Weight
input int                       InpMacdFast              = 12;                   // MACD Fast EMA
input int                       InpMacdSlow              = 26;                   // MACD Slow EMA
input int                       InpMacdSignal            = 9;                    // MACD Signal EMA
input bool                      InpStochEnable           = true;                 // Fast Stochastic %K Voter
input double                    InpStochWeight           = 1.0;                  // Fast Stochastic %K Weight
input int                       InpStochLength           = 14;                   // Fast %K Lookback Length
input int                       InpStochSmooth           = 3;                    // %D Smoothing Length

input group "=== 3. Channel & Volatility Components ==="
input bool                      InpBbEnable              = true;                 // Bollinger %B Voter
input double                    InpBbWeight              = 1.0;                  // Bollinger %B Weight
input int                       InpBbLength              = 20;                   // Bollinger Bands Length
input double                    InpBbMult                = 2.0;                  // Bollinger Bands Deviation Multiplier
input bool                      InpDonchianEnable        = true;                 // Donchian Position Voter
input double                    InpDonchianWeight        = 1.0;                  // Donchian Position Weight
input int                       InpDonchianLength        = 20;                   // Donchian Channel Lookback

input group "=== 4. Volume Components ==="
input bool                      InpObvEnable             = true;                 // OBV Trend Voter
input double                    InpObvWeight             = 1.0;                  // OBV Trend Weight
input int                       InpObvLength             = 20;                   // OBV Signal EMA Length
input bool                      InpMfiEnable             = true;                 // MFI Voter
input double                    InpMfiWeight             = 1.0;                  // MFI Weight
input int                       InpMfiLength             = 14;                   // MFI Lookback Length

//--- Indicator Output Buffers ---
double BufferConsensus[];
double BufferColors[];
double BufferSignalLine[];

//--- Internal HTF Data Caches (Chronological Arrays) ---
double   h_open[], h_high[], h_low[], h_close[];
double   h_vol[];
double   h_res_consensus[], h_res_signal[], h_res_raw[], h_res_agreement[];
datetime h_time[];

//--- Global Objects & State Management ---
CEnsembleVotingCalculator *g_calculator     = NULL;
bool                      g_is_mtf_mode     = false;
ENUM_TIMEFRAMES           g_calc_timeframe;
bool                      g_data_ready      = false;
bool                      g_data_synced     = false;
int                       g_htf_count       = 0;
datetime                  g_last_htf_time   = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

// 1. Timeframe Resolution & Direction Guard
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

// 2. Bind Output Buffers
// Plot 0 consumes Buffer 0 (Data) and Buffer 1 (Colors) in BOTH modes!
// Plot 1 consumes Buffer 2 (Signal Line) in BOTH modes!
   SetIndexBuffer(0, BufferConsensus,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors,     INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignalLine, INDICATOR_DATA);

   ArraySetAsSeries(BufferConsensus,  false);
   ArraySetAsSeries(BufferColors,     false);
   ArraySetAsSeries(BufferSignalLine, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling & Invariant 2-Buffer Plot Switching
   if(InpPlotMode == PLOT_MODE_HISTOGRAM)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorHistBull);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorHistBear);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorHistNeutral);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthHist);

      // Omit the 0.0 line in histogram mode
      IndicatorSetInteger(INDICATOR_LEVELS, 4);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, (double)InpStrongThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -(double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -(double)InpStrongThreshold);
     }
   else // PLOT_MODE_LINE (Uses DRAW_COLOR_LINE to preserve the 2-buffer mapping!)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthConsensusLine);

      // Include the 0.0 midline in line mode
      IndicatorSetInteger(INDICATOR_LEVELS, 5);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, (double)InpStrongThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 0.0);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -(double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, -(double)InpStrongThreshold);
     }

// Plot 1: Signal Line (Always mapped to Buffer 2!)
   if(InpShowSignalLine)
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorSignalLine);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleSignalLine);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthSignalLine);
     }
   else
     {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 30);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 30);
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

// 4. Initialize Core Calculator Engine
   g_calculator = new CEnsembleVotingCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpNeutralZone, InpConsensusSmoothing,
                         InpSignalPeriod, InpSignalMAType, InpSourcePrice,
                         InpMaCrossEnable, InpMaCrossWeight, InpMaCrossFast, InpMaCrossSlow,
                         InpPriceMaEnable, InpPriceMaWeight, InpPriceMaLength,
                         InpRsiEnable, InpRsiWeight, InpRsiLength,
                         InpMacdEnable, InpMacdWeight, InpMacdFast, InpMacdSlow, InpMacdSignal,
                         InpStochEnable, InpStochWeight, InpStochLength, InpStochSmooth,
                         InpBbEnable, InpBbWeight, InpBbLength, InpBbMult,
                         InpDonchianEnable, InpDonchianWeight, InpDonchianLength,
                         InpObvEnable, InpObvWeight, InpObvLength,
                         InpMfiEnable, InpMfiWeight, InpMfiLength))
     {
      Print("Critical Error: Failed to initialize Ensemble Voting Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("Ensemble Osc%s%s(%d,%s %d)", ha_tag, tf_str, InpConsensusSmoothing, EnumToString(InpSignalMAType), InpSignalPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, (InpPlotMode == PLOT_MODE_HISTOGRAM) ? "Consensus Bar" : "Consensus Line");
   PlotIndexSetString(1, PLOT_LABEL, StringFormat("Signal Line(%d)", InpSignalPeriod));

// 5. Background MTF Sync Daemon
   if(g_is_mtf_mode)
      EventSetTimer(1);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_is_mtf_mode)
      EventKillTimer();

   if(CheckPointer(g_calculator) != POINTER_INVALID && g_calculator != NULL)
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
   int required_bars = 210;
   if(rates_total < required_bars || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

// Enforce chronological indexing (0 = oldest bar)
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

   double raw_score[], agreement[];
   ArrayResize(raw_score, rates_total, 2048);
   ArrayResize(agreement, rates_total, 2048);
   ArraySetAsSeries(raw_score, false);
   ArraySetAsSeries(agreement, false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      long volume_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(volume_limit > 0)
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, volume,
                                BufferConsensus, BufferSignalLine, raw_score, agreement);
      else
         g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, tick_volume,
                                BufferConsensus, BufferSignalLine, raw_score, agreement);

      int loop_start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = loop_start; i < rates_total; i++)
        {
         double c_val = BufferConsensus[i];
         // Color index: 0 = Bull, 1 = Bear, 2 = Neutral
         BufferColors[i] = (c_val > 0.0) ? 0 : (c_val < 0.0 ? 1 : 2);
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = 220;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform atomic full history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars_mtf)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Resize all HTF caching arrays with capacity reservation
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,          g_htf_count, 2048);
         ArrayResize(h_open,          g_htf_count, 2048);
         ArrayResize(h_high,          g_htf_count, 2048);
         ArrayResize(h_low,           g_htf_count, 2048);
         ArrayResize(h_close,         g_htf_count, 2048);
         ArrayResize(h_vol,           g_htf_count, 2048);
         ArrayResize(h_res_consensus, g_htf_count, 2048);
         ArrayResize(h_res_signal,    g_htf_count, 2048);
         ArrayResize(h_res_raw,       g_htf_count, 2048);
         ArrayResize(h_res_agreement, g_htf_count, 2048);

         ArraySetAsSeries(h_time,          false);
         ArraySetAsSeries(h_open,          false);
         ArraySetAsSeries(h_high,          false);
         ArraySetAsSeries(h_low,           false);
         ArraySetAsSeries(h_close,         false);
         ArraySetAsSeries(h_vol,           false);
         ArraySetAsSeries(h_res_consensus, false);
         ArraySetAsSeries(h_res_signal,    false);
         ArraySetAsSeries(h_res_raw,       false);
         ArraySetAsSeries(h_res_agreement, false);
        }

      // Single Atomic Bulk Rates Copy
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

      // Compute HTF Ensemble Consensus and Signal Line on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_consensus, h_res_signal, h_res_raw, h_res_agreement);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufferConsensus[i]  = EMPTY_VALUE;
            BufferSignalLine[i] = EMPTY_VALUE;
            BufferColors[i]     = 2;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         double c_val = h_res_consensus[htf_ptr];
         BufferConsensus[i]  = c_val;
         BufferSignalLine[i] = h_res_signal[htf_ptr];
         BufferColors[i]     = (c_val > 0.0) ? 0 : (c_val < 0.0 ? 1 : 2);
        }

      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: Update forming candle strictly in RAM
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars_mtf)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_vol[live_idx] = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? (double)htf_rate[0].real_volume : (double)htf_rate[0].tick_volume;

         g_calculator.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_vol,
                                h_res_consensus, h_res_signal, h_res_raw, h_res_agreement);
        }
     }

// Binary Search for forming bar block start (Zero iBarShift API calls!)
   int first_bar_of_forming_htf = ArrayBsearch(time, htf_time_current);
   if(first_bar_of_forming_htf < 0)
      first_bar_of_forming_htf = 0;
   if(time[first_bar_of_forming_htf] < htf_time_current && first_bar_of_forming_htf < rates_total - 1)
      first_bar_of_forming_htf++;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

   double val_cons = h_res_consensus[live_idx];
   double val_sig  = h_res_signal[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufferConsensus[i]  = val_cons;
      BufferSignalLine[i] = val_sig;
      BufferColors[i]     = (val_cons > 0.0) ? 0 : (val_cons < 0.0 ? 1 : 2);
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = 220;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
