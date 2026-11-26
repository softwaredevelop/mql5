//+------------------------------------------------------------------+
//|                                DSP_Ensemble_Oscillator_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.00" // Enterprise Edition: Zero-Lag 8-Voter Cybernetic DSP Consensus Oscillator
#property description "Cybernetic Zero-Lag Ensemble Consensus Oscillator combining 8 refactored Ehlers & DSP engines."
#property description "Features Line/Histogram views, Threshold-Colored Neutral Zone, Signal Line, and MTF Fast-Path."

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_minimum -100.0
#property indicator_maximum  100.0
#property indicator_levelcolor clrDarkGray
#property indicator_levelstyle STYLE_DOT

//--- Plot 1: Consensus (DRAW_COLOR_HISTOGRAM or DRAW_COLOR_LINE)
#property indicator_label1  "DSP Consensus"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Signal MA Line
#property indicator_label2  "Signal MA"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Included DSP Engine & Core Tools ---
#include <MyIncludes\DSP_Ensemble_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Display Mode Enum for Visual Representation
enum ENUM_DSP_PLOT_MODE
  {
   DSP_PLOT_HISTOGRAM,       // Multi-Color Histogram
   DSP_PLOT_LINE             // Single-Color Line
  };

//--- Input Parameters ---
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe          = PERIOD_CURRENT;     // Calculation Timeframe (Current or HTF)

input group "=== Universal Price Source ==="
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice        = PRICE_CLOSE_STD;    // Global Price Source (Standard / HA)

input group "=== Consensus Core & Visual Mode ==="
input ENUM_DSP_PLOT_MODE        InpPlotMode           = DSP_PLOT_HISTOGRAM; // Visual Mode (Histogram vs Line)
input color                     InpColorConsensusLine = clrDodgerBlue;      // Line Mode: Color
input ENUM_LINE_STYLE           InpStyleConsensusLine = STYLE_SOLID;        // Line Mode: Style
input int                       InpWidthConsensusLine = 2;                  // Line Mode: Width
input color                     InpColorHistBull      = clrMediumSeaGreen;  // Histogram: Bullish Color (> +Threshold)
input color                     InpColorHistBear      = clrCrimson;         // Histogram: Bearish Color (< -Threshold)
input color                     InpColorHistNeutral   = clrDarkGray;        // Histogram: Neutral Zone Color (-Threshold to +Threshold)
input int                       InpWidthHist          = 2;                  // Histogram: Bar Width
input int                       InpSignalThreshold    = 20;                 // Buy / Sell Threshold Level (Neutral Zone Boundary)
input int                       InpStrongThreshold    = 60;                 // Strong Consensus Threshold Level
input int                       InpConsensusSmoothing = 3;                  // Consensus Smoothing (EMA Length)
input double                    InpNeutralZone        = 5.0;                // Bounded Oscillator Neutral Zone (Half-Width around 50)

input group "=== Signal Line Settings & Visuals ==="
input bool                      InpShowSignalLine     = true;               // Enable Signal Line
input int                       InpSignalPeriod       = 9;                  // Signal MA Period
input ENUM_MA_TYPE              InpSignalMAType       = EMA;                // Signal MA Algorithm (14 Pluggable Models)
input color                     InpColorSignalLine    = clrOrangeRed;       // Signal Line Color
input ENUM_LINE_STYLE           InpStyleSignalLine    = STYLE_DOT;          // Signal Line Style
input int                       InpWidthSignalLine    = 1;                  // Signal Line Width

input group "=== 1. Trend & Filtering Components ==="
input bool                      InpMamaEnable         = true;               // 1. MAMA vs FAMA Voter
input double                    InpMamaWeight         = 1.0;                // MAMA Weight
input double                    InpMamaFastLimit      = 0.50;               // MAMA Fast Limit Alpha
input double                    InpMamaSlowLimit      = 0.05;               // MAMA Slow Limit Alpha
input bool                      InpSmootherEnable     = true;               // 2. Price vs Ehlers Smoother Voter
input double                    InpSmootherWeight     = 1.0;                // Smoother Weight
input ENUM_SMOOTHER_TYPE        InpSmootherType       = SUPERSMOOTHER;      // Smoother Type (Super / Ultimate)
input int                       InpSmootherPeriod     = 20;                 // Smoother Cutoff Period

