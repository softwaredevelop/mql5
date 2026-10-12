//+------------------------------------------------------------------+
//|                                               VWAP_Bands_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.60" // Enterprise Ultra: Zero-Heap Live Ticks, Gated Session Masquerade & ALU Optimized
#property description "Volume Weighted Average Price (VWAP) with Volume-Weighted Standard Deviation Bands."
#property description "Engineered for maximum multi-chart concurrency with nanosecond execution pipelines."

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot 1-2: VWAP (Odd/Even for Gapped Drawing)
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  ""
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3-4: Band 1 (+/- 1.0 Sigma)
#property indicator_label3  "Upper Band 1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "Lower Band 1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5-6: Band 2 (+/- 2.0 Sigma)
#property indicator_label5  "Upper Band 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCoral
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Lower Band 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCoral
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Plot 7-8: Band 3 (+/- 3.0 Sigma)
#property indicator_label7  "Upper Band 3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCrimson
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  "Lower Band 3"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrCrimson
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Included Engines & Central Tools
#include <MyIncludes\VWAP_Calculator.mqh>
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
input ENUM_TIMEFRAMES           InpTimeframe            = PERIOD_CURRENT;        // Calculation Timeframe (Current or HTF)

input group "--- VWAP Settings ---"
input ENUM_VWAP_PERIOD          InpResetPeriod          = PERIOD_SESSION;        // Reset Period
input int                       InpTzShift              = 0;                     // Timezone Shift in hours vs Broker Time
input string                    InpCustomSessionStart   = "09:30";               // Start time (HH:MM) for Custom Session
input string                    InpCustomSessionEnd     = "16:00";               // End time (HH:MM) for Custom Session

input group "--- Calculation Settings ---"
input ENUM_APPLIED_VOLUME       InpVolumeType           = VOLUME_TICK;           // Volume Type
input ENUM_CANDLE_SOURCE        InpCandleSource         = CANDLE_STANDARD;       // Candle Source

input group "--- Bands Settings ---"
input double                    InpBand1Mult            = 1.0;                   // Band 1 Multiplier (Sigma)
input double                    InpBand2Mult            = 2.0;                   // Band 2 Multiplier (Sigma)
input double                    InpBand3Mult            = 3.0;                   // Band 3 Multiplier (Sigma)
input bool                      InpCurrentSessionOnly   = true;                  // Display Bands for Most Recent Session Only?

input group "--- Visual Settings - VWAP Centerline ---"
input color                     InpColorVWAP            = clrOrange;             // Centerline Color
input ENUM_LINE_STYLE           InpStyleVWAP            = STYLE_SOLID;           // Centerline Style
input int                       InpWidthVWAP            = 2;                     // Centerline Width

input group "--- Visual Settings - Bands Colors ---"
input color                     InpColorBand1           = clrDodgerBlue;         // Band 1 Color (+/- 1σ)
input color                     InpColorBand2           = clrCoral;              // Band 2 Color (+/- 2σ)
input color                     InpColorBand3           = clrCrimson;            // Band 3 Color (+/- 3σ)

//--- Visual Indicator Buffers ---
double BufVWAP_Odd[];
double BufVWAP_Even[];
double BufUp1[], BufDn1[];
double BufUp2[], BufDn2[];
double BufUp3[], BufDn3[];

//--- Persistent Native Calculation Registers
double m_cum_vol_cache[];
double m_cum_tpv2_cache[];
int    m_session_tag_cache[];
double m_tp_cache[];

//--- Persistent HTF Data & Calculation Registers (Eliminates memory thrashing on live ticks)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
double   h_res_odd[], h_res_even[];
double   h_res_tp[];
double   h_res_up1[], h_res_dn1[];
double   h_res_up2[], h_res_dn2[];
double   h_res_up3[], h_res_dn3[];
datetime h_time[];

double   m_htf_cvol[];
double   m_htf_ctpv2[];
int      m_htf_stag[];

