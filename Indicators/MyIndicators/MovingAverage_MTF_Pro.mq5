//+------------------------------------------------------------------+
//|                                        MovingAverage_MTF_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Optimized for incremental MTF calculation
#property description "Multi-Timeframe (MTF) Universal Moving Average."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "MA MTF"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#include <MyIncludes\MovingAverage_Engine.mqh>

//--- Input Parameters ---
input ENUM_TIMEFRAMES           InpUpperTimeframe = PERIOD_CURRENT;
input int                       InpPeriod         = 20;
input ENUM_MA_TYPE              InpMAType         = SMA;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice    = PRICE_CLOSE_STD;

//--- Indicator Buffers ---
double    BufferMA_MTF[];

//--- Internal Buffer for HTF Calculation (Must be global to persist state)
double    BufferMA_HTF_Internal[];

//--- Global variables ---
CMovingAverageCalculator *g_calculator;
bool                      g_is_mtf_mode = false;
ENUM_TIMEFRAMES           g_calc_timeframe;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
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
   SetIndexBuffer(0, BufferMA_MTF, INDICATOR_DATA);
   ArraySetAsSeries(BufferMA_MTF, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Initialize Calculator
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      g_calculator = new CMovingAverageCalculator_HA();
   else
      g_calculator = new CMovingAverageCalculator();

   if(CheckPointer(g_calculator) == POINTER_INVALID || !g_calculator.Init(InpPeriod, InpMAType))
     {
      Print("Failed to initialize Moving Average Calculator.");
      return(INIT_FAILED);
     }

//--- Set Short Name
   string ma_name = EnumToString(InpMAType);
   StringToUpper(ma_name);
   string short_name;
   if(g_is_mtf_mode)
      short_name = StringFormat("%s MTF%s(%s,%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), EnumToString(g_calc_timeframe), InpPeriod);
   else
      short_name = StringFormat("%s%s(%d)", ma_name, (InpSourcePrice <= PRICE_HA_CLOSE ? " HA" : ""), InpPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) != POINTER_INVALID)
      delete g_calculator;

// Free internal memory
   ArrayFree(BufferMA_HTF_Internal);
  }

//+------------------------------------------------------------------+
//| Calculation function                                             |
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
      if(htf_rates_total < InpPeriod)
         return 0;

      //--- 2. Manage HTF State (Incremental Logic)
      static int htf_prev_calculated = 0;

      // Reset if chart was reset
      if(prev_calculated == 0)
         htf_prev_calculated = 0;

      //--- 3. Fetch HTF Data
      // We copy the full history for data integrity, but the Calculator will optimize the math.
      // Copying simple arrays is fast in MT5.
      datetime htf_time[];
      double htf_open[], htf_high[], htf_low[], htf_close[];

      // Only copy if we have new data or need full recalc
      // For robustness, we copy full range, but we could optimize this further.
      // Given the Engine optimization, copying is acceptable.
      if(CopyTime(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_time) <= 0 ||
         CopyOpen(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_open) <= 0 ||
         CopyHigh(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_high) <= 0 ||
         CopyLow(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_low) <= 0 ||
         CopyClose(_Symbol, g_calc_timeframe, 0, htf_rates_total, htf_close) <= 0)
         return 0;

      //--- 4. Resize Internal Buffer
      if(ArraySize(BufferMA_HTF_Internal) != htf_rates_total)
         ArrayResize(BufferMA_HTF_Internal, htf_rates_total);

      //--- 5. Calculate on HTF (Optimized)
      // Pass htf_prev_calculated so the engine skips already calculated bars!
      g_calculator.Calculate(htf_rates_total, htf_prev_calculated, price_type, htf_open, htf_high, htf_low, htf_close, BufferMA_HTF_Internal);

      // Update state
      htf_prev_calculated = htf_rates_total;

      //--- 6. Map to Current Timeframe (Optimized Loop)
      // We need to access time[] as series for iBarShift usually, but let's stick to linear mapping
      // Standard iBarShift works with time.

      ArraySetAsSeries(htf_time, true);            // HTF time as series for search? No, CopyTime is non-series by default.
      ArraySetAsSeries(BufferMA_HTF_Internal, true); // Set as series to match iBarShift index logic (0 is newest)
      ArraySetAsSeries(time, true);                // Current time as series
      ArraySetAsSeries(BufferMA_MTF, true);        // Output as series

      // Determine where to start mapping
      int limit = (prev_calculated > 0) ? rates_total - prev_calculated : rates_total;
      // We iterate backwards from newest (0) to limit

      for(int i = 0; i < limit; i++)
        {
         // Find which HTF bar corresponds to the current bar time
         int htf_shift = iBarShift(_Symbol, g_calc_timeframe, time[i], false);

         if(htf_shift >= 0 && htf_shift < htf_rates_total)
           {
            // BufferMA_HTF_Internal is set as series, so htf_shift (0=newest) works directly
            BufferMA_MTF[i] = BufferMA_HTF_Internal[htf_shift];
           }
         else
           {
            BufferMA_MTF[i] = EMPTY_VALUE;
           }
        }

      // Restore array indexing to default (false)
      ArraySetAsSeries(BufferMA_HTF_Internal, false);
      ArraySetAsSeries(time, false);
      ArraySetAsSeries(BufferMA_MTF, false);
     }
//================================================================
// CURRENT TIMEFRAME MODE
//================================================================
   else
     {
      // Direct calculation with optimization
      g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, BufferMA_MTF);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
