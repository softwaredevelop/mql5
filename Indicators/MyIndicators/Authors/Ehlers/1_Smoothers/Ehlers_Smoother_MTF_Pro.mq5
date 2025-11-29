//+------------------------------------------------------------------+
//|                                     Ehlers_Smoother_MTF_Pro.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Optimized for incremental MTF calculation
#property description "Multi-Timeframe (MTF) version of John Ehlers' Smoothers."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Smoother MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlueViolet
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT;
input ENUM_SMOOTHER_TYPE        InpSmootherType   = SUPERSMOOTHER;
input int                       InpPeriod         = 20;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferFilterMTF[];

//--- Internal Buffer for HTF Calculation (Must be global to persist state)
double    BufferFilter_HTF_Internal[];

//--- Global variables ---
CEhlersSmootherCalculator *g_calculator;
bool                       g_is_mtf_mode = false;
ENUM_TIMEFRAMES            g_calc_timeframe;

//+------------------------------------------------------------------+
int OnInit()
  {
//--- Resolve Timeframe
   g_calc_timeframe = InpUpperTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

//--- Validation
   if(g_calc_timeframe < Period())
     {
      Print("Error: The selected timeframe must be higher than or equal to the current chart timeframe.");
      return(INIT_FAILED);
     }
   g_is_mtf_mode = (g_calc_timeframe > Period());

//--- Buffer Mapping
   SetIndexBuffer(0, BufferFilterMTF,  INDICATOR_DATA);
   ArraySetAsSeries(BufferFilterMTF,  false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Initialize Calculator
   string name = (InpSmootherType == SUPERSMOOTHER) ? "SuperSmoother" : "UltimateSmoother";
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CEhlersSmootherCalculator_HA();
   else
      g_calculator = new CEhlersSmootherCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpSmootherType, SOURCE_PRICE))
     {
      Print("Failed to initialize Ehlers Smoother Calculator.");
      return(INIT_FAILED);
     }

   if(g_is_mtf_mode)
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s MTF(%s,%d)", name, EnumToString(g_calc_timeframe), InpPeriod));
   else
      IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("%s(%d)", name, InpPeriod));

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 3);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

// Free internal memory
   ArrayFree(BufferFilter_HTF_Internal);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated, // <--- Now used!
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 2 || CheckPointer(g_calculator) == POINTER_INVALID)
      return 0;

   ENUM_APPLIED_PRICE price_type = (InpSourcePrice <= PRICE_HA_CLOSE) ? (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice) : (ENUM_APPLIED_PRICE)InpSourcePrice;

//================================================================
// MTF MODE
//================================================================
   if(g_is_mtf_mode)
     {
      //--- 1. Get HTF Bars Count
      int htf_rates_total = (int)SeriesInfoInteger(_Symbol, g_calc_timeframe, SERIES_BARS_COUNT);
      if(htf_rates_total < InpPeriod + 3)
         return 0;

      //--- 2. Manage HTF State (Incremental Logic)
      static int htf_prev_calculated = 0;

      // Reset if chart was reset
      if(prev_calculated == 0)
         htf_prev_calculated = 0;

      //--- 3. Fetch HTF Data
      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];

      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 ||
         CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 ||
         CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return 0;

      //--- 4. Resize Internal Buffer
      if(ArraySize(BufferFilter_HTF_Internal) != htf_rates_total)
         ArrayResize(BufferFilter_HTF_Internal, htf_rates_total);

      //--- 5. Calculate on HTF (Optimized)
      // Pass htf_prev_calculated so the engine skips already calculated bars!
      g_calculator.Calculate(htf_rates_total, htf_prev_calculated, price_type, htf_open, htf_high, htf_low, htf_close, BufferFilter_HTF_Internal);

      // Update state
      htf_prev_calculated = htf_rates_total;

      //--- 6. Map to Current Timeframe (Optimized Loop)
      ArraySetAsSeries(htf_time, true);
      ArraySetAsSeries(BufferFilter_HTF_Internal, true);
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(BufferFilterMTF, true);

      // Determine where to start mapping
      int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total;

      for(int i = 0; i < limit; i++)
        {
         int htf_bar_shift = iBarShift(_Symbol, g_calc_timeframe, time[i], false);
         if(htf_bar_shift >= 0 && htf_bar_shift < htf_rates_total)
            BufferFilterMTF[i] = BufferFilter_HTF_Internal[htf_bar_shift];
         else
            BufferFilterMTF[i] = EMPTY_VALUE;
        }

      ArraySetAsSeries(BufferFilterMTF, false);
      ArraySetAsSeries(time, false);
      ArraySetAsSeries(BufferFilter_HTF_Internal, false);
     }
//================================================================
// CURRENT TIMEFRAME MODE
//================================================================
   else
     {
      // Direct calculation with optimization
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferFilterMTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
