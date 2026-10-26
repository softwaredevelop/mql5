//+------------------------------------------------------------------+
//|                                           RejectionBlock_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.30" // Enterprise Edition: Streamlined Architecture, Pure GDI Canvas & Native MTF Engine
#property description "Institutional Rejection Block Indicator - Tracks swing rejection wicks and order flow."
#property description "Features non-repainting truncation, MTF support, native EA signal buffers, and ChartID isolation."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Bullish Rejection Signal Arrow
#property indicator_label1  "Bull Rejection"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMediumSeaGreen
#property indicator_width1  2

//--- Plot 2: Bearish Rejection Signal Arrow
#property indicator_label2  "Bear Rejection"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <MyIncludes\RejectionBlock_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Midline Style Options
enum ENUM_MIDLINE_STYLE
  {
   STYLE_SOLID_LINE = 0, // Solid Line
   STYLE_DASH_LINE  = 1, // Dashed Line
   STYLE_DOT_LINE   = 2  // Dotted Line
  };

//--- Input Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES       InpTimeframe         = PERIOD_CURRENT;      // Calculation Timeframe (Current or HTF)

input group "=== Rejection Blocks Core ==="
input int                   InpSwingLength       = 10;                  // Swing Pivot Length (1-100)
input double                InpMinWickPct        = 50.0;                // Minimum Wick % of Total Range (0-100)
input double                InpWickAtrMult       = 0.5;                 // Minimum Wick Size (x ATR)
input int                   InpAtrLength         = 14;                  // ATR Volatility Period
input bool                  InpSweepFilter       = false;               // Require Liquidity Sweep (Turtle Soup)
input int                   InpShowLast          = 10;                  // Maximum Zones Rendered (Pool Cap)

input group "=== Visual Styling ==="
input bool                  InpShowArrows        = false;               // Show Signal Arrows on Chart
input bool                  InpFillZones         = true;                // Fill Rectangle Zones (False = Hollow outline)
input color                 InpBullColor         = clrMediumSeaGreen;   // Bullish Zone Color
input color                 InpBearColor         = clrCrimson;          // Bearish Zone Color
input bool                  InpShowMidline       = true;                // Display 50% Equilibrium Midline
input ENUM_MIDLINE_STYLE    InpMidlineStyle      = STYLE_DOT_LINE;      // Midline Style
input bool                  InpShowInvalidated   = true;                // Display Breached Zones (Truncated)
input color                 InpInvalidColor      = clrSilver;           // Breached Zone Color

input group "=== Multi-Instance Settings ==="
input int                   InpInstanceID        = 1;                   // Unique Instance ID

//--- Indicator Output Buffers (Accessible by EAs via iCustom!)
double BufBullSig[];
double BufBearSig[];

//--- Internal HTF Data Caches (Chronological Arrays)
double   h_open[], h_high[], h_low[], h_close[];
double   h_res_bull[], h_res_bear[];
datetime h_time[];

//--- Global Engine Pointers & State Management
CRejectionBlock_Calculator *g_engine = NULL;
string                      g_prefix = "";

bool            g_is_mtf_mode    = false;
ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready     = false;
bool            g_data_synced    = false;
int             g_htf_count      = 0;
datetime        g_last_htf_time  = 0;
ulong           g_last_render_ms = 0;

//+------------------------------------------------------------------+
//| Blend Color with Background (Subtle 85% Soft Watermark)          |
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
//| Convert Midline Style                                            |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE GetMqlStyle(const ENUM_MIDLINE_STYLE style)
  {
   switch(style)
     {
      case STYLE_SOLID_LINE:
         return STYLE_SOLID;
      case STYLE_DASH_LINE:
         return STYLE_DASH;
      default:
         return STYLE_DOT;
     }
  }

//+------------------------------------------------------------------+
//| Clean Chart Objects with Isolated Deterministic Namespace        |
//+------------------------------------------------------------------+
void CleanUp()
  {
   ObjectsDeleteAll(0, g_prefix);
  }

//+------------------------------------------------------------------+
//| Render Rejection Blocks & Midlines onto Chart Window             |
//+------------------------------------------------------------------+
void RenderBlocks()
  {
   CleanUp();

   int total_blocks = g_engine.GetBlockCount();
   if(total_blocks <= 0)
      return;

   color chart_bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

   for(int b = 0; b < total_blocks; b++)
     {
      SRejectionBlock block;
      if(!g_engine.GetBlock(b, block))
         continue;

      if(block.invalidated && !InpShowInvalidated)
         continue;

      color base_color   = block.invalidated ? InpInvalidColor : (block.is_bull ? InpBullColor : InpBearColor);

      // Subtle 85% Soft Watermark Colors
      color fill_color   = BlendColor(base_color, chart_bg, 0.85);
      color border_color = BlendColor(base_color, chart_bg, 0.60);

      string box_name  = StringFormat("%sBOX_%d", g_prefix, block.id);
      string line_name = StringFormat("%sMID_%d", g_prefix, block.id);

      // 1. Draw Bounding Zone Box
      ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, block.time_start, block.top, block.time_end, block.bottom);
      ObjectSetInteger(0, box_name, OBJPROP_COLOR, border_color);
      ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, fill_color);
      ObjectSetInteger(0, box_name, OBJPROP_FILL, InpFillZones);
      ObjectSetInteger(0, box_name, OBJPROP_BACK, true); // Keep candles visible
      ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, box_name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, box_name, OBJPROP_HIDDEN, true);

      // 2. Draw 50% Equilibrium Midline
      if(InpShowMidline)
        {
         ObjectCreate(0, line_name, OBJ_TREND, 0, block.time_start, block.mid, block.time_end, block.mid);
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, BlendColor(base_color, chart_bg, 0.30));
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, GetMqlStyle(InpMidlineStyle));
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
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
   g_prefix = StringFormat("RB_%I64d_%s_%d_%d_",
                           ChartID(),
                           EnumToString(g_calc_timeframe),
                           InpSwingLength,
                           InpInstanceID);
   CleanUp();

   g_data_ready     = false;
   g_data_synced    = false;
   g_htf_count      = 0;
   g_last_htf_time  = 0;
   g_last_render_ms = 0;

