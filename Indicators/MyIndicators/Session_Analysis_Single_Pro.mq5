//+------------------------------------------------------------------+
//|                                  Session_Analysis_Single_Pro.mq5 |
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.10" // Fixed compilation errors
#property description "Session Analysis for a SINGLE market."
#property description "Supports Pre, Core, Post, and Full sessions with VWAP buffers."

#property indicator_chart_window
// We use exactly 8 buffers for 4 sessions x 2 VWAP lines (Odd/Even)
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot Properties ---
// Session 1: Pre-Market
#property indicator_label1  "Pre VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSlateBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label2  "Pre VWAP (Seg)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSlateBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Session 2: Core Trading
#property indicator_label3  "Core VWAP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSlateBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_label4  "Core VWAP (Seg)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrSlateBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Session 3: Post-Market
#property indicator_label5  "Post VWAP"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrSlateBlue
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1
#property indicator_label6  "Post VWAP (Seg)"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrSlateBlue
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

// Session 4: Full Day
#property indicator_label7  "Full VWAP"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGray
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1
#property indicator_label8  "Full VWAP (Seg)"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrGray
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

//--- Include Engines ---
#include <MyIncludes\Session_Analysis_Calculator.mqh>
#include <MyIncludes\VWAP_Calculator.mqh>

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group "Global Settings"
input string              InpMarketName     = "NYSE"; // Market Name (Unique ID)
input bool                InpFillBoxes      = false;
input int                 InpMaxHistoryDays = 5;
input ENUM_APPLIED_VOLUME InpVolumeType     = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource   = CANDLE_STANDARD; // For VWAP
input ENUM_APPLIED_PRICE  InpSourcePrice    = PRICE_TYPICAL;   // For Mean/LinReg

//--- Pre-Market Session ---
input group "Pre-Market Session"
input bool   InpPre_Enable        = true;
input string InpPre_Start         = "06:30";
input string InpPre_End           = "09:30";
input color  InpPre_Color         = clrSlateBlue;
input bool   InpPre_ShowVWAP      = true;
input bool   InpPre_ShowMean      = false;
input bool   InpPre_ShowLinReg    = false;

//--- Core Trading Session ---
input group "Core Trading Session"
input bool   InpCore_Enable       = true;
input string InpCore_Start        = "09:30";
input string InpCore_End          = "16:00";
input color  InpCore_Color        = clrSlateBlue;
input bool   InpCore_ShowVWAP     = true;
input bool   InpCore_ShowMean     = true;
input bool   InpCore_ShowLinReg   = true;

//--- Post-Market Session ---
input group "Post-Market Session"
input bool   InpPost_Enable       = true;
input string InpPost_Start        = "16:00";
input string InpPost_End          = "20:00";
input color  InpPost_Color        = clrSlateBlue;
input bool   InpPost_ShowVWAP     = true;
input bool   InpPost_ShowMean     = false;
input bool   InpPost_ShowLinReg   = false;

//--- Full Day Analysis ---
input group "Full Day Analysis"
input bool   InpFull_Enable       = false;
input color  InpFull_Color        = clrGray;
input bool   InpFull_ShowVWAP     = true;
input bool   InpFull_ShowMean     = false;
input bool   InpFull_ShowLinReg   = false;

//--- Indicator Buffers ---
double BufferPre_Odd[], BufferPre_Even[];
double BufferCore_Odd[], BufferCore_Even[];
double BufferPost_Odd[], BufferPost_Even[];
double BufferFull_Odd[], BufferFull_Even[];

//--- Global Variables ---
#define SESSIONS_COUNT 4
CSessionAnalyzer *g_box_analyzers[SESSIONS_COUNT];
CVWAPCalculator  *g_vwap_calculators[SESSIONS_COUNT];
string g_unique_prefix;
datetime g_last_bar_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_bar_time = 0;

// --- Map Buffers ---
   SetIndexBuffer(0, BufferPre_Odd, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPre_Even, INDICATOR_DATA);
   SetIndexBuffer(2, BufferCore_Odd, INDICATOR_DATA);
   SetIndexBuffer(3, BufferCore_Even, INDICATOR_DATA);
   SetIndexBuffer(4, BufferPost_Odd, INDICATOR_DATA);
   SetIndexBuffer(5, BufferPost_Even, INDICATOR_DATA);
   SetIndexBuffer(6, BufferFull_Odd, INDICATOR_DATA);
   SetIndexBuffer(7, BufferFull_Even, INDICATOR_DATA);

// --- Set Series and Empty Values (Unrolled loop) ---
   ArraySetAsSeries(BufferPre_Odd, false);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferPre_Even, false);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferCore_Odd, false);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferCore_Even, false);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferPost_Odd, false);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferPost_Even, false);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferFull_Odd, false);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(BufferFull_Even, false);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// --- Set Colors Dynamically ---
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpPre_Color);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpPre_Color);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpCore_Color);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpCore_Color);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpPost_Color);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpPost_Color);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpFull_Color);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpFull_Color);

