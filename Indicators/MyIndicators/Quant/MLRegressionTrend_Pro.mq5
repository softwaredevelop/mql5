//+------------------------------------------------------------------+
//|                                        MLRegressionTrend_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.70" // Enterprise Edition: Multi-Asset Pip & Point Normalized Error Calculation
#property description "Machine Learning Regression Trend with RANSAC Algorithm."
#property description "Features scale-invariant inlier thresholds, full visual customization, and native MTF."

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   0

#include <MyIncludes\MLRegressionTrend_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_CURRENT;         // Calculation Timeframe (Current or HTF)

input group "=== Settings ==="
input int                       InpLength         = 100;                    // Sample Length (min 5)
input double                    InpWidthMult      = 2.0;                    // Channel Width (RMSE Multiplier)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource    = PRICE_CLOSE_STD;        // Source Price (Standard / Heikin Ashi)

input group "=== RANSAC Model Settings ==="
input int                       InpInlineN        = 10;                     // Minimum Inliers Target (inlineN)
input ENUM_ERROR_TYPE           InpErrorType      = ERROR_AUTO;             // Allowed Error Type (Auto / Fixed Pips / Fixed Price)
input double                    InpMinError       = 1.0;                    // Error Value (Multiplier in Auto, Pips in Fixed Pips)
input int                       InpMaxIter        = 150;                    // Maximum Iteration Steps (maxIter)
input bool                      InpLiveUpdate     = false;                  // Real-time Update on Every Tick (false = On Bar Close)

input group "=== Style: Regression Centerline ==="
input color                     InpLineColor      = C'0x21,0x57,0xF3';      // Regression Line Color (#2157f3)
input ENUM_LINE_STYLE           InpLineStyle      = STYLE_SOLID;            // Regression Line Style
input int                       InpLineWidth      = 2;                      // Regression Line Width (1-5)

input group "=== Style: Error Margins ==="
input bool                      InpShowMargin     = true;                   // Show Error Margin
input color                     InpMarginColor    = C'0x72,0x9B,0xF8';      // Error Margin Color
input ENUM_LINE_STYLE           InpMarginStyle    = STYLE_DOT;              // Error Margin Style
input int                       InpMarginWidth    = 1;                      // Error Margin Width (1-5)

input group "=== Style: Volatility Channel ==="
input bool                      InpShowChannel    = true;                   // Show Volatility Channel
input color                     InpChannelColor   = clrSilver;              // Channel Line Color
input ENUM_LINE_STYLE           InpChannelStyle   = STYLE_DASH;             // Channel Line Style
input int                       InpChannelWidth   = 1;                      // Channel Line Width (1-5)

input group "=== Style: Inlier & Outlier Dots ==="
input bool                      InpShowInliers    = true;                   // Show Consensus Inlier Dots
input color                     InpInliersColor   = C'0x21,0x57,0xF3';      // Inliers Color (#2157f3)
input int                       InpInliersSize    = 1;                      // Inliers Dot Size (1-5)
input bool                      InpShowOutliers   = true;                   // Show Outlier Dots (Wicks/News)
input color                     InpOutliersColor  = C'0xFF,0x11,0x00';      // Outliers Color (#ff1100)
input int                       InpOutliersSize   = 2;                      // Outliers Dot Size (1-5)

input group "=== Multi-Instance Settings ==="
input int                       InpInstanceID     = 1;                      // Unique Instance ID

