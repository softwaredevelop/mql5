//+------------------------------------------------------------------+
//|                                            Gann_HiLo_MTF_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.30" // Updated to use ENUM_MA_TYPE
#property description "Multi-Timeframe (MTF) Gann HiLo Activator."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot 1: Gann HiLo line
#property indicator_label1  "Gann_HiLo MTF"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrMediumSeaGreen, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Include the calculator engine ---
#include <MyIncludes\GannHiLo_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group "Timeframe Settings"
input ENUM_TIMEFRAMES    InpUpperTimeframe = PERIOD_H1;     // Target Timeframe

input group "Gann HiLo Settings"
input int                InpPeriod       = 10;              // Period for High/Low averages
// UPDATED: Use ENUM_MA_TYPE
input ENUM_MA_TYPE       InpMAMethod     = SMA;             // Method for High/Low averages
input ENUM_CANDLE_SOURCE InpCandleSource = CANDLE_STANDARD; // Candle source

//--- Indicator Buffers ---
double    BufferGannHiLo_MTF[];
double    BufferColor_MTF[];

//--- MTF Globals (State & Data) ---
double    g_htf_hilo[];         // Internal buffer for HTF HiLo values
double    g_htf_color[];        // Internal buffer for HTF Color indexes
int       g_htf_prev_calculated = 0;
double    g_buf_open[], g_buf_high[], g_buf_low[], g_buf_close[]; // HTF Price Data

//--- Global variables ---
CGannHiLoCalculator *g_calculator;
bool                 g_is_mtf_mode = false;
ENUM_TIMEFRAMES      g_calc_timeframe;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 1. Resolve Timeframe
   g_calc_timeframe = InpUpperTimeframe;
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
   SetIndexBuffer(0, BufferGannHiLo_MTF, INDICATOR_DATA);
   SetIndexBuffer(1, BufferColor_MTF, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufferGannHiLo_MTF, false); // Standard indexing
   ArraySetAsSeries(BufferColor_MTF, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- 3. Initialize Calculator
   switch(InpCandleSource)
     {
      case CANDLE_HEIKIN_ASHI:
         g_calculator = new CGannHiLoCalculator_HA();
         break;
      default:
         g_calculator = new CGannHiLoCalculator();
         break;
     }

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAMethod))
     {
      Print("Failed to initialize Gann HiLo Calculator.");
      return(INIT_FAILED);
     }

//--- 4. Set Shortname
   string type = (InpCandleSource == CANDLE_HEIKIN_ASHI) ? " HA" : "";
   string tf_str = g_is_mtf_mode ? (" " + EnumToString(g_calc_timeframe)) : "";
   string ma_str = EnumToString(InpMAMethod);

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("GannHiLo%s%s(%d,%s)", type, tf_str, InpPeriod, ma_str));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
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
   if(rates_total < InpPeriod)
      return(0);

//================================================================
// MODE 1: Current Timeframe (Standard)
//================================================================
   if(!g_is_mtf_mode)
     {
      g_calculator.Calculate(rates_total, prev_calculated, open, high, low, close, BufferGannHiLo_MTF, BufferColor_MTF);
      return(rates_total);
     }

//================================================================
// MODE 2: Multi-Timeframe (MTF Engine)
//================================================================

//--- A. Get HTF Data Count
   int htf_rates_total = iBars(_Symbol, g_calc_timeframe);
   if(htf_rates_total < InpPeriod)
      return(0);

//--- B. Reset HTF State if Full Recalculation needed
   if(prev_calculated == 0)
     {
      g_htf_prev_calculated = 0;
      ArrayInitialize(BufferGannHiLo_MTF, EMPTY_VALUE);
      ArrayInitialize(BufferColor_MTF, EMPTY_VALUE);
     }

//--- C. Fetch HTF Price Data
   if(CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_open) < 0 ||
      CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_high) < 0 ||
      CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_low) < 0 ||
      CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, g_buf_close) < 0)
     {
      return(0); // Data not ready
     }

//--- D. Resize HTF Buffers
   if(ArraySize(g_htf_hilo) != htf_rates_total)
     {
      ArrayResize(g_htf_hilo, htf_rates_total);
      ArrayResize(g_htf_color, htf_rates_total);
     }

//--- E. Calculate HTF Gann HiLo (Incremental)
   int htf_calc_start = (g_htf_prev_calculated > 0) ? g_htf_prev_calculated - 1 : 0;

   g_calculator.Calculate(htf_rates_total, htf_calc_start,
                          g_buf_open, g_buf_high, g_buf_low, g_buf_close,
                          g_htf_hilo, g_htf_color);

   g_htf_prev_calculated = htf_rates_total;

//--- F. Map HTF Values to Current Chart (The "Staircase")
   ArraySetAsSeries(g_htf_hilo, true);
   ArraySetAsSeries(g_htf_color, true);
   ArraySetAsSeries(time, false);

   int limit = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = limit; i < rates_total; i++)
     {
      datetime current_time = time[i];
      int htf_index = iBarShift(_Symbol, g_calc_timeframe, current_time, false);

      if(htf_index >= 0 && htf_index < htf_rates_total)
        {
         BufferGannHiLo_MTF[i] = g_htf_hilo[htf_index];
         BufferColor_MTF[i]    = g_htf_color[htf_index];
        }
      else
        {
         BufferGannHiLo_MTF[i] = EMPTY_VALUE;
         BufferColor_MTF[i]    = EMPTY_VALUE;
        }
     }

   ArraySetAsSeries(g_htf_hilo, false);
   ArraySetAsSeries(g_htf_color, false);

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
