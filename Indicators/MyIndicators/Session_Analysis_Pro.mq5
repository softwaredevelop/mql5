//+------------------------------------------------------------------+
//|                                           Session_Analysis_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "4.00" // Scaled to support 3 independent markets
#property description "Draws boxes and analytics for up to 3 independent markets, each with Pre, Core, and Post sessions."
#property description "Supports Standard and Heikin Ashi price sources. Times are based on broker's server time."
#property indicator_chart_window
#property indicator_plots 0

#include <MyIncludes\Session_Analysis_Calculator.mqh>

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1, PRICE_HA_OPEN     = -2, PRICE_HA_HIGH     = -3, PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5, PRICE_HA_TYPICAL  = -6, PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE, PRICE_OPEN_STD    = PRICE_OPEN, PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW, PRICE_MEDIAN_STD  = PRICE_MEDIAN, PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input group "Global Settings"
input bool                      InpFillBoxes   = false;
input ENUM_APPLIED_VOLUME       InpVolumeType  = VOLUME_TICK;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price for Mean and LinReg

//--- Market 1 Settings ---
input group "Market 1 Settings (e.g., NYSE)"
input bool   InpM1_Enable        = true;
input group "M1 Pre-Market Session"
input bool   InpM1_PreMarket_Enable = true;
input string InpM1_PreMarket_Start  = "06:30";
input string InpM1_PreMarket_End    = "09:30";
input color  InpM1_PreMarket_Color  = clrSlateBlue;
input bool   InpM1_PreMarket_VWAP   = true;
input bool   InpM1_PreMarket_Mean   = true;
input bool   InpM1_PreMarket_LinReg = true;
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
input bool   InpM1_PostMarket_Mean   = true;
input bool   InpM1_PostMarket_LinReg = true;

//--- Market 2 Settings ---
input group "Market 2 Settings (e.g., LSE)"
input bool   InpM2_Enable        = true;
input group "M2 Pre-Market Session"
input bool   InpM2_PreMarket_Enable = true;
input string InpM2_PreMarket_Start  = "04:00";
input string InpM2_PreMarket_End    = "07:00";
input color  InpM2_PreMarket_Color  = clrIndianRed;
input bool   InpM2_PreMarket_VWAP   = true;
input bool   InpM2_PreMarket_Mean   = true;
input bool   InpM2_PreMarket_LinReg = true;
input group "M2 Core Trading Session"
input bool   InpM2_Core_Enable = true;
input string InpM2_Core_Start  = "07:00";
input string InpM2_Core_End    = "15:30";
input color  InpM2_Core_Color  = clrIndianRed;
input bool   InpM2_Core_VWAP   = true;
input bool   InpM2_Core_Mean   = true;
input bool   InpM2_Core_LinReg = true;
input group "M2 Post-Market Session"
input bool   InpM2_PostMarket_Enable = true;
input string InpM2_PostMarket_Start  = "15:30";
input string InpM2_PostMarket_End    = "16:15";
input color  InpM2_PostMarket_Color  = clrIndianRed;
input bool   InpM2_PostMarket_VWAP   = true;
input bool   InpM2_PostMarket_Mean   = true;
input bool   InpM2_PostMarket_LinReg = true;

//--- Market 3 Settings ---
input group "Market 3 Settings (e.g., TSE)"
input bool   InpM3_Enable        = true;
input group "M3 Pre-Market Session"
input bool   InpM3_PreMarket_Enable = true;
input string InpM3_PreMarket_Start  = "08:00";
input string InpM3_PreMarket_End    = "09:00";
input color  InpM3_PreMarket_Color  = clrSeaGreen;
input bool   InpM3_PreMarket_VWAP   = true;
input bool   InpM3_PreMarket_Mean   = true;
input bool   InpM3_PreMarket_LinReg = true;
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
input bool   InpM3_PostMarket_Mean   = true;
input bool   InpM3_PostMarket_LinReg = true;

//--- Global Variables ---
#define TOTAL_ANALYZERS 9
CSessionAnalyzer *g_analyzers[TOTAL_ANALYZERS];
datetime g_last_bar_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_bar_time = 0;
   for(int i = 0; i < TOTAL_ANALYZERS; i++)
      g_analyzers[i] = NULL;

//--- Create a stable, unique prefix for this indicator instance
   MathSrand((int)TimeCurrent() + (int)ChartID());
   string temp_short_name = StringFormat("SessPro_TempID_%d_%d", TimeCurrent(), MathRand());
   IndicatorSetString(INDICATOR_SHORTNAME, temp_short_name);
   ChartRedraw();
   int window_index = ChartWindowFind(0, temp_short_name);
   if(window_index < 0)
      window_index = 0;
   string unique_prefix = StringFormat("SessPro_%d_%d_", ChartID(), window_index);

   bool is_ha = (InpSourcePrice <= PRICE_HA_CLOSE);

