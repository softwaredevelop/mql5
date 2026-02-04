//+------------------------------------------------------------------+
//|                                                    RVOL_Pro.mq5  |
//|                   Relative Volume (RVOL) Professional Indicator  |
//|                                       Copyright 2026, xxxxxxxx   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.12" // Adopted standard Real Volume check
#property description "Displays volume as a ratio of its moving average."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

//--- Plot Settings
#property indicator_label1    "RVOL"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_style1    STYLE_SOLID
#property indicator_width1    2

//--- Color definitions for the histogram
#property indicator_color1    clrSilver, clrDodgerBlue, clrGold

//--- Levels
#property indicator_level1    1.5
#property indicator_level2    2.5
#property indicator_levelstyle STYLE_DOT

//--- Include Engine
#include <MyIncludes\RVOL_Calculator.mqh>

//--- Input Parameters
input group "Calculation Settings"
input int               InpPeriod      = 20;      // Lookback period for average volume
input ENUM_APPLIED_VOLUME InpVolumeType  = VOLUME_TICK; // Volume Type (Tick or Real)

input group "Visual Settings"
input double            InpLevelHigh   = 1.5;     // Level for 'High' volume
input double            InpLevelExtreme= 2.5;     // Level for 'Extreme' volume
input color             InpColorNormal = clrSilver;
input color             InpColorHigh   = clrDodgerBlue;
input color             InpColorExtreme= clrGold;

//--- Buffers
double ExtRvolBuffer[];
double ExtColorBuffer[];

//--- Global Calculator
CRVOLCalculator *g_calculator;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
// --- ADOPTED: Real Volume Availability Check (from PVI/NVI Pro) ---
   if(InpVolumeType == VOLUME_REAL && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) == 0)
     {
      Print("RVOL_Pro Error: Real Volume is not available for '", _Symbol, "'. The indicator will not be drawn. Please switch to Tick Volume.");
      return(INIT_FAILED);
     }
// --- End of Check ---

//--- Bind buffers
   SetIndexBuffer(0, ExtRvolBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtColorBuffer, INDICATOR_COLOR_INDEX);

//--- Use standard chronological array order
   ArraySetAsSeries(ExtRvolBuffer, false);
   ArraySetAsSeries(ExtColorBuffer, false);

//--- Set Plot Properties
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod);

//--- Dynamically set colors and levels from inputs
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(0, PLOT_LABEL, StringFormat("RVOL(%d)", InpPeriod));
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("RVOL(%d)", InpPeriod));

   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelExtreme);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColorNormal);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColorHigh);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColorExtreme);

//--- Initialize the calculator engine
   g_calculator = new CRVOLCalculator();
   if(!g_calculator.Init(InpPeriod))
     {
      Print("RVOL_Pro Error: Failed to initialize calculator engine.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_calculator) == POINTER_DYNAMIC)
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
   if(InpVolumeType == VOLUME_TICK)
     {
      g_calculator.Calculate(rates_total, prev_calculated, tick_volume, ExtRvolBuffer);
     }
   else
     {
      g_calculator.Calculate(rates_total, prev_calculated, volume, ExtRvolBuffer);
     }

   int limit = (prev_calculated == 0) ? InpPeriod : prev_calculated - 1;

   for(int i = limit; i < rates_total; i++)
     {
      if(ExtRvolBuffer[i] >= InpLevelExtreme)
        {
         ExtColorBuffer[i] = 2; // Index for Extreme color
        }
      else
         if(ExtRvolBuffer[i] >= InpLevelHigh)
           {
            ExtColorBuffer[i] = 1; // Index for High color
           }
         else
           {
            ExtColorBuffer[i] = 0; // Index for Normal color
           }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
