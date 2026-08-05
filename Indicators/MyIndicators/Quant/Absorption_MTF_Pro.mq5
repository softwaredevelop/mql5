//+------------------------------------------------------------------+
//|                                           Absorption_MTF_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00" // Dedicated MTF Absorption release with pure box drawing and state buffers
#property description "Institutional Multi-Timeframe Absorption Detector."
#property description "Draws Higher Timeframe Supply/Demand zones strictly on the HTF grid."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   0

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh> // Centralized MTF synchronization daemon

//--- Input Parameters
input group "--- Timeframe Settings ---"
input ENUM_TIMEFRAMES           InpTimeframe      = PERIOD_H1;            // Target Higher Timeframe (MTF)

input group "--- Indicator Settings ---"
input int                      InpATRPeriod      = 14;   // ATR Period
input int                      InpRVOLPeriod     = 20;   // RVOL Period (Relative Volume)
input int                      InpHistoryBars    = 500;  // Limit object creation history (Bars)
input bool                     InpShowObjects    = true; // Toggle zone and rectangle visuals

//--- Buffers (For calculations and iCustom export)
double BufATR[];
double BufRVOL[];
double BufState[]; // 0=None, 1=Bull, -1=Bear, 2=Climax, 0.5=Neut

//--- Internal HTF Data Caches
double    h_open[], h_high[], h_low[], h_close[], h_volume[];
double    h_res_atr[], h_res_rvol[], h_res_state[];
datetime  h_time[];

//--- Global Objects & Synchronizer State
CATRCalculator            *g_atr;
CRelativeVolumeCalculator *g_rvol;

ENUM_TIMEFRAMES g_calc_timeframe;
bool            g_data_ready          = false;
bool            g_data_synced         = false;
int             g_htf_count           = 0;
datetime        g_last_htf_time       = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_data_ready    = false;
   g_data_synced   = false;
   g_htf_count     = 0;
   g_last_htf_time = 0;

//--- 1. Resolve Timeframe and validate direction
   g_calc_timeframe = InpTimeframe;
   if(g_calc_timeframe == PERIOD_CURRENT)
      g_calc_timeframe = (ENUM_TIMEFRAMES)Period();

   if(g_calc_timeframe < Period())
     {
      PrintFormat("Critical Error: Target timeframe (%s) must be >= current timeframe (%s).",
                  EnumToString(g_calc_timeframe), EnumToString(Period()));
      return(INIT_FAILED);
     }

//--- 2. Bind Buffers to index mapping (No visual plots, calculations only)
   SetIndexBuffer(0, BufATR,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(1, BufRVOL,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, BufState, INDICATOR_CALCULATIONS);

//--- Force strict chronological alignment
   ArraySetAsSeries(BufATR,   false);
   ArraySetAsSeries(BufRVOL,  false);
   ArraySetAsSeries(BufState, false);

//--- Instantiate Calculators
   g_atr = new CATRCalculator();
   if(CheckPointer(g_atr) != POINTER_INVALID)
      g_atr.Init(InpATRPeriod, ATR_POINTS);

   g_rvol = new CRelativeVolumeCalculator();
   if(CheckPointer(g_rvol) != POINTER_INVALID)
      g_rvol.Init(InpRVOLPeriod);

//--- Setup Dynamic Shortname
   IndicatorSetString(INDICATOR_SHORTNAME, "Absorption MTF Pro (" + EnumToString(g_calc_timeframe) + ")");

//--- Initialize Timer for MTF synchronization (Required)
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "AbsZone_MTF_");
   if(CheckPointer(g_atr) != POINTER_INVALID)
      delete g_atr;
   if(CheckPointer(g_rvol) != POINTER_INVALID)
      delete g_rvol;
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
   int required_bars = InpATRPeriod + InpRVOLPeriod + 10;
   if(rates_total < required_bars)
      return 0;

   if(CheckPointer(g_atr) == POINTER_INVALID || CheckPointer(g_rvol) == POINTER_INVALID)
      return 0;

//--- Force strict chronological alignment on all input price and volume arrays
   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume,      false);

//--- Synchronize history up to the target evaluation window
   if(!CDataSync::EnsureHTFDataReady(_Symbol, g_calc_timeframe, required_bars))
     {
      g_data_synced = false;
      return 0; // Wait for next tick to let history synchronize
     }

   g_data_synced = true;

