//+------------------------------------------------------------------+
//|                                           Session_Analysis_Pro.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "3.04" // Using Time+Rand for a truly unique instance ID
#property description "Draws boxes, VWAP, Mean, and LinReg lines for user-defined trading sessions."
#property description "Supports Standard and Heikin Ashi price sources. Times are based on broker's server time."
#property indicator_chart_window
#property indicator_plots 0

#include <MyIncludes\Session_Analysis_Calculator.mqh>

//--- Custom Enum for Price Source, including Heikin Ashi ---
enum ENUM_APPLIED_PRICE_HA_ALL
  {
//--- Heikin Ashi Prices (negative values for easy identification)
   PRICE_HA_CLOSE    = -1,
   PRICE_HA_OPEN     = -2,
   PRICE_HA_HIGH     = -3,
   PRICE_HA_LOW      = -4,
   PRICE_HA_MEDIAN   = -5,
   PRICE_HA_TYPICAL  = -6,
   PRICE_HA_WEIGHTED = -7,
//--- Standard Prices (using built-in ENUM_APPLIED_PRICE values)
   PRICE_CLOSE_STD   = PRICE_CLOSE,
   PRICE_OPEN_STD    = PRICE_OPEN,
   PRICE_HIGH_STD    = PRICE_HIGH,
   PRICE_LOW_STD     = PRICE_LOW,
   PRICE_MEDIAN_STD  = PRICE_MEDIAN,
   PRICE_TYPICAL_STD = PRICE_TYPICAL,
   PRICE_WEIGHTED_STD= PRICE_WEIGHTED
  };

//--- Input Parameters ---
input group "Display Settings"
input bool                      InpFillBoxes   = false;
input ENUM_APPLIED_VOLUME       InpVolumeType  = VOLUME_TICK;
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice = PRICE_CLOSE_STD; // Price for Mean and LinReg

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Pre-Market Session (Broker Time)"
input bool   InpPreMarket_Enable = true;
input string InpPreMarket_Start  = "06:30";
input string InpPreMarket_End    = "09:30";
input color  InpPreMarket_Color  = clrSlateBlue;
input bool   InpPreMarket_VWAP   = true;
input bool   InpPreMarket_Mean   = true;
input bool   InpPreMarket_LinReg = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Core Trading Session (Broker Time)"
input bool   InpCore_Enable = true;
input string InpCore_Start  = "09:30";
input string InpCore_End    = "16:00";
input color  InpCore_Color  = clrSlateBlue;
input bool   InpCore_VWAP   = true;
input bool   InpCore_Mean   = true;
input bool   InpCore_LinReg = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Post-Market Session (Broker Time)"
input bool   InpPostMarket_Enable = true;
input string InpPostMarket_Start  = "16:00";
input string InpPostMarket_End    = "20:00";
input color  InpPostMarket_Color  = clrSlateBlue;
input bool   InpPostMarket_VWAP   = true;
input bool   InpPostMarket_Mean   = true;
input bool   InpPostMarket_LinReg = true;

//--- Global Variables ---
CSessionAnalyzer *g_pre_market_analyzer;
CSessionAnalyzer *g_core_market_analyzer;
CSessionAnalyzer *g_post_market_analyzer;
datetime g_last_bar_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_bar_time = 0;

//--- *** KEY CHANGE: Create a truly unique prefix using Time + Random value ***
//--- Seed the random number generator to ensure it's different on each terminal launch
   MathSrand((int)TimeCurrent());
   string unique_prefix = StringFormat("_ID_%d_%d_", TimeCurrent(), MathRand());


   string ha_suffix = "";
   if(InpSourcePrice <= PRICE_HA_CLOSE)
     {
      g_pre_market_analyzer = new CSessionAnalyzer_HA();
      g_core_market_analyzer = new CSessionAnalyzer_HA();
      g_post_market_analyzer = new CSessionAnalyzer_HA();
      ha_suffix = " HA";
     }
   else
     {
      g_pre_market_analyzer = new CSessionAnalyzer();
      g_core_market_analyzer = new CSessionAnalyzer();
      g_post_market_analyzer = new CSessionAnalyzer();
     }

   if(CheckPointer(g_pre_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_pre_market_analyzer.Init(InpPreMarket_Enable, InpPreMarket_Start, InpPreMarket_End, InpPreMarket_Color, InpFillBoxes, InpPreMarket_VWAP, InpPreMarket_Mean, InpPreMarket_LinReg, InpVolumeType, unique_prefix + "PreMarket_");

   if(CheckPointer(g_core_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_core_market_analyzer.Init(InpCore_Enable, InpCore_Start, InpCore_End, InpCore_Color, InpFillBoxes, InpCore_VWAP, InpCore_Mean, InpCore_LinReg, InpVolumeType, unique_prefix + "CoreMarket_");

   if(CheckPointer(g_post_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_post_market_analyzer.Init(InpPostMarket_Enable, InpPostMarket_Start, InpPostMarket_End, InpPostMarket_Color, InpFillBoxes, InpPostMarket_VWAP, InpPostMarket_Mean, InpPostMarket_LinReg, InpVolumeType, unique_prefix + "PostMarket_");

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis" + ha_suffix);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_pre_market_analyzer) != POINTER_INVALID)
     {
      g_pre_market_analyzer.Cleanup();
      delete g_pre_market_analyzer;
     }
   if(CheckPointer(g_core_market_analyzer) != POINTER_INVALID)
     {
      g_core_market_analyzer.Cleanup();
      delete g_core_market_analyzer;
     }
   if(CheckPointer(g_post_market_analyzer) != POINTER_INVALID)
     {
      g_post_market_analyzer.Cleanup();
      delete g_post_market_analyzer;
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime& time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total > 0 && time[rates_total - 1] == g_last_bar_time)
      return(rates_total);
   if(rates_total > 0)
      g_last_bar_time = time[rates_total - 1];

   ENUM_APPLIED_PRICE price_type;
   if(InpSourcePrice <= PRICE_HA_CLOSE)
      price_type = (ENUM_APPLIED_PRICE)(-(int)InpSourcePrice);
   else
      price_type = (ENUM_APPLIED_PRICE)InpSourcePrice;

   if(CheckPointer(g_pre_market_analyzer) != POINTER_INVALID)
      g_pre_market_analyzer.Update(rates_total, time, open, high, low, close, tick_volume, volume, price_type);

   if(CheckPointer(g_core_market_analyzer) != POINTER_INVALID)
      g_core_market_analyzer.Update(rates_total, time, open, high, low, close, tick_volume, volume, price_type);

   if(CheckPointer(g_post_market_analyzer) != POINTER_INVALID)
      g_post_market_analyzer.Update(rates_total, time, open, high, low, close, tick_volume, volume, price_type);

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