// --- Unique Prefix Generation ---
   MathSrand((int)TimeCurrent() + (int)ChartID());
   string temp_short_name = StringFormat("SessSingle_TempID_%d_%d", TimeCurrent(), MathRand());
   IndicatorSetString(INDICATOR_SHORTNAME, temp_short_name);
   ChartRedraw();
   int window_index = ChartWindowFind(0, temp_short_name);
   if(window_index < 0)
      window_index = 0;
   g_unique_prefix = StringFormat("SessSingle_%s_%d_%d_", InpMarketName, ChartID(), window_index);
   ObjectsDeleteAll(0, g_unique_prefix);

// --- Determine Mode ---
   bool is_ha_mode = (InpCandleSource == CANDLE_HEIKIN_ASHI);

   for(int i=0; i<SESSIONS_COUNT; i++)
     {
      if(is_ha_mode)
        {
         g_box_analyzers[i] = new CSessionAnalyzer_HA();
         g_vwap_calculators[i] = new CVWAPCalculator_HA();
        }
      else
        {
         g_box_analyzers[i] = new CSessionAnalyzer();
         g_vwap_calculators[i] = new CVWAPCalculator();
        }
     }

// --- Init Analyzers (Boxes, Mean, LinReg) ---
   g_box_analyzers[0].Init(InpPre_Enable, InpPre_Start, InpPre_End, InpPre_Color, InpFillBoxes, InpPre_ShowMean, InpPre_ShowLinReg, g_unique_prefix + "Pre_", InpMaxHistoryDays);
   g_box_analyzers[1].Init(InpCore_Enable, InpCore_Start, InpCore_End, InpCore_Color, InpFillBoxes, InpCore_ShowMean, InpCore_ShowLinReg, g_unique_prefix + "Core_", InpMaxHistoryDays);
   g_box_analyzers[2].Init(InpPost_Enable, InpPost_Start, InpPost_End, InpPost_Color, InpFillBoxes, InpPost_ShowMean, InpPost_ShowLinReg, g_unique_prefix + "Post_", InpMaxHistoryDays);
   g_box_analyzers[3].Init(InpFull_Enable, InpPre_Start, InpPost_End, InpFull_Color, InpFillBoxes, InpFull_ShowMean, InpFull_ShowLinReg, g_unique_prefix + "Full_", InpMaxHistoryDays);

// --- Init VWAP Calculators ---
   g_vwap_calculators[0].Init(InpPre_Start, InpPre_End, InpVolumeType, InpPre_Enable && InpPre_ShowVWAP, InpMaxHistoryDays);
   g_vwap_calculators[1].Init(InpCore_Start, InpCore_End, InpVolumeType, InpCore_Enable && InpCore_ShowVWAP, InpMaxHistoryDays);
   g_vwap_calculators[2].Init(InpPost_Start, InpPost_End, InpVolumeType, InpPost_Enable && InpPost_ShowVWAP, InpMaxHistoryDays);
   g_vwap_calculators[3].Init(InpPre_Start, InpPost_End, InpVolumeType, InpFull_Enable && InpFull_ShowVWAP, InpMaxHistoryDays);

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis Single (" + InpMarketName + ")" + (is_ha_mode ? " HA" : ""));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i=0; i<SESSIONS_COUNT; i++)
     {
      if(CheckPointer(g_box_analyzers[i]) != POINTER_INVALID)
        {
         g_box_analyzers[i].Cleanup();
         delete g_box_analyzers[i];
        }
      if(CheckPointer(g_vwap_calculators[i]) != POINTER_INVALID)
         delete g_vwap_calculators[i];
     }
   ObjectsDeleteAll(0, g_unique_prefix);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime& time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total > 0 && time[rates_total - 1] == g_last_bar_time && Bars(_Symbol, _Period) == rates_total)
      return(rates_total);
   if(rates_total > 0)
      g_last_bar_time = time[rates_total - 1];

// --- Clear VWAP buffers (Unrolled) ---
   ArrayInitialize(BufferPre_Odd, EMPTY_VALUE);
   ArrayInitialize(BufferPre_Even, EMPTY_VALUE);
   ArrayInitialize(BufferCore_Odd, EMPTY_VALUE);
   ArrayInitialize(BufferCore_Even, EMPTY_VALUE);
   ArrayInitialize(BufferPost_Odd, EMPTY_VALUE);
   ArrayInitialize(BufferPost_Even, EMPTY_VALUE);
   ArrayInitialize(BufferFull_Odd, EMPTY_VALUE);
   ArrayInitialize(BufferFull_Even, EMPTY_VALUE);

// --- Object Drawing Logic ---
   for(int i=0; i<SESSIONS_COUNT; i++)
     {
      if(CheckPointer(g_box_analyzers[i]))
         g_box_analyzers[i].Update(rates_total, 0, time, open, high, low, close, InpSourcePrice);
     }

// --- VWAP Buffer Calculation Logic ---
   int vwap_prev_calc = 0; // Force full recalc

   if(CheckPointer(g_vwap_calculators[0]))
      g_vwap_calculators[0].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferPre_Odd, BufferPre_Even);
   if(CheckPointer(g_vwap_calculators[1]))
      g_vwap_calculators[1].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferCore_Odd, BufferCore_Even);
   if(CheckPointer(g_vwap_calculators[2]))
      g_vwap_calculators[2].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferPost_Odd, BufferPost_Even);
   if(CheckPointer(g_vwap_calculators[3]))
      g_vwap_calculators[3].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferFull_Odd, BufferFull_Even);

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