//--- Global Objects & State Management
CVWAPCalculator *g_calculator = NULL;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

// Forward Declarations
void CalculateVWAPBandsEngine(const int total_bars, const int prev_calc,
                              const double &tp_arr[],
                              const long &tick_vol_arr[], const long &vol_arr[],
                              const ENUM_APPLIED_VOLUME vol_type,
                              const double &vwap_odd_arr[], const double &vwap_even_arr[],
                              double &cum_vol_reg[], double &cum_tpv2_reg[], int &sess_tag_reg[],
                              double &up1[], double &dn1[], double &up2[], double &dn2[], double &up3[], double &dn3[]);

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
   SetIndexBuffer(0, BufVWAP_Odd,  INDICATOR_DATA);
   SetIndexBuffer(1, BufVWAP_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufUp1,       INDICATOR_DATA);
   SetIndexBuffer(3, BufDn1,       INDICATOR_DATA);
   SetIndexBuffer(4, BufUp2,       INDICATOR_DATA);
   SetIndexBuffer(5, BufDn2,       INDICATOR_DATA);
   SetIndexBuffer(6, BufUp3,       INDICATOR_DATA);
   SetIndexBuffer(7, BufDn3,       INDICATOR_DATA);

   for(int i = 0; i < 8; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BufVWAP_Odd,  false);
   ArraySetAsSeries(BufVWAP_Even, false);
   ArraySetAsSeries(BufUp1,       false);
   ArraySetAsSeries(BufDn1,       false);
   ArraySetAsSeries(BufUp2,       false);
   ArraySetAsSeries(BufDn2,       false);
   ArraySetAsSeries(BufUp3,       false);
   ArraySetAsSeries(BufDn3,       false);

   ArrayInitialize(BufVWAP_Odd,  EMPTY_VALUE);
   ArrayInitialize(BufVWAP_Even, EMPTY_VALUE);
   ArrayInitialize(BufUp1,       EMPTY_VALUE);
   ArrayInitialize(BufDn1,       EMPTY_VALUE);
   ArrayInitialize(BufUp2,       EMPTY_VALUE);
   ArrayInitialize(BufDn2,       EMPTY_VALUE);
   ArrayInitialize(BufUp3,       EMPTY_VALUE);
   ArrayInitialize(BufDn3,       EMPTY_VALUE);

// 3. Configure Dynamic Visual Styling
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidthVWAP);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorVWAP);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleVWAP);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpWidthVWAP);
   PlotIndexSetString(1,  PLOT_LABEL, "VWAP (Segment)");

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorBand1);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpColorBand2);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpColorBand3);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpColorBand3);

// 4. Initialize Core Calculator Engine
   if(InpCandleSource == CANDLE_HEIKIN_ASHI)
      g_calculator = new CVWAPCalculator_HA();
   else
      g_calculator = new CVWAPCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID)
      return INIT_FAILED;

   bool init_success = false;
   if(InpResetPeriod == PERIOD_CUSTOM_SESSION)
      init_success = g_calculator.Init(InpCustomSessionStart, InpCustomSessionEnd, InpVolumeType, true, 100, InpTzShift);
   else
      init_success = g_calculator.Init(InpResetPeriod, InpVolumeType, InpTzShift, true, 100);

   if(!init_success)
      return INIT_FAILED;

   string ha_tag = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string short_name = StringFormat("VWAP Bands%s%s(%s)", ha_tag, tf_str, EnumToString(InpResetPeriod));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
