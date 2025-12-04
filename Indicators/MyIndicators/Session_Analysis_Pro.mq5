//+------------------------------------------------------------------+
//|                                           Session_Analysis_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "6.50" // Added History Limit to reduce template size
#property description "Draws boxes, analytics, and session-based VWAP via high-performance buffers."
#property indicator_chart_window
// Buffers: M1(Pre A/B, Core A/B, Post A/B, Full A/B) = 8. Total for 3 markets = 24
#property indicator_buffers 24
#property indicator_plots   24

//--- Include Engines ---
#include <MyIncludes\Session_Analysis_Calculator.mqh> // For Boxes, Mean, LinReg
#include <MyIncludes\VWAP_Calculator.mqh>             // For VWAP calculations

//--- Plot Properties for VWAP lines (Market 1) ---
#property indicator_type1   DRAW_LINE
#property indicator_label1  "M1 Pre VWAP"
#property indicator_type2   DRAW_LINE
#property indicator_label2  ""
#property indicator_type3   DRAW_LINE
#property indicator_label3  "M1 Core VWAP"
#property indicator_type4   DRAW_LINE
#property indicator_label4  ""
#property indicator_type5   DRAW_LINE
#property indicator_label5  "M1 Post VWAP"
#property indicator_type6   DRAW_LINE
#property indicator_label6  ""
#property indicator_type7   DRAW_LINE
#property indicator_label7  "M1 Full VWAP"
#property indicator_type8   DRAW_LINE
#property indicator_label8  ""
//--- Plot Properties for VWAP lines (Market 2) ---
#property indicator_type9   DRAW_LINE
#property indicator_label9  "M2 Pre VWAP"
#property indicator_type10  DRAW_LINE
#property indicator_label10 ""
#property indicator_type11  DRAW_LINE
#property indicator_label11 "M2 Core VWAP"
#property indicator_type12  DRAW_LINE
#property indicator_label12 ""
#property indicator_type13  DRAW_LINE
#property indicator_label13 "M2 Post VWAP"
#property indicator_type14  DRAW_LINE
#property indicator_label14 ""
#property indicator_type15  DRAW_LINE
#property indicator_label15 "M2 Full VWAP"
#property indicator_type16  DRAW_LINE
#property indicator_label16 ""
//--- Plot Properties for VWAP lines (Market 3) ---
#property indicator_type17  DRAW_LINE
#property indicator_label17 "M3 Pre VWAP"
#property indicator_type18  DRAW_LINE
#property indicator_label18 ""
#property indicator_type19  DRAW_LINE
#property indicator_label19 "M3 Core VWAP"
#property indicator_type20  DRAW_LINE
#property indicator_label20 ""
#property indicator_type21  DRAW_LINE
#property indicator_label21 "M3 Post VWAP"
#property indicator_type22  DRAW_LINE
#property indicator_label22 ""
#property indicator_type23  DRAW_LINE
#property indicator_label23 "M3 Full VWAP"
#property indicator_type24  DRAW_LINE
#property indicator_label24 ""

//--- Enum for selecting the candle source for calculation ---
enum ENUM_CANDLE_SOURCE
  {
   CANDLE_STANDARD,      // Use standard OHLC data
   CANDLE_HEIKIN_ASHI    // Use Heikin Ashi smoothed data
  };

//--- Input Parameters ---
input group "Global Settings"
input bool                InpFillBoxes   = false;
input int                 InpMaxHistoryDays = 5; // Limit object history (0 = All)
input ENUM_APPLIED_VOLUME InpVolumeType  = VOLUME_TICK;
input ENUM_CANDLE_SOURCE  InpCandleSource = CANDLE_STANDARD; // For VWAP and other analytics
input ENUM_APPLIED_PRICE  InpSourcePrice = PRICE_TYPICAL; // For Mean/LinReg