//--- Check if a new HTF candle has opened
   datetime htf_time_current = iTime(_Symbol, g_calc_timeframe, 0);
   bool htf_updated = (htf_time_current != g_last_htf_time);

   if(htf_updated || prev_calculated == 0)
     {
      g_last_htf_time = htf_time_current;

      int htf_bars = iBars(_Symbol, g_calc_timeframe);
      if(htf_bars < required_bars)
        {
         g_data_ready = false;
         return 0;
        }

      g_htf_count = MathMin(htf_bars, 3000); // Guard rails to prevent thread memory overload

      // Resize all HTF caching arrays
      ArrayResize(h_time,       g_htf_count);
      ArrayResize(h_open,       g_htf_count);
      ArrayResize(h_high,       g_htf_count);
      ArrayResize(h_low,        g_htf_count);
      ArrayResize(h_close,      g_htf_count);
      ArrayResize(h_volume,     g_htf_count);
      ArrayResize(h_res_atr,    g_htf_count);
      ArrayResize(h_res_rvol,   g_htf_count);
      ArrayResize(h_res_state,  g_htf_count);

      // Force chronological structure on high-level arrays
      ArraySetAsSeries(h_time,       false);
      ArraySetAsSeries(h_open,       false);
      ArraySetAsSeries(h_high,       false);
      ArraySetAsSeries(h_low,        false);
      ArraySetAsSeries(h_close,      false);
      ArraySetAsSeries(h_volume,     false);
      ArraySetAsSeries(h_res_atr,    false);
      ArraySetAsSeries(h_res_rvol,   false);
      ArraySetAsSeries(h_res_state,  false);

      // Copy basic pricing data
      if(CopyTime(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_time)  != g_htf_count ||
         CopyOpen(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_open)  != g_htf_count ||
         CopyHigh(_Symbol,  g_calc_timeframe, 0, g_htf_count, h_high)  != g_htf_count ||
         CopyLow(_Symbol,   g_calc_timeframe, 0, g_htf_count, h_low)   != g_htf_count ||
         CopyClose(_Symbol, g_calc_timeframe, 0, g_htf_count, h_close) != g_htf_count)
        {
         g_data_ready = false;
         return 0;
        }

      // Copy proper volume types for RVOL
      long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if(vol_limit > 0)
        {
         long temp_vol[];
         if(CopyRealVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }
      else
        {
         long temp_vol[];
         if(CopyTickVolume(_Symbol, g_calc_timeframe, 0, g_htf_count, temp_vol) == g_htf_count)
           {
            for(int i = 0; i < g_htf_count; i++)
               h_volume[i] = (double)temp_vol[i];
           }
        }

      //--- Calculate HTF baseline indicators
      g_atr.Calculate(g_htf_count, 0, h_open, h_high, h_low, h_close, h_res_atr);

      // Calculate RVOL on HTF (using long volume casting)
      long h_vol_long[];
      ArrayResize(h_vol_long, g_htf_count);
      for(int i=0; i<g_htf_count; i++)
         h_vol_long[i] = (long)h_volume[i];
      g_rvol.Calculate(g_htf_count, 0, h_vol_long, h_res_rvol);

      //--- Run Wyckoff VSA Analysis on HTF Bars
      ArrayInitialize(h_res_state, 0.0);

      g_data_ready = true;
     }

   if(!g_data_ready)
      return 0;

//--- 5. Real-Time Update for the active forming HTF candle (Index: g_htf_count - 1) on every tick
   int live_idx = g_htf_count - 1;
   if(live_idx >= required_bars)
     {
      double o[1], h[1], l[1], c[1];
      long v[1];
      int shift = iBarShift(_Symbol, g_calc_timeframe, htf_time_current, false);
      if(shift >= 0 &&
         CopyOpen(_Symbol,  g_calc_timeframe, shift, 1, o) == 1 &&
         CopyHigh(_Symbol,  g_calc_timeframe, shift, 1, h) == 1 &&
         CopyLow(_Symbol,   g_calc_timeframe, shift, 1, l) == 1 &&
         CopyClose(_Symbol, g_calc_timeframe, shift, 1, c) == 1)
        {
         h_open[live_idx]  = o[0];
         h_high[live_idx]  = h[0];
         h_low[live_idx]   = l[0];
         h_close[live_idx] = c[0];

         long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
         if(vol_limit > 0)
           {
            if(CopyRealVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }
         else
           {
            if(CopyTickVolume(_Symbol, g_calc_timeframe, shift, 1, v) == 1)
               h_volume[live_idx] = (double)v[0];
           }

         // Stateful, O(1) mock update for the live HTF bar
         g_atr.Calculate(g_htf_count, g_htf_count, h_open, h_high, h_low, h_close, h_res_atr);

         long h_vol_long[];
         ArrayResize(h_vol_long, g_htf_count);
         for(int i=0; i<g_htf_count; i++)
            h_vol_long[i] = (long)h_volume[i];
         g_rvol.Calculate(g_htf_count, g_htf_count, h_vol_long, h_res_rvol);
        }
     }

//--- 6. Perform VSA classification and draw objects STRICTLY on HTF Grid
   int htf_start_calc = (prev_calculated > 0) ? g_htf_count - 2 : required_bars;
   if(htf_start_calc < required_bars)
      htf_start_calc = required_bars;

   datetime cutoff_time = TimeCurrent() - InpHistoryBars * PeriodSeconds();

   for(int i = htf_start_calc; i < g_htf_count; i++)
     {
      h_res_state[i] = 0.0;

      double atr = h_res_atr[i];
      if(atr <= 0.0)
         continue;

      double body = MathAbs(h_close[i] - h_open[i]);
      double total_range = h_high[i] - h_low[i];
      double r_vol = h_res_rvol[i];

      bool is_bull   = false;
      bool is_bear   = false;
      bool is_climax = false;

      // Quantitative VSA rules on HTF
      bool high_effort = (r_vol > 2.0);
      bool low_result  = (body < (0.35 * atr));

      if(high_effort && low_result)
        {
         double close_pos = 0.5;
         if(total_range > 0.0)
            close_pos = (h_close[i] - h_low[i]) / total_range;

         if(close_pos > 0.66)
           {
            h_res_state[i] = 1.0;
            is_bull = true;
           }
         else
            if(close_pos < 0.33)
              {
               h_res_state[i] = -1.0;
               is_bear = true;
              }
            else
              {
               h_res_state[i] = 0.5;
              }
        }
      else
         if(r_vol > 3.5 && body < (0.6 * atr))
           {
            h_res_state[i] = 2.0;
            is_climax = true;
           }

      // Object drawing strictly on HTF Grid for absolute stability!
      if((is_bull || is_bear || is_climax) && h_time[i] >= cutoff_time)
        {
         if(InpShowObjects)
           {
            string name = "AbsZone_MTF_" + TimeToString(h_time[i]);
            color zone_col = is_bull ? clrLightSteelBlue : (is_bear ? clrMistyRose : clrWheat);

            if(ObjectFind(0, name) < 0)
              {
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, h_time[i], h_high[i], h_time[i], h_low[i]);
               ObjectSetInteger(0, name, OBJPROP_COLOR, zone_col);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
              }

            // Scan forward strictly on HTF bars to ensure absolute stability!
            datetime end_time = h_time[g_htf_count - 1] + PeriodSeconds(g_calc_timeframe) * 5;
            bool broken = false;

            for(int k = i + 1; k < g_htf_count; k++)
              {
               if(is_bull && h_close[k] < h_low[i])
                 {
                  end_time = h_time[k];
                  broken = true;
                  break;
                 }
               if(is_bear && h_close[k] > h_high[i])
                 {
                  end_time = h_time[k];
                  broken = true;
                  break;
                 }
               if(is_climax && (h_close[k] > h_high[i] || h_close[k] < h_low[i]))
                 {
                  end_time = h_time[k];
                  broken = true;
                  break;
                 }
              }

            ObjectSetInteger(0, name, OBJPROP_TIME, 1, end_time);
            if(broken)
               ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
           }
        }
     }

//--- 7. Warp-free step force (Staircase Solution anchor determination)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   int first_bar_of_forming_htf = rates_total - 1;
   while(first_bar_of_forming_htf > 0 &&
         iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
     {
      first_bar_of_forming_htf--;
     }
   first_bar_of_forming_htf++; // Anchor set to start of current HTF period block

   if(start > first_bar_of_forming_htf)
      start = first_bar_of_forming_htf;

//--- 8. Map HTF Calculated results cleanly to the lower chart timeframe (O(1) complexity)
   for(int i = start; i < rates_total; i++)
     {
      datetime t = time[i];
      int shift_htf = iBarShift(_Symbol, g_calc_timeframe, t, false);

      if(shift_htf >= 0)
        {
         int idx_htf = g_htf_count - 1 - shift_htf;
         if(idx_htf >= 0 && idx_htf < g_htf_count)
           {
            BufATR[i]   = h_res_atr[idx_htf];
            BufRVOL[i]  = h_res_rvol[idx_htf];
            BufState[i] = h_res_state[idx_htf];
           }
         else
           {
            BufATR[i] = EMPTY_VALUE;
            BufRVOL[i] = EMPTY_VALUE;
            BufState[i] = 0.0;
           }
        }
      else
        {
         BufATR[i] = EMPTY_VALUE;
         BufRVOL[i] = EMPTY_VALUE;
         BufState[i] = 0.0;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Delegate asynchronous history checking and forced redraws to DataSync daemon using correct lookback period
   int required_bars = InpATRPeriod + InpRVOLPeriod + 10;
   CDataSync::OnTimerUpdate(_Symbol, g_calc_timeframe, required_bars, g_data_synced);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