//--- Instantiate all 9 analyzers ---
// Market 1
   g_analyzers[0] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[0].Init(InpM1_Enable && InpM1_PreMarket_Enable, InpM1_PreMarket_Start, InpM1_PreMarket_End, InpM1_PreMarket_Color, InpFillBoxes, InpM1_PreMarket_VWAP, InpM1_PreMarket_Mean, InpM1_PreMarket_LinReg, InpVolumeType, unique_prefix + "M1_Pre_");
   g_analyzers[1] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[1].Init(InpM1_Enable && InpM1_Core_Enable, InpM1_Core_Start, InpM1_Core_End, InpM1_Core_Color, InpFillBoxes, InpM1_Core_VWAP, InpM1_Core_Mean, InpM1_Core_LinReg, InpVolumeType, unique_prefix + "M1_Core_");
   g_analyzers[2] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[2].Init(InpM1_Enable && InpM1_PostMarket_Enable, InpM1_PostMarket_Start, InpM1_PostMarket_End, InpM1_PostMarket_Color, InpFillBoxes, InpM1_PostMarket_VWAP, InpM1_PostMarket_Mean, InpM1_PostMarket_LinReg, InpVolumeType, unique_prefix + "M1_Post_");
// Market 2
   g_analyzers[3] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[3].Init(InpM2_Enable && InpM2_PreMarket_Enable, InpM2_PreMarket_Start, InpM2_PreMarket_End, InpM2_PreMarket_Color, InpFillBoxes, InpM2_PreMarket_VWAP, InpM2_PreMarket_Mean, InpM2_PreMarket_LinReg, InpVolumeType, unique_prefix + "M2_Pre_");
   g_analyzers[4] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[4].Init(InpM2_Enable && InpM2_Core_Enable, InpM2_Core_Start, InpM2_Core_End, InpM2_Core_Color, InpFillBoxes, InpM2_Core_VWAP, InpM2_Core_Mean, InpM2_Core_LinReg, InpVolumeType, unique_prefix + "M2_Core_");
   g_analyzers[5] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[5].Init(InpM2_Enable && InpM2_PostMarket_Enable, InpM2_PostMarket_Start, InpM2_PostMarket_End, InpM2_PostMarket_Color, InpFillBoxes, InpM2_PostMarket_VWAP, InpM2_PostMarket_Mean, InpM2_PostMarket_LinReg, InpVolumeType, unique_prefix + "M2_Post_");
// Market 3
   g_analyzers[6] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[6].Init(InpM3_Enable && InpM3_PreMarket_Enable, InpM3_PreMarket_Start, InpM3_PreMarket_End, InpM3_PreMarket_Color, InpFillBoxes, InpM3_PreMarket_VWAP, InpM3_PreMarket_Mean, InpM3_PreMarket_LinReg, InpVolumeType, unique_prefix + "M3_Pre_");
   g_analyzers[7] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[7].Init(InpM3_Enable && InpM3_Core_Enable, InpM3_Core_Start, InpM3_Core_End, InpM3_Core_Color, InpFillBoxes, InpM3_Core_VWAP, InpM3_Core_Mean, InpM3_Core_LinReg, InpVolumeType, unique_prefix + "M3_Core_");
   g_analyzers[8] = is_ha ? new CSessionAnalyzer_HA() : new CSessionAnalyzer();
   g_analyzers[8].Init(InpM3_Enable && InpM3_PostMarket_Enable, InpM3_PostMarket_Start, InpM3_PostMarket_End, InpM3_PostMarket_Color, InpFillBoxes, InpM3_PostMarket_VWAP, InpM3_PostMarket_Mean, InpM3_PostMarket_LinReg, InpVolumeType, unique_prefix + "M3_Post_");

//--- Clean up any old objects before drawing ---
   for(int i = 0; i < TOTAL_ANALYZERS; i++)
     {
      if(CheckPointer(g_analyzers[i]) != POINTER_INVALID)
         g_analyzers[i].Cleanup();
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis" + (is_ha ? " HA" : ""));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i = 0; i < TOTAL_ANALYZERS; i++)
     {
      if(CheckPointer(g_analyzers[i]) != POINTER_INVALID)
        {
         g_analyzers[i].Cleanup();
         delete g_analyzers[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime& time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total > 0 && time[rates_total - 1] == g_last_bar_time && Bars(_Symbol, _Period) == rates_total)
      return(rates_total);
   if(rates_total > 0)
      g_last_bar_time = time[rates_total - 1];

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   for(int i = 0; i < TOTAL_ANALYZERS; i++)
     {
      if(CheckPointer(g_analyzers[i]) != POINTER_INVALID)
         g_analyzers[i].Update(rates_total, time, open, high, low, close, tick_volume, volume, price_type);
     }

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