input group "=== 2. Momentum & Cycle Components ==="
input bool                      InpLrsiEnable         = true;               // 3. Laguerre RSI Voter
input double                    InpLrsiWeight         = 1.0;                // Laguerre RSI Weight
input double                    InpLrsiGamma          = 0.500;              // Laguerre Gamma (e.g. 0.236, 0.382, 0.500, 0.618)
input bool                      InpCyberEnable        = true;               // 4. Cyber Cycle Voter
input double                    InpCyberWeight        = 1.0;                // Cyber Cycle Weight
input double                    InpCyberAlpha         = 0.062;              // Cyber Alpha (Fibo: 0.038, 0.062, 0.088)
input bool                      InpRoofEnable         = true;               // 5. Roofing Filter Voter
input double                    InpRoofWeight         = 1.0;                // Roofing Filter Weight
input int                       InpRoofHPPeriod       = 48;                 // Roofing HighPass Cutoff
input int                       InpRoofSSPeriod       = 10;                 // Roofing SuperSmoother Cutoff

input group "=== 3. Volatility & Squeeze Components ==="
input bool                      InpBandsEnable        = true;               // 6. Ehlers Bands %B Voter
input double                    InpBandsWeight        = 1.0;                // Ehlers Bands Weight
input int                       InpBandsSmoothPeriod  = 20;                 // Ehlers Bands Centerline Period
input int                       InpBandsPeriod        = 20;                 // Ehlers Bands Dispersion Period
input double                    InpBandsMult          = 2.0;                // Ehlers Bands Multiplier
input ENUM_EHLERS_BANDS_MODE    InpBandsMode          = BANDS_RMS_RESIDUAL; // Ehlers Bands Mode (RMS / StDev)
input bool                      InpSqzEnable          = true;               // 7. TTM Squeeze Momentum Voter
input double                    InpSqzWeight          = 1.0;                // Squeeze Weight
input int                       InpSqzPeriod          = 20;                 // Squeeze BB & KC Basis Period
input double                    InpSqzBBMult          = 2.0;                // Squeeze BB Multiplier
input int                       InpSqzAtrPeriod       = 20;                 // Squeeze KC ATR Period
input double                    InpSqzKCMult          = 1.5;                // Squeeze KC Multiplier
input int                       InpSqzMomPeriod       = 20;                 // Squeeze LinReg Momentum Period

input group "=== 4. Volume & Microstructure Components ==="
input bool                      InpVpEnable           = true;               // 8. Volume Pressure (CLV) Voter
input double                    InpVpWeight           = 1.0;                // Volume Pressure Weight
input int                       InpVpSmoothPeriod     = 5;                  // Volume Pressure Smoothing (1 = Raw)
input ENUM_MA_TYPE              InpVpMAType           = VWMA;               // Volume Pressure Smoothing MA (VWMA Recommended)
input double                    InpVpNeutralZone      = 0.10;               // Volume Pressure Neutral Dead Zone

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
CDSPEnsembleCalculator *g_calculator     = NULL;
bool                    g_is_mtf_mode    = false;
ENUM_TIMEFRAMES         g_calc_timeframe;
bool                    g_data_ready     = false;
bool                    g_data_synced    = false;
int                     g_htf_count      = 0;
datetime                g_last_htf_time  = 0;

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

