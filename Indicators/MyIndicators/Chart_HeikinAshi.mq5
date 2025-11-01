//+------------------------------------------------------------------+
//|                                           Chart_HeikinAshi.mq5   |
//|                      Copyright 2025, xxxxxxxx                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "3.01" // Added DRAW_NONE plot to hide main series and prevent flickering
#property description "Draws Heikin Ashi candles on the main chart."

//--- Custom Toolkit Include ---
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 8       // 4 for HA candles, 4 for the hidden main series
#property indicator_plots   2       // 1 for HA candles, 1 hidden plot

//--- Plot 1: Heikin Ashi Candles (Visible)
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrCornflowerBlue, clrChocolate // Up and Down colors
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"

//--- Plot 2: Main Price Series (Hidden)
#property indicator_type2   DRAW_NONE
#property indicator_label2  "OHLC" // Label for Data Window

//--- Indicator Buffers ---
// Buffers for Heikin Ashi
double    BufferHA_Open[];
double    BufferHA_High[];
double    BufferHA_Low[];
double    BufferHA_Close[];
double    BufferColor[];

// Buffers for the hidden main series plot
double    BufferMain_Open[];
double    BufferMain_High[];
double    BufferMain_Low[];
double    BufferMain_Close[];


//--- Global Objects ---
CHeikinAshi_Calculator *g_ha_calculator;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map the Heikin Ashi buffers
   SetIndexBuffer(0, BufferHA_Open,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferHA_High,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferHA_Low,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferHA_Close, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColor,    INDICATOR_COLOR_INDEX);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1); // Start drawing HA from the second bar

//--- Map the hidden main series buffers
   SetIndexBuffer(5, BufferMain_Open,  INDICATOR_DATA);
   SetIndexBuffer(6, BufferMain_High,  INDICATOR_DATA);
   SetIndexBuffer(7, BufferMain_Low,   INDICATOR_DATA);
   SetIndexBuffer(8, BufferMain_Close, INDICATOR_DATA);
// No PLOT_DRAW_BEGIN needed for DRAW_NONE

//--- Set all buffers to non-timeseries for stable calculation
   ArraySetAsSeries(BufferHA_Open,  false);
   ArraySetAsSeries(BufferHA_High,  false);
   ArraySetAsSeries(BufferHA_Low,   false);
   ArraySetAsSeries(BufferHA_Close, false);
   ArraySetAsSeries(BufferColor,    false);
   ArraySetAsSeries(BufferMain_Open,  false);
   ArraySetAsSeries(BufferMain_High,  false);
   ArraySetAsSeries(BufferMain_Low,   false);
   ArraySetAsSeries(BufferMain_Close, false);

//--- Set indicator properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "Heikin Ashi");

//--- Create the calculator instance
   g_ha_calculator = new CHeikinAshi_Calculator();
   if(CheckPointer(g_ha_calculator) == POINTER_INVALID)
     {
      Print("Error creating CHeikinAshi_Calculator object");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_ha_calculator) != POINTER_INVALID)
     {
      delete g_ha_calculator;
      g_ha_calculator = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Heikin Ashi calculation function.                                |
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
   if(rates_total < 2)
      return(0);

//--- STEP 1: Hide the main series by copying data to the DRAW_NONE plot
   ArrayCopy(BufferMain_Open,  open,  0, 0, rates_total);
   ArrayCopy(BufferMain_High,  high,  0, 0, rates_total);
   ArrayCopy(BufferMain_Low,   low,   0, 0, rates_total);
   ArrayCopy(BufferMain_Close, close, 0, 0, rates_total);

//--- STEP 2: Calculate Heikin Ashi bars
   g_ha_calculator.Calculate(rates_total, open, high, low, close,
                             BufferHA_Open, BufferHA_High, BufferHA_Low, BufferHA_Close);

//--- STEP 3: Set the colors for the Heikin Ashi candles
   for(int i = 0; i < rates_total; i++)
     {
      if(BufferHA_Open[i] < BufferHA_Close[i])
         BufferColor[i] = 0; // Index for the first color (clrCornflowerBlue)
      else
         BufferColor[i] = 1; // Index for the second color (clrChocolate)
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