//--- Market 1 Settings ---
input group "Market 1 Settings (e.g., NYSE)"
input bool   InpM1_Enable        = true;
input group "M1 Pre-Market Session"
input bool   InpM1_PreMarket_Enable = true;
input string InpM1_PreMarket_Start  = "06:30";
input string InpM1_PreMarket_End    = "09:30";
input color  InpM1_PreMarket_Color  = clrSlateBlue;
input bool   InpM1_PreMarket_VWAP   = true;
input bool   InpM1_PreMarket_Mean   = false;
input bool   InpM1_PreMarket_LinReg = false;
input group "M1 Core Trading Session"
input bool   InpM1_Core_Enable = true;
input string InpM1_Core_Start  = "09:30";
input string InpM1_Core_End    = "16:00";
input color  InpM1_Core_Color  = clrSlateBlue;
input bool   InpM1_Core_VWAP   = true;
input bool   InpM1_Core_Mean   = true;
input bool   InpM1_Core_LinReg = true;
input group "M1 Post-Market Session"
input bool   InpM1_PostMarket_Enable = true;
input string InpM1_PostMarket_Start  = "16:00";
input string InpM1_PostMarket_End    = "20:00";
input color  InpM1_PostMarket_Color  = clrSlateBlue;
input bool   InpM1_PostMarket_VWAP   = true;
input bool   InpM1_PostMarket_Mean   = false;
input bool   InpM1_PostMarket_LinReg = false;
input group "M1 Full Day Analysis"
input bool   InpM1_FullDay_Enable = false;
input color  InpM1_FullDay_Color  = clrGray;
input bool   InpM1_FullDay_VWAP   = true;
input bool   InpM1_FullDay_Mean   = false;
input bool   InpM1_FullDay_LinReg = false;

//--- Market 2 Settings ---
input group "Market 2 Settings (e.g., LSE)"
input bool   InpM2_Enable        = false;
input group "M2 Pre-Market Session"
input bool   InpM2_PreMarket_Enable = true;
input string InpM2_PreMarket_Start  = "05:00";
input string InpM2_PreMarket_End    = "08:00";
input color  InpM2_PreMarket_Color  = clrIndianRed;
input bool   InpM2_PreMarket_VWAP   = true;
input bool   InpM2_PreMarket_Mean   = false;
input bool   InpM2_PreMarket_LinReg = false;
input group "M2 Core Trading Session"
input bool   InpM2_Core_Enable = true;
input string InpM2_Core_Start  = "08:00";
input string InpM2_Core_End    = "16:30";
input color  InpM2_Core_Color  = clrIndianRed;
input bool   InpM2_Core_VWAP   = true;
input bool   InpM2_Core_Mean   = true;
input bool   InpM2_Core_LinReg = true;
input group "M2 Post-Market Session"
input bool   InpM2_PostMarket_Enable = true;
input string InpM2_PostMarket_Start  = "16:30";
input string InpM2_PostMarket_End    = "17:15";
input color  InpM2_PostMarket_Color  = clrIndianRed;
input bool   InpM2_PostMarket_VWAP   = true;
input bool   InpM2_PostMarket_Mean   = false;
input bool   InpM2_PostMarket_LinReg = false;
input group "M2 Full Day Analysis"
input bool   InpM2_FullDay_Enable = false;
input color  InpM2_FullDay_Color  = clrGray;
input bool   InpM2_FullDay_VWAP   = true;
input bool   InpM2_FullDay_Mean   = false;
input bool   InpM2_FullDay_LinReg = false;

//--- Market 3 Settings ---
input group "Market 3 Settings (e.g., TSE)"
input bool   InpM3_Enable        = false;
input group "M3 Pre-Market Session"
input bool   InpM3_PreMarket_Enable = true;
input string InpM3_PreMarket_Start  = "08:00";
input string InpM3_PreMarket_End    = "09:00";
input color  InpM3_PreMarket_Color  = clrSeaGreen;
input bool   InpM3_PreMarket_VWAP   = true;
input bool   InpM3_PreMarket_Mean   = false;
input bool   InpM3_PreMarket_LinReg = false;
input group "M3 Core Trading Session"
input bool   InpM3_Core_Enable = true;
input string InpM3_Core_Start  = "09:00";
input string InpM3_Core_End    = "11:30";
input color  InpM3_Core_Color  = clrSeaGreen;
input bool   InpM3_Core_VWAP   = true;
input bool   InpM3_Core_Mean   = true;
input bool   InpM3_Core_LinReg = true;
input group "M3 Post-Market Session"
input bool   InpM3_PostMarket_Enable = true;
input string InpM3_PostMarket_Start  = "12:30";
input string InpM3_PostMarket_End    = "15:30";
input color  InpM3_PostMarket_Color  = clrSeaGreen;
input bool   InpM3_PostMarket_VWAP   = true;
input bool   InpM3_PostMarket_Mean   = false;
input bool   InpM3_PostMarket_LinReg = false;
input group "M3 Full Day Analysis"
input bool   InpM3_FullDay_Enable = false;
input color  InpM3_FullDay_Color  = clrGray;
input bool   InpM3_FullDay_VWAP   = true;
input bool   InpM3_FullDay_Mean   = false;
input bool   InpM3_FullDay_LinReg = false;

