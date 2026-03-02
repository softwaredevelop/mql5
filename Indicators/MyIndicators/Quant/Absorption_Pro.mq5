//+------------------------------------------------------------------+
//|                                               Absorption_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Institutional Absorption Detector (Wyckoff)."
#property description "Draws Supply/Demand zones based on Volume/Price anomalies."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

// Use arrow buffers just to mark the signal bar visually on top/bottom
#property indicator_label1  "Bull Abs"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Bear Abs"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Parameters
input int      InpATRPeriod      = 14;       // Volatility Period
input int      InpRVOLPeriod     = 20;       // Volume Period
input int      InpHistoryBars    = 500;      // Max Bars to analyze (for objects)

//--- Buffers
double BufBull[];
double BufBear[];
double BufATR[];  // Internal
double BufRVOL[]; // Internal

//--- Objects
CATRCalculator            *g_atr;
CRelativeVolumeCalculator *g_rvol;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufBull, INDICATOR_DATA);
   SetIndexBuffer(1, BufBear, INDICATOR_DATA);
   SetIndexBuffer(2, BufATR, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufRVOL, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow

   g_atr = new CATRCalculator();
   if(!g_atr.Init(InpATRPeriod, ATR_POINTS))
      return INIT_FAILED;

   g_rvol = new CRelativeVolumeCalculator();
   if(!g_rvol.Init(InpRVOLPeriod))
      return INIT_FAILED;

   IndicatorSetString(INDICATOR_SHORTNAME, "Absorption Pro");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   ObjectsDeleteAll(0, "AbsZone_");
   if(CheckPointer(g_atr)==POINTER_DYNAMIC)
      delete g_atr;
   if(CheckPointer(g_rvol)==POINTER_DYNAMIC)
      delete g_rvol;
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
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
// Safety
   if(rates_total < InpATRPeriod + InpRVOLPeriod)
      return 0;

// 1. Data Prep & Calc
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, BufATR);
   g_rvol.Calculate(rates_total, prev_calculated, tick_volume, BufRVOL);

// Limit loop for objects (don't draw 100000 objects)
// Always recalc recent history to update "Open" zones
   int start = rates_total - InpHistoryBars;
   if(start < 0)
      start = 0;

// Optimization: Only create objects if not exists. But update "End Time" of active zones.
// Simplified approach: scan history, manage objects.

   for(int i = start; i < rates_total; i++)
     {
      // Reset arrow buffers
      BufBull[i] = EMPTY_VALUE;
      BufBear[i] = EMPTY_VALUE;

      double atr = BufATR[i];
      if(atr == 0)
         continue;

      // LOGIC from Script
      double body = MathAbs(close[i] - open[i]);
      double total_range = high[i] - low[i];
      double rvol = BufRVOL[i];

      bool is_bull = false;
      bool is_bear = false;
      bool is_climax = false;

      bool high_effort = (rvol > 2.0);
      bool low_result  = (body < (0.35 * atr));

      if(high_effort && low_result)
        {
         double close_pos = 0.5;
         if(total_range > 0)
            close_pos = (close[i] - low[i]) / total_range;

         if(close_pos > 0.66)
            is_bull = true;
         else
            if(close_pos < 0.33)
               is_bear = true;
            else
              {
               // Neutral Abs - maybe mark as yellow?
              }
        }
      else
         if(rvol > 3.5 && body < (0.6 * atr))
           {
            is_climax = true; // Use neutral/warning color
           }

      // Drawing Logic
      if(is_bull || is_bear || is_climax)
        {
         // Mark Arrow
         if(is_bull)
            BufBull[i] = low[i] - atr * 0.5;
         if(is_bear)
            BufBear[i] = high[i] + atr * 0.5;
         if(is_climax) { /* Maybe draw both or special? */ }

         // Create/Update Zone Object
         string name = "AbsZone_" + TimeToString(time[i]);
         color zone_col = is_bull ? clrGreen : (is_bear ? clrRed : clrGold);
         if(is_bull)
            zone_col = C'0,64,0'; // Darker Green for fill
         if(is_bear)
            zone_col = C'64,0,0'; // Darker Red

         if(ObjectFind(0, name) < 0)
           {
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], high[i], time[i], low[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, zone_col);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind candles
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
           }

         // Manage Zone Extension
         // Find if/when price broke the zone
         datetime end_time = time[rates_total-1] + PeriodSeconds()*5; // Default: Live into future

         bool broken = false;
         for(int k = i + 1; k < rates_total; k++)
           {
            // Bull Zone broken if Close < Low
            if(is_bull && close[k] < low[i])
              {
               end_time = time[k];
               broken = true;
               break;
              }
            // Bear Zone broken if Close > High
            if(is_bear && close[k] > high[i])
              {
               end_time = time[k];
               broken = true;
               break;
              }
            // Climax broken if broken either way
            if(is_climax)
              {
               if(close[k] > high[i] || close[k] < low[i])
                 {
                  end_time = time[k];
                  broken = true;
                  break;
                 }
              }
           }

         // FIX: Use Modifier Index 1 for Time2
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, end_time);

         // Visual Polish: If broken, make it lighter or dashed?
         // For now, standard rectangle.
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
