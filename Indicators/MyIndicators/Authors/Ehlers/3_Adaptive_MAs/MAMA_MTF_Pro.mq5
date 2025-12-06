//+------------------------------------------------------------------+
//|                                                  MAMA_MTF_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.30" // Fully optimized incremental MTF calculation
#property description "Multi-Timeframe (MTF) version of John Ehlers' MAMA and FAMA."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: MAMA
#property indicator_label1  "MAMA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: FAMA
#property indicator_label2  "FAMA MTF"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#include <MyIncludes\MAMA_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT; // Default to current timeframe
input double                    InpFastLimit    = 0.5;   // Fast Limit for Alpha
input double                    InpSlowLimit    = 0.05;  // Slow Limit for Alpha
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMAMA_MTF[];
double    BufferFAMA_MTF[];

//--- Internal Buffers for HTF Calculation (Global to persist state)
double    BufferMAMA_HTF_Internal[];
double    BufferFAMA_HTF_Internal[];

//--- Global variables ---
CMAMACalculator  *g_calculator;
bool              g_is_mtf_mode = false;
ENUM_TIMEFRAMES   g_calc_timeframe;

//+------------------------------------------------------------------+
int OnInit()
  {
// --- Determine calculation mode (MTF or Current) ---
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      Print("Error: The selected timeframe must be lower than the current chart timeframe.");
      return(INIT_FAILED);
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// --- Standard buffer setup ---
   SetIndexBuffer(0, BufferMAMA_MTF,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferFAMA_MTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferMAMA_MTF,  false);
   ArraySetAsSeries(BufferFAMA_MTF,  false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMAMACalculator_HA();
   else
      g_calculator = new CMAMACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpFastLimit, InpSlowLimit))
     {
      Print("Failed to create or initialize MAMA Calculator object.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA MTF(%s)", EnumToString(g_calc_timeframe)));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("MAMA(%.2f,%.2f)", InpFastLimit, InpSlowLimit));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 50);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 50);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   ArrayFree(BufferMAMA_HTF_Internal);
   ArrayFree(BufferFAMA_HTF_Internal);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

// --- Branching logic based on mode ---
   if(g_is_mtf_mode)
     {
      // --- MTF Mode ---
      int htf_rates_total = (int)SeriesInfoInteger(_Symbol, g_calc_timeframe, SERIES_BARS_COUNT);
      if(htf_rates_total < 50)
         return 0; // MAMA warmup period

      // --- Manage HTF State (Incremental Logic) ---
      static int htf_prev_calculated = 0;
      if(prev_calculated == 0)
         htf_prev_calculated = 0;

      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];

      // Optimization: We could copy only new bars, but for safety with CopyTime/BarShift,
      // copying full history on HTF is usually fast enough. The math is the bottleneck.
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 ||
         CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 ||
         CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
        {
         return 0; // Data not fully ready
        }

      if(ArraySize(BufferMAMA_HTF_Internal) != htf_rates_total)
         ArrayResize(BufferMAMA_HTF_Internal, htf_rates_total);
      if(ArraySize(BufferFAMA_HTF_Internal) != htf_rates_total)
         ArrayResize(BufferFAMA_HTF_Internal, htf_rates_total);

      // Incremental Calculation on HTF
      // We pass htf_prev_calculated so the engine only computes new bars!
      g_calculator.Calculate(htf_rates_total, htf_prev_calculated, price_type, htf_open, htf_high, htf_low, htf_close, BufferMAMA_HTF_Internal, BufferFAMA_HTF_Internal);

      htf_prev_calculated = htf_rates_total;

      // Mapping (Optimized Loop)
      ArraySetAsSeries(BufferMAMA_HTF_Internal, true);
      ArraySetAsSeries(BufferFAMA_HTF_Internal, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferMAMA_MTF, true);
      ArraySetAsSeries(BufferFAMA_MTF, true);

      int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total;

      for(int i = 0; i < limit; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i], false);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
           {
            BufferMAMA_MTF[i] = BufferMAMA_HTF_Internal[htf_bar_shift];
            BufferFAMA_MTF[i] = BufferFAMA_HTF_Internal[htf_bar_shift];
           }
         else
           {
            BufferMAMA_MTF[i] = EMPTY_VALUE;
            BufferFAMA_MTF[i] = EMPTY_VALUE;
           }
        }

      ArraySetAsSeries(BufferMAMA_MTF, false);
      ArraySetAsSeries(BufferFAMA_MTF, false);
      ArraySetAsSeries(time, false);
      ArraySetAsSeries(BufferMAMA_HTF_Internal, false);
      ArraySetAsSeries(BufferFAMA_HTF_Internal, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      // Incremental Calculation
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMAMA_MTF, BufferFAMA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
