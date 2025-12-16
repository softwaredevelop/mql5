//+------------------------------------------------------------------+
//|                                               VIDYA_MTF_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.20" // Optimized for incremental MTF calculation
#property description "Multi-Timeframe (MTF) Variable Index Dynamic Average (VIDYA)."

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "VIDYA MTF"

//--- Include the calculator engine ---
#include <MyIncludes\VIDYA_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT; // Default to current timeframe
input int                       InpPeriodCMO    = 9;
input int                       InpPeriodEMA    = 12;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferVIDYA_MTF[];

//--- Internal Buffer for HTF Calculation (Global to persist state)
double    BufferVIDYA_HTF_Internal[];

//--- Global variables ---
CVIDYACalculator *g_calculator;
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
      Print("Error: The selected timeframe must be higher than or equal to the current chart timeframe.");
      return(INIT_FAILED);
     }

   g_is_mtf_mode = (g_calc_timeframe > Period());

// --- Standard buffer setup ---
   SetIndexBuffer(0, BufferVIDYA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferVIDYA_MTF, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CVIDYACalculator_HA();
   else
      g_calculator = new CVIDYACalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriodCMO, InpPeriodEMA))
     {
      Print("Failed to create or initialize VIDYA Calculator object.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA MTF(%s,%d,%d)", EnumToString(g_calc_timeframe), InpPeriodCMO, InpPeriodEMA));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("VIDYA(%d,%d)", InpPeriodCMO, InpPeriodEMA));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriodCMO + InpPeriodEMA);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

   ArrayFree(BufferVIDYA_HTF_Internal);
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
      if(htf_rates_total < InpPeriodCMO + InpPeriodEMA)
         return 0;

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

      if(ArraySize(BufferVIDYA_HTF_Internal) != htf_rates_total)
         ArrayResize(BufferVIDYA_HTF_Internal, htf_rates_total);

      // Incremental Calculation on HTF
      g_calculator.Calculate(htf_rates_total, htf_prev_calculated, price_type, htf_open, htf_high, htf_low, htf_close, BufferVIDYA_HTF_Internal);

      htf_prev_calculated = htf_rates_total;

      // Mapping (Optimized Loop)
      ArraySetAsSeries(BufferVIDYA_HTF_Internal, true);
      ArraySetAsSeries(htf_time, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferVIDYA_MTF, true);

      int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total;

      for(int i = 0; i < limit; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i], false);
         if(htf_bar_shift < htf_rates_total && htf_bar_shift >= 0)
            BufferVIDYA_MTF[i] = BufferVIDYA_HTF_Internal[htf_bar_shift];
         else
            BufferVIDYA_MTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferVIDYA_MTF, false);
      ArraySetAsSeries(time, false);
      ArraySetAsSeries(BufferVIDYA_HTF_Internal, false);
     }
   else
     {
      // --- Current Timeframe Mode ---
      // Incremental Calculation
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferVIDYA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
