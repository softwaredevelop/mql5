//+------------------------------------------------------------------+
//|                                     ClustersVolumeProfile_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Enterprise Edition: Full MTF Fast-Path, Heikin Ashi & Extended 100-Iteration Support
#property description "Clusters Volume Profile with Volume-Weighted K-Means Regime Segmentation."
#property description "Features native & MTF support, multi-price & Heikin Ashi routing, and non-flicker GUI."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <MyIncludes\ClustersVolumeProfile_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Dot Size Enumeration
enum ENUM_DOT_SIZE
  {
   DOT_TINY   = 1, // Tiny
   DOT_SMALL  = 2, // Small
   DOT_NORMAL = 3, // Normal
   DOT_LARGE  = 4, // Large
   DOT_HUGE   = 5  // Huge
  };

//--- Input Parameters: Timeframe Settings
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

//--- Input Parameters: Clustering Settings
input group "=== Clustering Settings ==="
input int                       InpLookback       = 200;                    // Lookback Period (Bars, 50-1000)
input int                       InpClusters       = 5;                      // Number of Clusters (k: 2-10)
input int                       InpIterations     = 50;                     // Max K-Means Iterations (5-100)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource    = PRICE_MEDIAN_STD;       // Price Source (Standard / Heikin Ashi)

//--- Input Parameters: Volume Profile Settings
input group "=== Volume Profile Settings ==="
input int                       InpRows           = 20;                     // Rows per Cluster VP (Vertical Bins)
input int                       InpVPWidth        = 40;                     // Max VP Width (Bars)
input int                       InpVPOffset       = 10;                     // VP Offset (Bars to the right of live bar)
input bool                      InpShowDots       = true;                   // Highlight Price Dots on Bars
input ENUM_DOT_SIZE             InpDotSize        = DOT_SMALL;              // Price Dot Size
input bool                      InpShowPOCLine    = true;                   // Draw POC Dashed Ray Lines
input bool                      InpShowLabels     = true;                   // Display Volume Labels
input bool                      InpLiveUpdate     = false;                  // Live-Tick Recalculation (false = On Bar Close)

//--- Symmetrical 10-Color Institutional Palette
const color PALETTE[10] =
  {
   clrDodgerBlue,
   clrCrimson,
   clrMediumSeaGreen,
   clrOrange,
   clrDarkOrchid,
   clrDarkTurquoise,
   clrGold,
   clrDeepPink,
   clrChocolate,
   clrSlateGray
  };

//--- Global Engine & State Management
CClustersVolumeProfile_Calculator *g_engine = NULL;
string                             g_prefix = "";
datetime                           g_last_calc_time = 0;
ulong                              g_last_tick_ms   = 0;

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
long     h_tick_vol[], h_vol[];
datetime h_time[];

//+------------------------------------------------------------------+
//| Format Volume Utility (e.g., 1.25M, 45.20K)                      |
//+------------------------------------------------------------------+
string FormatVolume(const double vol)
  {
   if(vol >= 1.0e9)
      return StringFormat("%.2fB", vol / 1.0e9);
   if(vol >= 1.0e6)
      return StringFormat("%.2fM", vol / 1.0e6);
   if(vol >= 1.0e3)
      return StringFormat("%.2fK", vol / 1.0e3);
   return StringFormat("%.0f", vol);
  }

//+------------------------------------------------------------------+
//| Blend Color with Background (Simulates Alpha Transparency)       |
//+------------------------------------------------------------------+
color BlendColor(const color fg, const color bg, const double alpha)
  {
   int r_fg = (int)(fg & 0xFF);
   int g_fg = (int)((fg >> 8) & 0xFF);
   int b_fg = (int)((fg >> 16) & 0xFF);

   int r_bg = (int)(bg & 0xFF);
   int g_bg = (int)((bg >> 8) & 0xFF);
   int b_bg = (int)((bg >> 16) & 0xFF);

   int r = (int)(r_fg * (1.0 - alpha) + r_bg * alpha);
   int g = (int)(g_fg * (1.0 - alpha) + g_bg * alpha);
   int b = (int)(b_fg * (1.0 - alpha) + b_bg * alpha);

   return (color)(r | (g << 8) | (b << 16));
  }