//--- Indicator Buffers for VWAP ---
double BufferM1_Pre_A[],  BufferM1_Pre_B[];
double BufferM1_Core_A[], BufferM1_Core_B[];
double BufferM1_Post_A[], BufferM1_Post_B[];
double BufferM1_Full_A[], BufferM1_Full_B[];
double BufferM2_Pre_A[],  BufferM2_Pre_B[];
double BufferM2_Core_A[], BufferM2_Core_B[];
double BufferM2_Post_A[], BufferM2_Post_B[];
double BufferM2_Full_A[], BufferM2_Full_B[];
double BufferM3_Pre_A[],  BufferM3_Pre_B[];
double BufferM3_Core_A[], BufferM3_Core_B[];
double BufferM3_Post_A[], BufferM3_Post_B[];
double BufferM3_Full_A[], BufferM3_Full_B[];

//--- Global Variables ---
#define TOTAL_SESSIONS 12
CSessionAnalyzer *g_box_analyzers[TOTAL_SESSIONS];
CVWAPCalculator  *g_vwap_calculators[TOTAL_SESSIONS];
datetime g_last_bar_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_bar_time = 0;
   for(int i=0; i<TOTAL_SESSIONS; i++)
     {
      g_box_analyzers[i] = NULL;
      g_vwap_calculators[i] = NULL;
     }

// --- Set up VWAP Buffers ---
   SetIndexBuffer(0,  BufferM1_Pre_A,  INDICATOR_DATA);
   SetIndexBuffer(1,  BufferM1_Pre_B,  INDICATOR_DATA);
   SetIndexBuffer(2,  BufferM1_Core_A, INDICATOR_DATA);
   SetIndexBuffer(3,  BufferM1_Core_B, INDICATOR_DATA);
   SetIndexBuffer(4,  BufferM1_Post_A, INDICATOR_DATA);
   SetIndexBuffer(5,  BufferM1_Post_B, INDICATOR_DATA);
   SetIndexBuffer(6,  BufferM1_Full_A, INDICATOR_DATA);
   SetIndexBuffer(7,  BufferM1_Full_B, INDICATOR_DATA);
   SetIndexBuffer(8,  BufferM2_Pre_A,  INDICATOR_DATA);
   SetIndexBuffer(9,  BufferM2_Pre_B,  INDICATOR_DATA);
   SetIndexBuffer(10, BufferM2_Core_A, INDICATOR_DATA);
   SetIndexBuffer(11, BufferM2_Core_B, INDICATOR_DATA);
   SetIndexBuffer(12, BufferM2_Post_A, INDICATOR_DATA);
   SetIndexBuffer(13, BufferM2_Post_B, INDICATOR_DATA);
   SetIndexBuffer(14, BufferM2_Full_A, INDICATOR_DATA);
   SetIndexBuffer(15, BufferM2_Full_B, INDICATOR_DATA);
   SetIndexBuffer(16, BufferM3_Pre_A,  INDICATOR_DATA);
   SetIndexBuffer(17, BufferM3_Pre_B,  INDICATOR_DATA);
   SetIndexBuffer(18, BufferM3_Core_A, INDICATOR_DATA);
   SetIndexBuffer(19, BufferM3_Core_B, INDICATOR_DATA);
   SetIndexBuffer(20, BufferM3_Post_A, INDICATOR_DATA);
   SetIndexBuffer(21, BufferM3_Post_B, INDICATOR_DATA);
   SetIndexBuffer(22, BufferM3_Full_A, INDICATOR_DATA);
   SetIndexBuffer(23, BufferM3_Full_B, INDICATOR_DATA);

   for(int i=0; i<24; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

// --- Set VWAP Colors ---
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpM1_PreMarket_Color);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpM1_PreMarket_Color);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpM1_Core_Color);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpM1_Core_Color);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpM1_PostMarket_Color);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpM1_PostMarket_Color);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, InpM1_FullDay_Color);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpM1_FullDay_Color);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpM2_PreMarket_Color);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, InpM2_PreMarket_Color);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, InpM2_Core_Color);
   PlotIndexSetInteger(11, PLOT_LINE_COLOR, InpM2_Core_Color);
   PlotIndexSetInteger(12, PLOT_LINE_COLOR, InpM2_PostMarket_Color);
   PlotIndexSetInteger(13, PLOT_LINE_COLOR, InpM2_PostMarket_Color);
   PlotIndexSetInteger(14, PLOT_LINE_COLOR, InpM2_FullDay_Color);
   PlotIndexSetInteger(15, PLOT_LINE_COLOR, InpM2_FullDay_Color);
   PlotIndexSetInteger(16, PLOT_LINE_COLOR, InpM3_PreMarket_Color);
   PlotIndexSetInteger(17, PLOT_LINE_COLOR, InpM3_PreMarket_Color);
   PlotIndexSetInteger(18, PLOT_LINE_COLOR, InpM3_Core_Color);
   PlotIndexSetInteger(19, PLOT_LINE_COLOR, InpM3_Core_Color);
   PlotIndexSetInteger(20, PLOT_LINE_COLOR, InpM3_PostMarket_Color);
   PlotIndexSetInteger(21, PLOT_LINE_COLOR, InpM3_PostMarket_Color);
   PlotIndexSetInteger(22, PLOT_LINE_COLOR, InpM3_FullDay_Color);
   PlotIndexSetInteger(23, PLOT_LINE_COLOR, InpM3_FullDay_Color);