// 2. Bind Output Buffers (Invariant 2-Plot / 3-Buffer Allocation)
   SetIndexBuffer(0, BufferConsensus,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferColors,     INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferSignalLine, INDICATOR_DATA);

   ArraySetAsSeries(BufferConsensus,  false);
   ArraySetAsSeries(BufferColors,     false);
   ArraySetAsSeries(BufferSignalLine, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// 3. Dynamic Visual Styling & Plot Switching
   if(InpPlotMode == DSP_PLOT_HISTOGRAM)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
      PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorHistBull);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorHistBear);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorHistNeutral);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthHist);

      // Omit 0.0 line in histogram mode
      IndicatorSetInteger(INDICATOR_LEVELS, 4);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, (double)InpStrongThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -(double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -(double)InpStrongThreshold);
     }
   else // DSP_PLOT_LINE (Uses DRAW_COLOR_LINE to preserve 2-buffer mapping!)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
      PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleConsensusLine);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthConsensusLine);

      // Include 0.0 midline in line mode
      IndicatorSetInteger(INDICATOR_LEVELS, 5);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, (double)InpStrongThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 0.0);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -(double)InpSignalThreshold);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, -(double)InpStrongThreshold);
     }

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

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 60);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 60);
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

// 4. Initialize Master DSP Ensemble Calculator
   g_calculator = new CDSPEnsembleCalculator();
   if(CheckPointer(g_calculator) == POINTER_INVALID ||
      !g_calculator.Init(InpNeutralZone, InpConsensusSmoothing,
                         InpSignalPeriod, InpSignalMAType, InpSourcePrice,
                         InpMamaEnable, InpMamaWeight, InpMamaFastLimit, InpMamaSlowLimit,
                         InpSmootherEnable, InpSmootherWeight, InpSmootherType, InpSmootherPeriod,
                         InpLrsiEnable, InpLrsiWeight, InpLrsiGamma,
                         InpCyberEnable, InpCyberWeight, InpCyberAlpha,
                         InpRoofEnable, InpRoofWeight, InpRoofHPPeriod, InpRoofSSPeriod,
                         InpBandsEnable, InpBandsWeight, InpBandsSmoothPeriod, InpBandsPeriod, InpBandsMult, InpBandsMode,
                         InpSqzEnable, InpSqzWeight, InpSqzPeriod, InpSqzBBMult, InpSqzAtrPeriod, InpSqzKCMult, InpSqzMomPeriod,
                         InpVpEnable, InpVpWeight, InpVpSmoothPeriod, InpVpMAType, InpVpNeutralZone))
     {
      Print("Critical Error: Failed to initialize DSP Ensemble Calculator.");
      return INIT_FAILED;
     }

   string ha_tag = (InpSourcePrice <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("DSP Ensemble%s%s(%d, %s %d)", ha_tag, tf_str, InpConsensusSmoothing, EnumToString(InpSignalMAType), InpSignalPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, (InpPlotMode == DSP_PLOT_HISTOGRAM) ? "DSP Consensus Bar" : "DSP Consensus Line");
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
   int required_bars = 70;
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

         // Threshold-Based Neutral Zone Coloring (-Threshold to +Threshold is Neutral/Gray)
         int col_idx = 2;
         if(c_val > (double)InpSignalThreshold)
            col_idx = 0; // Bullish (> +20)
         else
            if(c_val < -(double)InpSignalThreshold)
               col_idx = 1; // Bearish (< -20)

         BufferColors[i] = col_idx;
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = 80;
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

      // Compute HTF DSP Ensemble Consensus & Signal Line on Clean HTF Domain
      g_calculator.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_vol,
                             h_res_consensus, h_res_signal, h_res_raw, h_res_agreement);
      g_data_ready = true;

      // TWO-POINTER CHRONOLOGICAL SWEEP (Zero API calls, Nanosecond Execution!)
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

         int col_idx = 2;
         if(c_val > (double)InpSignalThreshold)
            col_idx = 0;
         else
            if(c_val < -(double)InpSignalThreshold)
               col_idx = 1;

         BufferColors[i] = col_idx;
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

   int col_idx = 2;
   if(val_cons > (double)InpSignalThreshold)
      col_idx = 0;
   else
      if(val_cons < -(double)InpSignalThreshold)
         col_idx = 1;

   for(int i = start; i < rates_total; i++)
     {
      BufferConsensus[i]  = val_cons;
      BufferSignalLine[i] = val_sig;
      BufferColors[i]     = col_idx;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = 80 + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