// 3. Setup Buffers & Chronological Indexing
   SetIndexBuffer(0, BufBullSig, INDICATOR_DATA);
   SetIndexBuffer(1, BufBearSig, INDICATOR_DATA);

   ArraySetAsSeries(BufBullSig, false);
   ArraySetAsSeries(BufBearSig, false);

   ArrayInitialize(BufBullSig, EMPTY_VALUE);
   ArrayInitialize(BufBearSig, EMPTY_VALUE);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// Configure Signal Arrows Visibility
   if(!InpShowArrows)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
     }
   else
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(0, PLOT_ARROW, 233); // Bullish Up Arrow
      PlotIndexSetInteger(1, PLOT_ARROW, 234); // Bearish Down Arrow
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

// 4. Initialize Core Calculator Engine (Pure Price Action)
   g_engine = new CRejectionBlock_Calculator();
   if(CheckPointer(g_engine) == POINTER_INVALID ||
      !g_engine.Init(InpSwingLength, InpMinWickPct, InpWickAtrMult, InpAtrLength, InpSweepFilter, InpShowLast))
     {
      Print("Critical Error: Failed to initialize CRejectionBlock_Calculator.");
      return INIT_FAILED;
     }

   string tf_str   = g_is_mtf_mode ? (" [" + EnumToString(g_calc_timeframe) + "]") : "";
   string inst_str = (InpInstanceID > 1) ? StringFormat(" #%d", InpInstanceID) : "";
   string name     = StringFormat("Rejection Blocks%s(L%d, ATR%d)%s", tf_str, InpSwingLength, InpAtrLength, inst_str);
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
   int min_bars = MathMax(InpSwingLength * 2 + 1, InpAtrLength + 5);
   if(rates_total < min_bars || !g_engine)
      return 0;

// Force chronological indexing
   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

//===================================================================
// MODE 1: Direct Current Timeframe Calculation (Zero-Lag O(1))
//===================================================================
   if(!g_is_mtf_mode)
     {
      // 1. Calculate Engine
      g_engine.Calculate(rates_total, prev_calculated, time, open, high, low, close, BufBullSig, BufBearSig);

      // 2. Throttled GUI Rendering (Caps DirectX flushes on live ticks)
      ulong cur_ms = GetTickCount64();
      if(prev_calculated == 0 || (cur_ms - g_last_render_ms >= 250))
        {
         RenderBlocks();
         g_last_render_ms = cur_ms;
         ChartRedraw(0);
        }

      return rates_total;
     }

//===================================================================
// MODE 2: Multi-Timeframe Engine (High-Performance Fast-Path)
//===================================================================
   int required_bars_mtf = min_bars + 10;
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
         ArrayResize(h_time,       g_htf_count);
         ArrayResize(h_open,       g_htf_count);
         ArrayResize(h_high,       g_htf_count);
         ArrayResize(h_low,        g_htf_count);
         ArrayResize(h_close,      g_htf_count);
         ArrayResize(h_res_bull,   g_htf_count);
         ArrayResize(h_res_bear,   g_htf_count);

         ArraySetAsSeries(h_time,     false);
         ArraySetAsSeries(h_open,     false);
         ArraySetAsSeries(h_high,     false);
         ArraySetAsSeries(h_low,      false);
         ArraySetAsSeries(h_close,    false);
         ArraySetAsSeries(h_res_bull, false);
         ArraySetAsSeries(h_res_bear, false);
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

      // Compute HTF Blocks on HTF Domain
      g_engine.Calculate(g_htf_count, 0, h_time, h_open, h_high, h_low, h_close, h_res_bull, h_res_bear);
      g_data_ready = true;

      // Project Native Signal Arrows via Two-Pointer Chronological Sweep
      int htf_ptr = 0;
      datetime oldest_htf = h_time[0];

      for(int i = 0; i < rates_total; i++)
        {
         datetime t = time[i];
         if(t < oldest_htf)
           {
            BufBullSig[i] = EMPTY_VALUE;
            BufBearSig[i] = EMPTY_VALUE;
            continue;
           }

         while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
            htf_ptr++;

         if(t == h_time[htf_ptr])
           {
            BufBullSig[i] = h_res_bull[htf_ptr];
            BufBearSig[i] = h_res_bear[htf_ptr];
           }
         else
           {
            BufBullSig[i] = EMPTY_VALUE;
            BufBearSig[i] = EMPTY_VALUE;
           }
        }

      RenderBlocks();
      ChartRedraw(0);
      return rates_total;
     }

   if(!g_data_ready)
      return 0;

// B) LIVE TICK FAST-PATH: HTF bar did not close. Update forming candle in RAM!
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

         g_engine.Calculate(g_htf_count, g_htf_count, h_time, h_open, h_high, h_low, h_close, h_res_bull, h_res_bear);

         ulong cur_ms = GetTickCount64();
         if(cur_ms - g_last_render_ms >= 250)
           {
            RenderBlocks();
            g_last_render_ms = cur_ms;
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
   int min_bars = MathMax(InpSwingLength * 2 + 1, InpAtrLength + 5);
   int required_bars_mtf = min_bars + 15;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars_mtf, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
