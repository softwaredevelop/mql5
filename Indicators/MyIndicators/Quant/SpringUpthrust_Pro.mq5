//+------------------------------------------------------------------+
//|                                           SpringUpthrust_Pro.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Fixed array out of range exception and added level age filters
#property description "Professional Wyckoff Springs & Upthrusts Detector"
#property description "Flags false breakouts of trading ranges on key S/R levels."
#property indicator_chart_window
#property indicator_buffers 6  // Upgraded to 6 buffers for precise level time tracking
#property indicator_plots   2

//--- Plot 1: Bullish Spring Arrow
#property indicator_label1  "Spring (Buy)"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  2

//--- Plot 2: Bearish Upthrust Arrow
#property indicator_label2  "Upthrust (Sell)"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <MyIncludes\ATR_Calculator.mqh>
#include <MyIncludes\RelativeVolume_Calculator.mqh>
#include <MyIncludes\SpringUpthrust_Calculator.mqh>

//--- Input Parameters
input int      InpFractalPeriod   = 5;    // Fractal Peak/Trough Period (Recommended: 5)
input int      InpMinLevelAge     = 10;   // Minimum bars elapsed since level formation (Zajszűrés)
input int      InpATRPeriod       = 14;   // Volatility ATR Period
input int      InpRVOLPeriod      = 20;   // Relative Volume RVOL Period
input bool     InpDrawLevelLines  = true; // Draw the penetrated level lines?

//--- Buffers
double ExtSpringBuffer[];
double ExtUpthrustBuffer[];
double BufATR[];
double BufRVOL[];
double BufSupTime[]; // Track S_Time to prevent array out of range
double BufResTime[]; // Track R_Time to prevent array out of range

//--- Global Variables
CATRCalculator            *g_atr;
CRelativeVolumeCalculator *g_rvol;
CSpringUpthrustCalculator  *g_calc;
string                     g_prefix = "";

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_prefix = StringFormat("WYC_SUT_%I64d_", ChartID());
   ObjectsDeleteAll(0, g_prefix);

   SetIndexBuffer(0, ExtSpringBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtUpthrustBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BufATR, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, BufRVOL, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, BufSupTime, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufResTime, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(ExtSpringBuffer, false);
   ArraySetAsSeries(ExtUpthrustBuffer, false);

// Configure MT5 Arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Arrow pointing UP (Spring)
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Arrow pointing DOWN (Upthrust)

   string short_name = StringFormat("Wyckoff S&UT Pro(%d, %d)", InpFractalPeriod, InpATRPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   g_atr = new CATRCalculator();
   g_atr.Init(InpATRPeriod, ATR_POINTS);

   g_rvol = new CRelativeVolumeCalculator();
   g_rvol.Init(InpRVOLPeriod);

   g_calc = new CSpringUpthrustCalculator();
   if(CheckPointer(g_calc) == POINTER_INVALID || !g_calc.Init(InpFractalPeriod, InpMinLevelAge))
     {
      Print("Error: Failed to initialize S&UT Calculator.");
      return INIT_FAILED;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, g_prefix);
   if(CheckPointer(g_atr) == POINTER_DYNAMIC)
      delete g_atr;
   if(CheckPointer(g_rvol) == POINTER_DYNAMIC)
      delete g_rvol;
   if(CheckPointer(g_calc) == POINTER_DYNAMIC)
      delete g_calc;
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
   if(rates_total < InpFractalPeriod + InpATRPeriod + InpRVOLPeriod)
      return 0;

// Force standard chronological indexing for Strategy Tester consistency
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

// Calculate ATR and RVOL buffers
   g_atr.Calculate(rates_total, prev_calculated, open, high, low, close, BufATR);
   g_rvol.Calculate(rates_total, prev_calculated, tick_volume, BufRVOL);

// Local arrays for level output drawing
   double temp_sup_levels[];
   double temp_res_levels[];
   ArrayResize(temp_sup_levels, rates_total);
   ArrayResize(temp_res_levels, rates_total);

//--- Run the State Machine Engine
   g_calc.Calculate(rates_total, prev_calculated, time, high, low, close, BufATR, BufRVOL,
                    ExtSpringBuffer, ExtUpthrustBuffer, temp_sup_levels, temp_res_levels, BufSupTime, BufResTime);

//--- VSA Level Drawing Loop (Only on new signals)
   if(InpDrawLevelLines)
     {
      int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
      for(int i = start; i < rates_total; i++)
        {
         // 1. Draw Support Line tested by Spring
         if(ExtSpringBuffer[i] != EMPTY_VALUE && temp_sup_levels[i] > 0.0 && BufSupTime[i] > 0)
           {
            string line_name = StringFormat("%sSup_Line_%I64d", g_prefix, time[i]);
            if(ObjectFind(0, line_name) < 0)
              {
               // FIXED: Target line starts exactly from the historical level time, preventing Out-Of-Range!
               datetime start_line = (datetime)BufSupTime[i];
               ObjectCreate(0, line_name, OBJ_TREND, 0, start_line, temp_sup_levels[i], time[i], temp_sup_levels[i]);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrLimeGreen);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
              }
           }

         // 2. Draw Resistance Line tested by Upthrust
         if(ExtUpthrustBuffer[i] != EMPTY_VALUE && temp_res_levels[i] > 0.0 && BufResTime[i] > 0)
           {
            string line_name = StringFormat("%sRes_Line_%I64d", g_prefix, time[i]);
            if(ObjectFind(0, line_name) < 0)
              {
               datetime start_line = (datetime)BufResTime[i];
               ObjectCreate(0, line_name, OBJ_TREND, 0, start_line, temp_res_levels[i], time[i], temp_res_levels[i]);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrCrimson);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
              }
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