// --- Centralized Cleanup Logic ---
   MathSrand((int)TimeCurrent() + (int)ChartID());
   string temp_short_name = StringFormat("SessPro_TempID_%d_%d", TimeCurrent(), MathRand());
   IndicatorSetString(INDICATOR_SHORTNAME, temp_short_name);
   ChartRedraw();
   int window_index = ChartWindowFind(0, temp_short_name);
   if(window_index < 0)
      window_index = 0;
   string unique_prefix = StringFormat("SessPro_%d_%d_", ChartID(), window_index);
   ObjectsDeleteAll(0, unique_prefix);

// --- Unified Initialization for both calculator types ---
   bool is_ha_mode = (InpCandleSource == CANDLE_HEIKIN_ASHI);
   for(int i=0; i<TOTAL_SESSIONS; i++)
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

// --- Init Logic for Box/Mean/LinReg Analyzers (Object-based) ---
   g_box_analyzers[0].Init(InpM1_Enable && InpM1_PreMarket_Enable, InpM1_PreMarket_Start, InpM1_PreMarket_End, InpM1_PreMarket_Color, InpFillBoxes, InpM1_PreMarket_Mean, InpM1_PreMarket_LinReg, unique_prefix + "M1_Pre_", InpMaxHistoryDays);
   g_box_analyzers[1].Init(InpM1_Enable && InpM1_Core_Enable, InpM1_Core_Start, InpM1_Core_End, InpM1_Core_Color, InpFillBoxes, InpM1_Core_Mean, InpM1_Core_LinReg, unique_prefix + "M1_Core_", InpMaxHistoryDays);
   g_box_analyzers[2].Init(InpM1_Enable && InpM1_PostMarket_Enable, InpM1_PostMarket_Start, InpM1_PostMarket_End, InpM1_PostMarket_Color, InpFillBoxes, InpM1_PostMarket_Mean, InpM1_PostMarket_LinReg, unique_prefix + "M1_Post_", InpMaxHistoryDays);
   g_box_analyzers[3].Init(InpM1_Enable && InpM1_FullDay_Enable, InpM1_PreMarket_Start, InpM1_PostMarket_End, InpM1_FullDay_Color, InpFillBoxes, InpM1_FullDay_Mean, InpM1_FullDay_LinReg, unique_prefix + "M1_Full_", InpMaxHistoryDays);
   g_box_analyzers[4].Init(InpM2_Enable && InpM2_PreMarket_Enable, InpM2_PreMarket_Start, InpM2_PreMarket_End, InpM2_PreMarket_Color, InpFillBoxes, InpM2_PreMarket_Mean, InpM2_PreMarket_LinReg, unique_prefix + "M2_Pre_", InpMaxHistoryDays);
   g_box_analyzers[5].Init(InpM2_Enable && InpM2_Core_Enable, InpM2_Core_Start, InpM2_Core_End, InpM2_Core_Color, InpFillBoxes, InpM2_Core_Mean, InpM2_Core_LinReg, unique_prefix + "M2_Core_", InpMaxHistoryDays);
   g_box_analyzers[6].Init(InpM2_Enable && InpM2_PostMarket_Enable, InpM2_PostMarket_Start, InpM2_PostMarket_End, InpM2_PostMarket_Color, InpFillBoxes, InpM2_PostMarket_Mean, InpM2_PostMarket_LinReg, unique_prefix + "M2_Post_", InpMaxHistoryDays);
   g_box_analyzers[7].Init(InpM2_Enable && InpM2_FullDay_Enable, InpM2_PreMarket_Start, InpM2_PostMarket_End, InpM2_FullDay_Color, InpFillBoxes, InpM2_FullDay_Mean, InpM2_FullDay_LinReg, unique_prefix + "M2_Full_", InpMaxHistoryDays);
   g_box_analyzers[8].Init(InpM3_Enable && InpM3_PreMarket_Enable, InpM3_PreMarket_Start, InpM3_PreMarket_End, InpM3_PreMarket_Color, InpFillBoxes, InpM3_PreMarket_Mean, InpM3_PreMarket_LinReg, unique_prefix + "M3_Pre_", InpMaxHistoryDays);
   g_box_analyzers[9].Init(InpM3_Enable && InpM3_Core_Enable, InpM3_Core_Start, InpM3_Core_End, InpM3_Core_Color, InpFillBoxes, InpM3_Core_Mean, InpM3_Core_LinReg, unique_prefix + "M3_Core_", InpMaxHistoryDays);
   g_box_analyzers[10].Init(InpM3_Enable && InpM3_PostMarket_Enable, InpM3_PostMarket_Start, InpM3_PostMarket_End, InpM3_PostMarket_Color, InpFillBoxes, InpM3_PostMarket_Mean, InpM3_PostMarket_LinReg, unique_prefix + "M3_Post_", InpMaxHistoryDays);
   g_box_analyzers[11].Init(InpM3_Enable && InpM3_FullDay_Enable, InpM3_PreMarket_Start, InpM3_PostMarket_End, InpM3_FullDay_Color, InpFillBoxes, InpM3_FullDay_Mean, InpM3_FullDay_LinReg, unique_prefix + "M3_Full_", InpMaxHistoryDays);

