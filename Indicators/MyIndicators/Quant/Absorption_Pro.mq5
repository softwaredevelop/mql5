//+------------------------------------------------------------------+
//|                                               Absorption_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.22" // Upgraded with subtle pastel watermark MQL5 colors for multi-template support
#property description "Institutional Absorption Detector."
#property description "Draws Supply/Demand zones & Outputs State Buffer with soft pastel styling."

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2

//--- Plot 1: Bull Arrow (Dodger Blue)
#property indicator_label1  "Bull Abs"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

//--- Plot 2: Bear Arrow (Crimson Red)
#property indicator_label2  "Bear Abs"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>

//--- Input Parameters
input group "--- Indicator Settings ---"
input int      InpATRPeriod      = 14;   // ATR Period
input int      InpRVOLPeriod     = 20;   // RVOL Period (Relative Volume)
input int      InpHistoryBars    = 500;  // Limit object creation history (Bars)
input bool     InpShowObjects    = true; // Toggle zone and rectangle visuals

//--- Buffers
double BufBull[];
double BufBear[];
double BufATR[];
double BufRVOL[];
double BufState[]; // 0=None, 1=Bull, -1=Bear, 2=Climax, 0.5=Neut

CATRCalculator            *g_atr;
CRelativeVolumeCalculator *g_rvol;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind Buffers to index mapping
   SetIndexBuffer(0, BufBull,  INDICATOR_DATA);
   SetIndexBuffer(1, BufBear,  INDICATOR_DATA);
   SetIndexBuffer(2, BufATR,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufRVOL,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufState, INDICATOR_CALCULATIONS);

//--- Enforce strict chronological alignment (false = old to new) on dynamic buffers
   ArraySetAsSeries(BufBull,  false);
   ArraySetAsSeries(BufBear,  false);
   ArraySetAsSeries(BufATR,   false);
   ArraySetAsSeries(BufRVOL,  false);
   ArraySetAsSeries(BufState, false);

//--- Arrow Styles (Wingdings wing arrows)
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);

//--- Instantiate Calculators
   g_atr = new CATRCalculator();
   if(CheckPointer(g_atr) != POINTER_INVALID)
      g_atr.Init(InpATRPeriod, ATR_POINTS);

   g_rvol = new CRelativeVolumeCalculator();
   if(CheckPointer(g_rvol) != POINTER_INVALID)
      g_rvol.Init(InpRVOLPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME, "Absorption Pro");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   ObjectsDeleteAll(0, "AbsZone_");
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
   if(rates_total < InpATRPeriod + InpRVOLPeriod)
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

//--- Calculate Volatility and Relative Volume indicators
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, BufATR);
   g_rvol.Calculate(rates_total, prev_calculated, tick_volume, BufRVOL);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpATRPeriod + InpRVOLPeriod;

//--- Limit loop to history bars limit to prevent terminal lag
   int draw_limit = rates_total - InpHistoryBars;
   if(draw_limit < 0)
      draw_limit = 0;
   if(start < draw_limit)
      start = draw_limit;

   for(int i = start; i < rates_total; i++)
     {
      BufBull[i]  = EMPTY_VALUE;
      BufBear[i]  = EMPTY_VALUE;
      BufState[i] = 0.0;

      double atr = BufATR[i];
      if(atr <= 0.0)
         continue;

      double body = MathAbs(close[i] - open[i]);
      double total_range = high[i] - low[i];
      double rvol = BufRVOL[i];

      bool is_bull   = false;
      bool is_bear   = false;
      bool is_climax = false;

      //--- Quantitative VSA rules
      bool high_effort = (rvol > 2.0);
      bool low_result  = (body < (0.35 * atr));

      if(high_effort && low_result)
        {
         double close_pos = 0.5;
         if(total_range > 0.0)
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

      //--- Render Visuals & Graphical Objects
      if(is_bull || is_bear || is_climax)
        {
         if(InpShowObjects)
           {
            // Arrows Setup
            if(is_bull)
               BufBull[i] = low[i] - atr * 0.3;
            if(is_bear)
               BufBear[i] = high[i] + atr * 0.3;

            // ZONES (Rectangles) using soft, transparent-like native MQL5 pastel colors
            string name = "AbsZone_" + TimeToString(time[i]);
            color zone_col = is_bull ? clrLightSteelBlue : (is_bear ? clrMistyRose : clrWheat);

            // Create rectangle if not already exists on active chart
            if(ObjectFind(0, name) < 0)
              {
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], high[i], time[i], low[i]);
               ObjectSetInteger(0, name, OBJPROP_COLOR, zone_col);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); // Borderless style
              }

            // Forward scan looking for the break candle
            datetime end_time = time[rates_total - 1] + PeriodSeconds() * 5; // Default: Live bar
            bool broken = false;

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

            // Update zone ending time anchor
            ObjectSetInteger(0, name, OBJPROP_TIME, 1, end_time);

            // Adjust border style if zone was broken by price
            if(broken)
               ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