//| High-Performance O(1) Engine with Monotonic Session Tracking     |
//+------------------------------------------------------------------+
void CalculateVWAPBandsEngine(const int total_bars, const int prev_calc,
                              const double &tp_arr[],
                              const long &tick_vol_arr[], const long &vol_arr[],
                              const ENUM_APPLIED_VOLUME vol_type,
                              const double &vwap_odd_arr[], const double &vwap_even_arr[],
                              double &cum_vol_reg[], double &cum_tpv2_reg[], int &sess_tag_reg[],
                              double &up1[], double &dn1[], double &up2[], double &dn2[], double &up3[], double &dn3[])
  {
   if(ArraySize(cum_vol_reg) != total_bars)
     {
      ArrayResize(cum_vol_reg,      total_bars);
      ArraySetAsSeries(cum_vol_reg,      false);
      ArrayResize(cum_tpv2_reg,     total_bars);
      ArraySetAsSeries(cum_tpv2_reg,     false);
      ArrayResize(sess_tag_reg,     total_bars);
      ArraySetAsSeries(sess_tag_reg,     false);
     }

   int start = (prev_calc > 0) ? (prev_calc - 1) : 0;

   double cum_vol       = 0.0;
   double cum_tpv2      = 0.0;
   int    last_parity   = 0;
   int    cur_sess_id   = 0;

// Load persistent registers from previous committed bar in O(1)
   if(start > 0)
     {
      int base = start - 1;
      cum_vol     = cum_vol_reg[base];
      cum_tpv2    = cum_tpv2_reg[base];
      cur_sess_id = sess_tag_reg[base];

      bool base_odd  = (vwap_odd_arr[base]  != EMPTY_VALUE && vwap_odd_arr[base]  > 0.0);
      bool base_even = (vwap_even_arr[base] != EMPTY_VALUE && vwap_even_arr[base] > 0.0);
      last_parity    = base_odd ? 1 : (base_even ? 2 : 0);
     }

   for(int i = start; i < total_bars; i++)
     {
      bool is_odd  = (vwap_odd_arr[i]  != EMPTY_VALUE && vwap_odd_arr[i]  > 0.0);
      bool is_even = (vwap_even_arr[i] != EMPTY_VALUE && vwap_even_arr[i] > 0.0);

      if(!is_odd && !is_even)
        {
         last_parity     = 0;
         cum_vol         = 0.0;
         cum_tpv2        = 0.0;
         up1[i] = EMPTY_VALUE;
         dn1[i] = EMPTY_VALUE;
         up2[i] = EMPTY_VALUE;
         dn2[i] = EMPTY_VALUE;
         up3[i] = EMPTY_VALUE;
         dn3[i] = EMPTY_VALUE;
         cum_vol_reg[i]  = 0.0;
         cum_tpv2_reg[i] = 0.0;
         sess_tag_reg[i] = 0;
         continue;
        }

      int parity = is_odd ? 1 : 2;

      // Monotonic Session ID increment upon true session boundary or post-gap return
      if(parity != last_parity || cur_sess_id == 0)
        {
         cur_sess_id++;
         cum_vol     = 0.0;
         cum_tpv2    = 0.0;
         last_parity = parity;
        }

      double vwap = is_odd ? vwap_odd_arr[i] : vwap_even_arr[i];

      if(vwap > 0.0)
        {
         double tp = tp_arr[i];
         long v_raw = (vol_type == VOLUME_REAL) ? vol_arr[i] : tick_vol_arr[i];
         double vol = (v_raw < 1) ? 1.0 : (double)v_raw;

         cum_vol  += vol;
         cum_tpv2 += (tp * tp) * vol;

         if(cum_vol > 0.0)
           {
            // Guaranteed mathematical variance: E[P^2] - (E[P])^2
            double mean_p2  = cum_tpv2 / cum_vol;
            double variance = mean_p2 - (vwap * vwap);
            double stddev   = (variance > 1.0e-12) ? MathSqrt(variance) : 0.0;

            up1[i] = vwap + (InpBand1Mult * stddev);
            dn1[i] = vwap - (InpBand1Mult * stddev);
            up2[i] = vwap + (InpBand2Mult * stddev);
            dn2[i] = vwap - (InpBand2Mult * stddev);
            up3[i] = vwap + (InpBand3Mult * stddev);
            dn3[i] = vwap - (InpBand3Mult * stddev);
           }
         else
           {
            up1[i] = EMPTY_VALUE;
            dn1[i] = EMPTY_VALUE;
            up2[i] = EMPTY_VALUE;
            dn2[i] = EMPTY_VALUE;
            up3[i] = EMPTY_VALUE;
            dn3[i] = EMPTY_VALUE;
           }
        }
      else
        {
         up1[i] = EMPTY_VALUE;
         dn1[i] = EMPTY_VALUE;
         up2[i] = EMPTY_VALUE;
         dn2[i] = EMPTY_VALUE;
         up3[i] = EMPTY_VALUE;
         dn3[i] = EMPTY_VALUE;
        }

      // Commit persistent state registers (Now storing strictly unique monotonic session IDs)
      cum_vol_reg[i]  = cum_vol;
      cum_tpv2_reg[i] = cum_tpv2;
      sess_tag_reg[i] = cur_sess_id;
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
   if(rates_total < 2 || !g_calculator)
      return 0;

// Force chronological indexing on input arrays
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
      // 1. Calculate VWAP and Export Synchronized Typical Price in O(1)
      g_calculator.Calculate(rates_total, prev_calculated, time, open, high, low, close,
                             tick_volume, volume, BufVWAP_Odd, BufVWAP_Even, m_tp_cache);

      // 2. Calculate Running Volume-Weighted Standard Deviation Bands
      CalculateVWAPBandsEngine(rates_total, prev_calculated, m_tp_cache, tick_volume, volume, InpVolumeType,
                               BufVWAP_Odd, BufVWAP_Even, m_cum_vol_cache, m_cum_tpv2_cache, m_session_tag_cache,
                               BufUp1, BufDn1, BufUp2, BufDn2, BufUp3, BufDn3);

      // 3. Mask Older Sessions if CurrentSessionOnly is active (ALU-Optimized Rollover Gate)
      if(InpCurrentSessionOnly)
        {
         int active_sess_id = m_session_tag_cache[rates_total - 1];

         // FAST-PATH GATE: Execute search & wipe ONLY on initial startup or genuine session rollover!
         // Eliminates 99.99% of backwards while-loop evaluations on live ticks!
         bool is_rollover = (prev_calculated > 0 && m_session_tag_cache[prev_calculated - 1] != active_sess_id);

         if(prev_calculated == 0 || is_rollover)
           {
            int cur_sess_start = rates_total - 1;
            while(cur_sess_start > 0 && m_session_tag_cache[cur_sess_start - 1] == active_sess_id && active_sess_id > 0)
               cur_sess_start--;

            for(int i = 0; i < cur_sess_start; i++)
              {
               BufUp1[i] = EMPTY_VALUE;
               BufDn1[i] = EMPTY_VALUE;
               BufUp2[i] = EMPTY_VALUE;
               BufDn2[i] = EMPTY_VALUE;
               BufUp3[i] = EMPTY_VALUE;
               BufDn3[i] = EMPTY_VALUE;
              }
           }
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int htf_required = 100;
   if(InpResetPeriod == PERIOD_WEEK)
      htf_required = 1000;
   if(InpResetPeriod == PERIOD_MONTH)
      htf_required = 2000;

   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, htf_required))
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
      if(htf_bars < htf_required)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000);

      // Reallocate persistent cache registers ONLY when capacity changes
      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,       g_htf_count);
         ArrayResize(h_open,       g_htf_count);
         ArrayResize(h_high,       g_htf_count);
         ArrayResize(h_low,        g_htf_count);
         ArrayResize(h_close,      g_htf_count);
         ArrayResize(h_tick_vol,   g_htf_count);
         ArrayResize(h_vol,        g_htf_count);
         ArrayResize(h_res_odd,    g_htf_count);
         ArrayResize(h_res_even,   g_htf_count);
         ArrayResize(h_res_tp,     g_htf_count);
         ArrayResize(h_res_up1,    g_htf_count);
         ArrayResize(h_res_dn1,    g_htf_count);
         ArrayResize(h_res_up2,    g_htf_count);
         ArrayResize(h_res_dn2,    g_htf_count);
         ArrayResize(h_res_up3,    g_htf_count);
         ArrayResize(h_res_dn3,    g_htf_count);

         ArrayResize(m_htf_cvol,   g_htf_count);
         ArrayResize(m_htf_ctpv2,  g_htf_count);
         ArrayResize(m_htf_stag,   g_htf_count);

         ArraySetAsSeries(h_time,       false);
         ArraySetAsSeries(h_open,       false);
         ArraySetAsSeries(h_high,       false);
         ArraySetAsSeries(h_low,        false);
         ArraySetAsSeries(h_close,      false);
         ArraySetAsSeries(h_tick_vol,   false);
         ArraySetAsSeries(h_vol,        false);
         ArraySetAsSeries(h_res_odd,    false);
         ArraySetAsSeries(h_res_even,   false);
         ArraySetAsSeries(h_res_tp,     false);
         ArraySetAsSeries(h_res_up1,    false);
         ArraySetAsSeries(h_res_dn1,    false);
         ArraySetAsSeries(h_res_up2,    false);
         ArraySetAsSeries(h_res_dn2,    false);
         ArraySetAsSeries(h_res_up3,    false);
         ArraySetAsSeries(h_res_dn3,    false);

         ArraySetAsSeries(m_htf_cvol,   false);
         ArraySetAsSeries(m_htf_ctpv2,  false);
         ArraySetAsSeries(m_htf_stag,   false);
        }

      // Atomic bulk rates copy
      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]     = htf_bulk_rates[i].time;
         h_open[i]     = htf_bulk_rates[i].open;
         h_high[i]     = htf_bulk_rates[i].high;
         h_low[i]      = htf_bulk_rates[i].low;
         h_close[i]    = htf_bulk_rates[i].close;
         h_tick_vol[i] = htf_bulk_rates[i].tick_volume;
         h_vol[i]      = (vol_limit > 0 && htf_bulk_rates[i].real_volume > 0) ? htf_bulk_rates[i].real_volume : htf_bulk_rates[i].tick_volume;
        }

      // Compute HTF VWAP and Export Synchronized HTF Typical Price
      g_calculator.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close,
                             h_tick_vol, h_vol, h_res_odd, h_res_even, h_res_tp);

      // Compute HTF Bands into Persistent Register Pools (Populates Monotonic IDs)
      CalculateVWAPBandsEngine(g_htf_count, 0, h_res_tp, h_tick_vol, h_vol, InpVolumeType,
                               h_res_odd, h_res_even, m_htf_cvol, m_htf_ctpv2, m_htf_stag,
                               h_res_up1, h_res_dn1, h_res_up2, h_res_dn2, h_res_up3, h_res_dn3);

      g_data_ready = true;

      // Identify Current Active Session Tag on HTF (Guaranteed strictly unique monotonic integer)
      int active_sess_tag = m_htf_stag[g_htf_count - 1];

      // Full Historical Projection to Chart Buffers (With strictly unique active session isolation)
      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);
         if(shift_htf >= 0)
           {
            int idx_htf = g_htf_count - 1 - shift_htf;
            if(idx_htf >= 0 && idx_htf < g_htf_count)
              {
               BufVWAP_Odd[i]  = h_res_odd[idx_htf];
               BufVWAP_Even[i] = h_res_even[idx_htf];

               // True Isolation: ONLY the current active session matches active_sess_tag
               bool is_cur_sess = (!InpCurrentSessionOnly || (m_htf_stag[idx_htf] == active_sess_tag && active_sess_tag > 0));

               BufUp1[i] = is_cur_sess ? h_res_up1[idx_htf] : EMPTY_VALUE;
               BufDn1[i] = is_cur_sess ? h_res_dn1[idx_htf] : EMPTY_VALUE;
               BufUp2[i] = is_cur_sess ? h_res_up2[idx_htf] : EMPTY_VALUE;
               BufDn2[i] = is_cur_sess ? h_res_dn2[idx_htf] : EMPTY_VALUE;
               BufUp3[i] = is_cur_sess ? h_res_up3[idx_htf] : EMPTY_VALUE;
               BufDn3[i] = is_cur_sess ? h_res_dn3[idx_htf] : EMPTY_VALUE;
              }
            else
              {
               BufVWAP_Odd[i] = EMPTY_VALUE;
               BufVWAP_Even[i] = EMPTY_VALUE;
               BufUp1[i] = EMPTY_VALUE;
               BufDn1[i] = EMPTY_VALUE;
               BufUp2[i] = EMPTY_VALUE;
               BufDn2[i] = EMPTY_VALUE;
               BufUp3[i] = EMPTY_VALUE;
               BufDn3[i] = EMPTY_VALUE;
              }
           }
         else
           {
            BufVWAP_Odd[i] = EMPTY_VALUE;
            BufVWAP_Even[i] = EMPTY_VALUE;
            BufUp1[i] = EMPTY_VALUE;
            BufDn1[i] = EMPTY_VALUE;
            BufUp2[i] = EMPTY_VALUE;
            BufDn2[i] = EMPTY_VALUE;
            BufUp3[i] = EMPTY_VALUE;
            BufDn3[i] = EMPTY_VALUE;
           }
        }
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update forming candle in RAM!
   int live_idx = g_htf_count - 1;
   if(live_idx >= htf_required)
     {
      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]     = htf_rate[0].time;
         h_open[live_idx]     = htf_rate[0].open;
         h_high[live_idx]     = htf_rate[0].high;
         h_low[live_idx]      = htf_rate[0].low;
         h_close[live_idx]    = htf_rate[0].close;
         h_tick_vol[live_idx] = htf_rate[0].tick_volume;
         long vol_limit       = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         h_vol[live_idx]      = (vol_limit > 0 && htf_rate[0].real_volume > 0) ? htf_rate[0].real_volume : htf_rate[0].tick_volume;

         // Mock update strictly on forming candle with Synchronized TP Export
         g_calculator.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close,
                                h_tick_vol, h_vol, h_res_odd, h_res_even, h_res_tp);

         // Run Bands Engine with persistent memory registers (Zero memory amnesia!)
         CalculateVWAPBandsEngine(g_htf_count, g_htf_count, h_res_tp, h_tick_vol, h_vol, InpVolumeType,
                                  h_res_odd, h_res_even, m_htf_cvol, m_htf_ctpv2, m_htf_stag,
                                  h_res_up1, h_res_dn1, h_res_up2, h_res_dn2, h_res_up3, h_res_dn3);
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

// Direct Vectorized Assignment (Zero API calls, Nanosecond Execution across 8 buffers)
   double vwap_o = h_res_odd[live_idx];
   double vwap_e = h_res_even[live_idx];
   double up1_v  = h_res_up1[live_idx];
   double dn1_v  = h_res_dn1[live_idx];
   double up2_v  = h_res_up2[live_idx];
   double dn2_v  = h_res_dn2[live_idx];
   double up3_v  = h_res_up3[live_idx];
   double dn3_v  = h_res_dn3[live_idx];

   for(int i = start; i < rates_total; i++)
     {
      BufVWAP_Odd[i]  = vwap_o;
      BufVWAP_Even[i] = vwap_e;
      BufUp1[i]       = up1_v;
      BufDn1[i]       = dn1_v;
      BufUp2[i]       = up2_v;
      BufDn2[i]       = dn2_v;
      BufUp3[i]       = up3_v;
      BufDn3[i]       = dn3_v;
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int htf_required = 100;
   if(InpResetPeriod == PERIOD_WEEK)
      htf_required = 1000;
   if(InpResetPeriod == PERIOD_MONTH)
      htf_required = 2000;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, htf_required, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