//+------------------------------------------------------------------+
//| Clean Chart Objects with Isolated Prefix                         |
//+------------------------------------------------------------------+
void CleanUp()
  {
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
//| Render Clusters & Volume Profile Graphical Elements              |
//+------------------------------------------------------------------+
void RenderClusterProfiles(const datetime &ltf_time[], const double &ltf_high[], const double &ltf_low[], const int ltf_rates_total)
  {
   CleanUp(); // Wipe previous objects within isolated ChartID namespace

   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int periodSec = PeriodSeconds();
   int n         = g_engine.GetLookbackProcessed();
   int k         = g_engine.GetClusterCount();

   if(n < 10 || k < 2)
      return;

   datetime calcStartTime = g_engine.GetBarTime(n - 1);
   datetime vpStartTime   = ltf_time[ltf_rates_total - 1] + (datetime)(InpVPOffset * periodSec);

   int obj_counter = 0;

// 1. Render Cluster Price Dots on Chart Bars
   if(InpShowDots)
     {
      if(!g_is_mtf_mode)
        {
         for(int i = 0; i < n; i++)
           {
            int cluster_id = g_engine.GetBarAssignment(i);
            if(cluster_id < 0)
               continue;

            color dot_col = PALETTE[cluster_id % 10];
            string dot_name = StringFormat("%sDOT_%d", g_prefix, obj_counter++);

            ObjectCreate(0, dot_name, OBJ_ARROW, 0, g_engine.GetBarTime(i), g_engine.GetBarPrice(i));
            ObjectSetInteger(0, dot_name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, dot_name, OBJPROP_COLOR, dot_col);
            ObjectSetInteger(0, dot_name, OBJPROP_WIDTH, (int)InpDotSize);
            ObjectSetInteger(0, dot_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, dot_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, dot_name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, dot_name, OBJPROP_BACK, false);
           }
        }
      else
        {
         // Two-Pointer Chronological Alignment: Project HTF cluster colors to LTF chart bars
         int htf_ptr = 0;
         datetime oldest_htf = h_time[0];

         for(int i = 0; i < ltf_rates_total; i++)
           {
            datetime t = ltf_time[i];
            if(t < oldest_htf || t < calcStartTime)
               continue;

            while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
               htf_ptr++;

            // Map HTF index to Lookback window (0 = newest bar)
            int htf_window_idx = (g_htf_count - 1) - htf_ptr;
            int cluster_id = g_engine.GetBarAssignment(htf_window_idx);
            if(cluster_id < 0)
               continue;

            color dot_col = PALETTE[cluster_id % 10];
            string dot_name = StringFormat("%sDOT_%d", g_prefix, obj_counter++);
            double dot_y = (ltf_high[i] + ltf_low[i]) * 0.5;

            ObjectCreate(0, dot_name, OBJ_ARROW, 0, t, dot_y);
            ObjectSetInteger(0, dot_name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, dot_name, OBJPROP_COLOR, dot_col);
            ObjectSetInteger(0, dot_name, OBJPROP_WIDTH, (int)InpDotSize);
            ObjectSetInteger(0, dot_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, dot_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, dot_name, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, dot_name, OBJPROP_BACK, false);
           }
        }
     }

// 2. Render Per-Cluster Volume Profiles & POC Lines
   for(int c_id = 0; c_id < k; c_id++)
     {
      SClusterData cluster;
      if(!g_engine.GetClusterData(c_id, cluster) || cluster.member_count == 0)
         continue;

      color cluster_col = PALETTE[c_id % 10];
      double max_bin_vol = cluster.poc_volume;
      int bin_count = ArraySize(cluster.bins);

      for(int b_idx = 0; b_idx < bin_count; b_idx++)
        {
         double vol = cluster.bins[b_idx].volume;
         if(vol <= 0.0)
            continue;

         double b_bottom = cluster.bins[b_idx].bottom_price;
         double b_top    = cluster.bins[b_idx].top_price;
         bool   is_poc   = cluster.bins[b_idx].is_poc;

         int b_width = (max_bin_vol > 0.0) ? (int)MathRound((vol / max_bin_vol) * (double)InpVPWidth) : 1;
         if(b_width < 1)
            b_width = 1;

         datetime binEndTime = vpStartTime + (datetime)(b_width * periodSec);
         color b_color = is_poc ? cluster_col : BlendColor(cluster_col, chartBg, 0.75);

         // Histogram Box (OBJ_RECTANGLE)
         string box_name = StringFormat("%sBOX_%d", g_prefix, obj_counter++);
         ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, vpStartTime, b_top, binEndTime, b_bottom);
         ObjectSetInteger(0, box_name, OBJPROP_COLOR, is_poc ? cluster_col : b_color);
         ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, b_color);
         ObjectSetInteger(0, box_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, box_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, box_name, OBJPROP_HIDDEN, true);

         // Point of Control (POC) Features
         if(is_poc)
           {
            double poc_y = cluster.poc_price;

            // POC Dashed Horizontal Ray Line
            if(InpShowPOCLine)
              {
               string line_name = StringFormat("%sPOCLN_%d", g_prefix, obj_counter++);
               ObjectCreate(0, line_name, OBJ_TREND, 0, calcStartTime, poc_y, vpStartTime, poc_y);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, cluster_col);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
              }

            // Numerical Volume Labels
            if(InpShowLabels)
              {
               // Left POC Volume Label
               string poc_lbl = StringFormat("%sPOCLBL_%d", g_prefix, obj_counter++);
               ObjectCreate(0, poc_lbl, OBJ_TEXT, 0, calcStartTime, poc_y);
               ObjectSetString(0,  poc_lbl, OBJPROP_TEXT, " " + FormatVolume(vol));
               ObjectSetInteger(0, poc_lbl, OBJPROP_COLOR, cluster_col);
               ObjectSetInteger(0, poc_lbl, OBJPROP_ANCHOR, ANCHOR_RIGHT);
               ObjectSetString(0,  poc_lbl, OBJPROP_FONT, "Arial");
               ObjectSetInteger(0, poc_lbl, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, poc_lbl, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, poc_lbl, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, poc_lbl, OBJPROP_HIDDEN, true);

               // Right Cluster Total Volume Label
               string tot_lbl = StringFormat("%sTOTLBL_%d", g_prefix, obj_counter++);
               ObjectCreate(0, tot_lbl, OBJ_TEXT, 0, binEndTime, poc_y);
               ObjectSetString(0,  tot_lbl, OBJPROP_TEXT, " Total: " + FormatVolume(cluster.total_volume));
               ObjectSetInteger(0, tot_lbl, OBJPROP_COLOR, cluster_col);
               ObjectSetInteger(0, tot_lbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
               ObjectSetString(0,  tot_lbl, OBJPROP_FONT, "Arial");
               ObjectSetInteger(0, tot_lbl, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, tot_lbl, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, tot_lbl, OBJPROP_SELECTED, false);
               ObjectSetInteger(0, tot_lbl, OBJPROP_HIDDEN, true);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_prefix = StringFormat("CVP_%I64d_", ChartID());
   CleanUp();

   g_last_calc_time = 0;
   g_last_tick_ms   = 0;
   g_data_ready     = false;
   g_data_synced    = false;
   g_htf_count      = 0;
   g_last_htf_time  = 0;

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

// 2. Initialize Engine
   g_engine = new CClustersVolumeProfile_Calculator();
   if(CheckPointer(g_engine) == POINTER_INVALID)
     {
      Print("Critical Error: Failed to instantiate CClustersVolumeProfile_Calculator.");
      return INIT_FAILED;
     }

   string tf_str = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string ha_str = (InpPriceSource <= PRICE_HA_CLOSE) ? " HA" : "";
   string short_name = StringFormat("Clusters VP%s%s(k=%d, N=%d, iter=%d)",
                                    ha_str, tf_str, InpClusters, InpLookback, InpIterations);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

// 3. Background Timer for MTF synchronization
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

   CleanUp();

   if(CheckPointer(g_engine) != POINTER_INVALID)
     {
      delete g_engine;
      g_engine = NULL;
     }

   ChartRedraw(0);
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
   int n = InpLookback;
   if(rates_total < n || n < 10 || !g_engine)
      return rates_total;

// Chronological alignment enforcement
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation
//===================================================================
   if(!g_is_mtf_mode)
     {
      datetime current_live_bar = time[rates_total - 1];
      if(!InpLiveUpdate && prev_calculated > 0 && current_live_bar == g_last_calc_time)
         return rates_total;

      ulong current_ms = GetTickCount64();
      if(InpLiveUpdate && prev_calculated > 0 && (current_ms - g_last_tick_ms < 250))
         return rates_total;

      g_last_calc_time = current_live_bar;
      g_last_tick_ms   = current_ms;

      if(!g_engine.Execute(rates_total, InpLookback, InpClusters, InpIterations, InpRows,
                           InpPriceSource, time, open, high, low, close, tick_volume, volume))
         return rates_total;

      RenderClusterProfiles(time, high, low, rates_total);
      ChartRedraw(0);
      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars = InpLookback + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0;
     }

   g_data_synced = true;

   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

// A) HTF Bar Closure / Startup: Perform bulk history sync once
   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 2000);

      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,     g_htf_count);
         ArrayResize(h_open,     g_htf_count);
         ArrayResize(h_high,     g_htf_count);
         ArrayResize(h_low,      g_htf_count);
         ArrayResize(h_close,    g_htf_count);
         ArrayResize(h_tick_vol, g_htf_count);
         ArrayResize(h_vol,      g_htf_count);

         ArraySetAsSeries(h_time,     false);
         ArraySetAsSeries(h_open,     false);
         ArraySetAsSeries(h_high,     false);
         ArraySetAsSeries(h_low,      false);
         ArraySetAsSeries(h_close,    false);
         ArraySetAsSeries(h_tick_vol, false);
         ArraySetAsSeries(h_vol,      false);
        }

      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]     = htf_bulk_rates[i].time;
         h_open[i]     = htf_bulk_rates[i].open;
         h_high[i]     = htf_bulk_rates[i].high;
         h_low[i]      = htf_bulk_rates[i].low;
         h_close[i]    = htf_bulk_rates[i].close;
         h_tick_vol[i] = htf_bulk_rates[i].tick_volume;
         h_vol[i]      = (long)htf_bulk_rates[i].real_volume;
        }

      if(!g_engine.Execute(g_htf_count, InpLookback, InpClusters, InpIterations, InpRows,
                           InpPriceSource, h_time, h_open, h_high, h_low, h_close, h_tick_vol, h_vol))
         return rates_total;

      g_data_ready = true;
      RenderClusterProfiles(time, high, low, rates_total);
      ChartRedraw(0);
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH (MTF Intra-Bar Throttled Update)
   if(InpLiveUpdate)
     {
      ulong current_ms = GetTickCount64();
      if(current_ms - g_last_tick_ms < 250)
         return rates_total;
      g_last_tick_ms = current_ms;

      int live_idx = g_htf_count - 1;
      if(live_idx >= required_bars)
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
            h_vol[live_idx]      = (long)htf_rate[0].real_volume;

            if(g_engine.Execute(g_htf_count, InpLookback, InpClusters, InpIterations, InpRows,
                                InpPriceSource, h_time, h_open, h_high, h_low, h_close, h_tick_vol, h_vol))
              {
               RenderClusterProfiles(time, high, low, rates_total);
               ChartRedraw(0);
              }
           }
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler (Data Synchronization Daemon)              |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int required_bars = InpLookback + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
