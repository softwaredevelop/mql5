//+------------------------------------------------------------------+
//|                                               Absorption_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.10"
#property description "Institutional Absorption Detector."
#property description "Draws Supply/Demand zones & Outputs State Buffer."

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2

// Plot 1: Bull Arrow
#property indicator_label1  "Bull Abs"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

// Plot 2: Bear Arrow
#property indicator_label2  "Bear Abs"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Parameters
input int      InpATRPeriod      = 14;
input int      InpRVOLPeriod     = 20;
input int      InpHistoryBars    = 500; // Limit object creation history
input bool     InpShowObjects    = true; // Toggle visuals

//--- Buffers
double BufBull[];
double BufBear[];
double BufATR[];
double BufRVOL[];
double BufState[]; // 0=None, 1=Bull, -1=Bear, 2=Climax, 0.5=Neut

CATRCalculator            *g_atr;
CRelativeVolumeCalculator *g_rvol;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufBull, INDICATOR_DATA);
   SetIndexBuffer(1, BufBear, INDICATOR_DATA);
   SetIndexBuffer(2, BufATR, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufRVOL, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufState, INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);
   g_rvol = new CRelativeVolumeCalculator();
   g_rvol.Init(InpRVOLPeriod);

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
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < InpATRPeriod + InpRVOLPeriod)
      return 0;

   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, BufATR);
   g_rvol.Calculate(rates_total, prev_calculated, tick_volume, BufRVOL);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpATRPeriod + InpRVOLPeriod;

// Limit Drawing loop to history bars to avoid lag on recompiles with huge history
   int draw_limit = rates_total - InpHistoryBars;
   if(draw_limit < 0)
      draw_limit = 0;
   if(start < draw_limit)
      start = draw_limit;

   for(int i = start; i < rates_total; i++)
     {
      BufBull[i] = EMPTY_VALUE;
      BufBear[i] = EMPTY_VALUE;
      BufState[i] = 0;

      double atr = BufATR[i];
      if(atr == 0)
         continue;

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
           {
            BufState[i] = 1.0;
            is_bull = true;
           }
         else
            if(close_pos < 0.33)
              {
               BufState[i] = -1.0;
               is_bear = true;
              }
            else
              {
               BufState[i] = 0.5;
              }
        }
      else
         if(rvol > 3.5 && body < (0.6 * atr))
           {
            BufState[i] = 2.0;
            is_climax = true;
           }

      // Visuals & Objects
      if(is_bull || is_bear || is_climax)
        {
         if(InpShowObjects)
           {
            // Arrows
            if(is_bull)
               BufBull[i] = low[i] - atr*0.3;
            if(is_bear)
               BufBear[i] = high[i] + atr*0.3;

            // ZONES (Rectangles)
            string name = "AbsZone_" + TimeToString(time[i]);
            color zone_col = is_bull ? C'0,64,0' : (is_bear ? C'64,0,0' : C'184,134,11'); // Dark Green/Red/Gold

            // Create if not exists
            if(ObjectFind(0, name) < 0)
              {
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], high[i], time[i], low[i]);
               ObjectSetInteger(0, name, OBJPROP_COLOR, zone_col);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); // Borderless look if fill
              }

            // Extend Logic: Find breaker candle
            datetime end_time = time[rates_total-1] + PeriodSeconds()*5; // Default: Live
            bool broken = false;

            // Scan forward from signal bar
            for(int k = i + 1; k < rates_total; k++)
              {
               if(is_bull && close[k] < low[i])
                 {
                  end_time = time[k];
                  broken = true;
                  break;
                 }
               if(is_bear && close[k] > high[i])
                 {
                  end_time = time[k];
                  broken = true;
                  break;
                 }
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

            // Update Time2
            ObjectSetInteger(0, name, OBJPROP_TIME, 1, end_time);
            // Optional: Change style if broken
            if(broken)
               ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