//--- Native Calculation Buffers (Accessible by EAs via iCustom!)
double BufRegression[];
double BufChanTop[];
double BufChanBtm[];
double BufMargTop[];
double BufMargBtm[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CMLRegressionTrend_Calculator *g_engine = NULL;
string                         g_prefix = "";

bool            g_is_mtf_mode   = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready    = false;
bool            g_data_synced   = false;
int             g_htf_count     = 0;
datetime        g_last_htf_time = 0;
datetime        g_last_bar_time = 0;
ulong           g_last_calc_ms  = 0;

//+------------------------------------------------------------------+
//| Clean Chart Objects with Isolated Deterministic Namespace        |
//+------------------------------------------------------------------+
void CleanUp()
  {
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
//| Helper to Draw or Update Trendline with Dynamic Styles & Widths  |
//+------------------------------------------------------------------+
void DrawTrendLine(const string name, const datetime t1, const double p1,
                   const datetime t2, const double p2, const color clr,
                   const ENUM_LINE_STYLE style, const int width, const bool rayRight)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   else
     {
      ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
      ObjectSetDouble(0,  name, OBJPROP_PRICE, 1, p2);
     }

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, rayRight);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Render Visual RANSAC Trend & Channels Exactly Matching Settings  |
//+------------------------------------------------------------------+
void RenderRansacVisuals()
  {
   SRansacResult res;
   if(!g_engine.GetResult(res))
      return;

   CleanUp(); // Clear previous frame

   double y1   = res.y_start;
   double y2   = res.y_end;
   datetime t1 = res.t_start;
   datetime t2 = res.t_end;

// 1. Primary Regression Line (Ray to the right)
   DrawTrendLine(g_prefix + "RegLine", t1, y1, t2, y2, InpLineColor, InpLineStyle, InpLineWidth, true);

// 2. Error Margins
   if(InpShowMargin)
     {
      DrawTrendLine(g_prefix + "MargTop", t1, y1 + res.threshold, t2, y2 + res.threshold, InpMarginColor, InpMarginStyle, InpMarginWidth, false);
      DrawTrendLine(g_prefix + "MargBtm", t1, y1 - res.threshold, t2, y2 - res.threshold, InpMarginColor, InpMarginStyle, InpMarginWidth, false);
     }

// 3. RMSE Volatility Channels (Ray to the right)
   if(InpShowChannel)
     {
      DrawTrendLine(g_prefix + "ChanTop", t1, y1 + res.channel_width, t2, y2 + res.channel_width, InpChannelColor, InpChannelStyle, InpChannelWidth, true);
      DrawTrendLine(g_prefix + "ChanBtm", t1, y1 - res.channel_width, t2, y2 - res.channel_width, InpChannelColor, InpChannelStyle, InpChannelWidth, true);
     }

// 4. Inlier & Outlier Classification Dots
   int len = res.total_points;
   for(int k = 0; k < len; k++)
     {
      bool is_inlier = g_engine.IsInlier(k);
      if((is_inlier && InpShowInliers) || (!is_inlier && InpShowOutliers))
        {
         datetime pt_time  = g_engine.GetWindowTime(k);
         double   pt_price = g_engine.GetWindowPrice(k);
         color    pt_color = is_inlier ? InpInliersColor : InpOutliersColor;
         int      pt_size  = is_inlier ? InpInliersSize  : InpOutliersSize;

         string dot_name = StringFormat("%sDOT_%d", g_prefix, k);
         ObjectCreate(0, dot_name, OBJ_ARROW, 0, pt_time, pt_price);
         ObjectSetInteger(0, dot_name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, dot_name, OBJPROP_COLOR, pt_color);
         ObjectSetInteger(0, dot_name, OBJPROP_WIDTH, pt_size);
         ObjectSetInteger(0, dot_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, dot_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, dot_name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, dot_name, OBJPROP_BACK, false);
        }
     }
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
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

// 2. Build Fully Isolated Deterministic Instance Namespace
   g_prefix = StringFormat("MLRT_%I64d_%s_%d_%d_",
                           ChartID(),
                           EnumToString(g_calc_timeframe),
                           InpLength,
                           InpInstanceID);
   CleanUp();

   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;
   g_last_bar_time = 0;
   g_last_calc_ms  = 0;

// 3. Setup Native Buffers (Accessible by EAs via iCustom!)
   SetIndexBuffer(0, BufRegression, INDICATOR_DATA);
   SetIndexBuffer(1, BufChanTop,    INDICATOR_DATA);
   SetIndexBuffer(2, BufChanBtm,    INDICATOR_DATA);
   SetIndexBuffer(3, BufMargTop,    INDICATOR_DATA);
   SetIndexBuffer(4, BufMargBtm,    INDICATOR_DATA);

   ArraySetAsSeries(BufRegression, false);
   ArraySetAsSeries(BufChanTop,    false);
   ArraySetAsSeries(BufChanBtm,    false);
   ArraySetAsSeries(BufMargTop,    false);
   ArraySetAsSeries(BufMargBtm,    false);

   ArrayInitialize(BufRegression, EMPTY_VALUE);
   ArrayInitialize(BufChanTop,    EMPTY_VALUE);
   ArrayInitialize(BufChanBtm,    EMPTY_VALUE);
   ArrayInitialize(BufMargTop,    EMPTY_VALUE);
   ArrayInitialize(BufMargBtm,    EMPTY_VALUE);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine
   g_engine = new CMLRegressionTrend_Calculator();
   if(CheckPointer(g_engine) == POINTER_INVALID ||
      !g_engine.Init(InpLength, InpWidthMult, InpInlineN, InpErrorType, InpMinError, InpMaxIter, InpPriceSource))
     {
      Print("Critical Error: Failed to initialize CMLRegressionTrend_Calculator.");
      return INIT_FAILED;
     }

   string ha_str  = (InpPriceSource <= PRICE_HA_CLOSE) ? " HA" : "";
   string tf_str  = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string inst_str= (InpInstanceID > 1) ? StringFormat(" #%d", InpInstanceID) : "";
   string name    = StringFormat("ML RANSAC Trend%s%s(N%d, k=%.1f)%s", ha_str, tf_str, InpLength, InpWidthMult, inst_str);
   IndicatorSetString(INDICATOR_SHORTNAME, name);

// 5. Background Timer for MTF synchronization
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
   int len = MathMax(InpLength, 5);
   if(rates_total < len || !g_engine)
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
// MODE 1: Direct Current Timeframe Calculation
//===================================================================
   if(!g_is_mtf_mode)
     {
      datetime current_bar_time = time[rates_total - 1];

      // Jitter elimination: On Bar Close default
      if(!InpLiveUpdate && prev_calculated > 0 && current_bar_time == g_last_bar_time)
         return rates_total;

      ulong cur_ms = GetTickCount64();
      if(InpLiveUpdate && prev_calculated > 0 && (cur_ms - g_last_calc_ms < 250))
         return rates_total;

      g_last_bar_time = current_bar_time;
      g_last_calc_ms  = cur_ms;

      // 1. Execute Exact RANSAC Engine
      if(!g_engine.Execute(rates_total, prev_calculated, time, open, high, low, close))
         return rates_total;

      // 2. Populate EA Buffers across active window
      SRansacResult res;
      if(g_engine.GetResult(res))
        {
         int win_start = rates_total - len;
         for(int k = 0; k < len; k++)
           {
            int idx = win_start + k;
            double pred = res.slope * (double)k + res.intercept;

            BufRegression[idx] = pred;
            BufChanTop[idx]    = pred + res.channel_width;
            BufChanBtm[idx]    = pred - res.channel_width;
            BufMargTop[idx]    = pred + res.threshold;
            BufMargBtm[idx]    = pred - res.threshold;
           }
        }

      // 3. Render Visuals
      RenderRansacVisuals();
      ChartRedraw(0);

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = len + 10;
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars_mtf))
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
      if(htf_bars < required_bars_mtf)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 2000);

      if(ArraySize(h_time) != g_htf_count)
        {
         ArrayResize(h_time,  g_htf_count);
         ArrayResize(h_open,  g_htf_count);
         ArrayResize(h_high,  g_htf_count);
         ArrayResize(h_low,   g_htf_count);
         ArrayResize(h_close, g_htf_count);

         ArraySetAsSeries(h_time,  false);
         ArraySetAsSeries(h_open,  false);
         ArraySetAsSeries(h_high,  false);
         ArraySetAsSeries(h_low,   false);
         ArraySetAsSeries(h_close, false);
        }

      MqlRates htf_bulk_rates[];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      for(int i = 0; i < g_htf_count; i++)
        {
         h_time[i]  = htf_bulk_rates[i].time;
         h_open[i]  = htf_bulk_rates[i].open;
         h_high[i]  = htf_bulk_rates[i].high;
         h_low[i]   = htf_bulk_rates[i].low;
         h_close[i] = htf_bulk_rates[i].close;
        }

      // Execute RANSAC Engine on Pure HTF Domain
      if(!g_engine.Execute(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close))
         return rates_total;

      g_data_ready = true;

      // Populate EA Buffers on Chart Timeframe using Two-Pointer Projector
      SRansacResult res;
      if(g_engine.GetResult(res))
        {
         int htf_win_start = g_htf_count - len;
         int htf_ptr = 0;

         for(int i = 0; i < rates_total; i++)
           {
            datetime t = time[i];
            if(t < res.t_start)
              {
               BufRegression[i] = EMPTY_VALUE;
               BufChanTop[i]    = EMPTY_VALUE;
               BufChanBtm[i]    = EMPTY_VALUE;
               BufMargTop[i]    = EMPTY_VALUE;
               BufMargBtm[i]    = EMPTY_VALUE;
               continue;
              }

            while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
               htf_ptr++;

            int k = htf_ptr - htf_win_start;
            if(k >= 0 && k < len)
              {
               double pred = res.slope * (double)k + res.intercept;
               BufRegression[i] = pred;
               BufChanTop[i]    = pred + res.channel_width;
               BufChanBtm[i]    = pred - res.channel_width;
               BufMargTop[i]    = pred + res.threshold;
               BufMargBtm[i]    = pred - res.threshold;
              }
            else
              {
               BufRegression[i] = EMPTY_VALUE;
               BufChanTop[i]    = EMPTY_VALUE;
               BufChanBtm[i]    = EMPTY_VALUE;
               BufMargTop[i]    = EMPTY_VALUE;
               BufMargBtm[i]    = EMPTY_VALUE;
              }
           }
        }

      RenderRansacVisuals();
      ChartRedraw(0);
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH (MTF Throttled Re-evaluation)
   if(InpLiveUpdate)
     {
      ulong cur_ms = GetTickCount64();
      if(cur_ms - g_last_calc_ms < 250)
         return rates_total;

      g_last_calc_ms = cur_ms;
      int live_idx = g_htf_count - 1;

      MqlRates htf_rate[1];
      if(CopyRates(_Symbol, g_calc_timeframe, 0, 1, htf_rate) == 1)
        {
         h_time[live_idx]  = htf_rate[0].time;
         h_open[live_idx]  = htf_rate[0].open;
         h_high[live_idx]  = htf_rate[0].high;
         h_low[live_idx]   = htf_rate[0].low;
         h_close[live_idx] = htf_rate[0].close;

         if(g_engine.Execute(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close))
           {
            RenderRansacVisuals();
            ChartRedraw(0);
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
   int len = MathMax(InpLength, 5);
   int required_bars_mtf = len + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars_mtf, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