// --- Init Logic for VWAP Calculators (Buffer-based) ---
// Updated to pass InpMaxHistoryDays
   g_vwap_calculators[0].Init(InpM1_PreMarket_Start, InpM1_PreMarket_End, InpVolumeType, InpM1_Enable && InpM1_PreMarket_Enable && InpM1_PreMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[1].Init(InpM1_Core_Start, InpM1_Core_End, InpVolumeType, InpM1_Enable && InpM1_Core_Enable && InpM1_Core_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[2].Init(InpM1_PostMarket_Start, InpM1_PostMarket_End, InpVolumeType, InpM1_Enable && InpM1_PostMarket_Enable && InpM1_PostMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[3].Init(InpM1_PreMarket_Start, InpM1_PostMarket_End, InpVolumeType, InpM1_Enable && InpM1_FullDay_Enable && InpM1_FullDay_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[4].Init(InpM2_PreMarket_Start, InpM2_PreMarket_End, InpVolumeType, InpM2_Enable && InpM2_PreMarket_Enable && InpM2_PreMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[5].Init(InpM2_Core_Start, InpM2_Core_End, InpVolumeType, InpM2_Enable && InpM2_Core_Enable && InpM2_Core_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[6].Init(InpM2_PostMarket_Start, InpM2_PostMarket_End, InpVolumeType, InpM2_Enable && InpM2_PostMarket_Enable && InpM2_PostMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[7].Init(InpM2_PreMarket_Start, InpM2_PostMarket_End, InpVolumeType, InpM2_Enable && InpM2_FullDay_Enable && InpM2_FullDay_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[8].Init(InpM3_PreMarket_Start, InpM3_PreMarket_End, InpVolumeType, InpM3_Enable && InpM3_PreMarket_Enable && InpM3_PreMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[9].Init(InpM3_Core_Start, InpM3_Core_End, InpVolumeType, InpM3_Enable && InpM3_Core_Enable && InpM3_Core_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[10].Init(InpM3_PostMarket_Start, InpM3_PostMarket_End, InpVolumeType, InpM3_Enable && InpM3_PostMarket_Enable && InpM3_PostMarket_VWAP, InpMaxHistoryDays);
   g_vwap_calculators[11].Init(InpM3_PreMarket_Start, InpM3_PostMarket_End, InpVolumeType, InpM3_Enable && InpM3_FullDay_Enable && InpM3_FullDay_VWAP, InpMaxHistoryDays);

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis" + (is_ha_mode ? " HA" : ""));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i=0; i<TOTAL_SESSIONS; i++)
     {
      if(CheckPointer(g_box_analyzers[i]) != POINTER_INVALID)
        {
         g_box_analyzers[i].Cleanup();
         delete g_box_analyzers[i];
        }
      if(CheckPointer(g_vwap_calculators[i]) != POINTER_INVALID)
        {
         delete g_vwap_calculators[i];
        }
     }
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

// --- Clear VWAP buffers ---
// Note: We clear them every new bar because we force full recalc for VWAP too
   ArrayInitialize(BufferM1_Pre_A, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Pre_B, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Core_A, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Core_B, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Post_A, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Post_B, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Full_A, EMPTY_VALUE);
   ArrayInitialize(BufferM1_Full_B, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Pre_A, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Pre_B, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Core_A, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Core_B, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Post_A, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Post_B, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Full_A, EMPTY_VALUE);
   ArrayInitialize(BufferM2_Full_B, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Pre_A, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Pre_B, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Core_A, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Core_B, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Post_A, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Post_B, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Full_A, EMPTY_VALUE);
   ArrayInitialize(BufferM3_Full_B, EMPTY_VALUE);

// --- Object Drawing Logic (Boxes, etc.) ---
// Pass 0 as prev_calculated to force full update (but optimized inside to skip drawing old boxes)
   for(int i=0; i<TOTAL_SESSIONS; i++)
     {
      if(CheckPointer(g_box_analyzers[i]))
         g_box_analyzers[i].Update(rates_total, 0, time, open, high, low, close, (ENUM_APPLIED_PRICE)InpSourcePrice);
     }

// --- VWAP Buffer Calculation Logic ---
   int vwap_prev_calc = 0; // Force full recalc

   if(CheckPointer(g_vwap_calculators[0]))
      g_vwap_calculators[0].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM1_Pre_A, BufferM1_Pre_B);
   if(CheckPointer(g_vwap_calculators[1]))
      g_vwap_calculators[1].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM1_Core_A, BufferM1_Core_B);
   if(CheckPointer(g_vwap_calculators[2]))
      g_vwap_calculators[2].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM1_Post_A, BufferM1_Post_B);
   if(CheckPointer(g_vwap_calculators[3]))
      g_vwap_calculators[3].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM1_Full_A, BufferM1_Full_B);
   if(CheckPointer(g_vwap_calculators[4]))
      g_vwap_calculators[4].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM2_Pre_A, BufferM2_Pre_B);
   if(CheckPointer(g_vwap_calculators[5]))
      g_vwap_calculators[5].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM2_Core_A, BufferM2_Core_B);
   if(CheckPointer(g_vwap_calculators[6]))
      g_vwap_calculators[6].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM2_Post_A, BufferM2_Post_B);
   if(CheckPointer(g_vwap_calculators[7]))
      g_vwap_calculators[7].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM2_Full_A, BufferM2_Full_B);
   if(CheckPointer(g_vwap_calculators[8]))
      g_vwap_calculators[8].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM3_Pre_A, BufferM3_Pre_B);
   if(CheckPointer(g_vwap_calculators[9]))
      g_vwap_calculators[9].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM3_Core_A, BufferM3_Core_B);
   if(CheckPointer(g_vwap_calculators[10]))
      g_vwap_calculators[10].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM3_Post_A, BufferM3_Post_B);
   if(CheckPointer(g_vwap_calculators[11]))
      g_vwap_calculators[11].Calculate(rates_total, vwap_prev_calc, time, open, high, low, close, tick_volume, volume, BufferM3_Full_A, BufferM3_Full_B);

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
