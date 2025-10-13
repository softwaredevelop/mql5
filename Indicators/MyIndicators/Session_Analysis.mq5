//+------------------------------------------------------------------+
//|                                              Session_Analysis.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.61" // Corrected Mean line drawing logic
#property description "Draws boxes, VWAP, Mean, and LinReg lines for user-defined trading sessions."
#property description "Times are based on broker's server time."
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| CLASS: CSessionAnalyzer                                          |
//| Manages the drawing and analysis of a single session.            |
//+------------------------------------------------------------------+
class CSessionAnalyzer
  {
private:
   int               m_start_hour, m_start_min;
   int               m_end_hour, m_end_min;
   color             m_color;
   string            m_prefix;
   bool              m_enabled;
   bool              m_fill_box;
   bool              m_show_vwap;
   bool              m_show_mean;
   bool              m_show_linreg;
   ENUM_APPLIED_VOLUME m_volume_type;

   bool              IsTimeInSession(const MqlDateTime &dt);

public:
   void              Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_vwap, bool show_mean, bool show_linreg, ENUM_APPLIED_VOLUME vol_type, string prefix);
   void              Update(const int rates_total, const datetime &time[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[]);
   void              Cleanup(void);
  };

//+------------------------------------------------------------------+
//| CSessionAnalyzer: Initialization                                 |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_vwap, bool show_mean, bool show_linreg, ENUM_APPLIED_VOLUME vol_type, string prefix)
  {
   m_enabled     = enabled;
   m_prefix      = prefix;
   m_color       = box_color;
   m_fill_box    = fill_box;
   m_show_vwap   = show_vwap;
   m_show_mean   = show_mean;
   m_show_linreg = show_linreg;
   m_volume_type = vol_type;

   string parts[];
   if(StringSplit(start_time, ':', parts) == 2)
     {
      m_start_hour = (int)StringToInteger(parts[0]);
      m_start_min  = (int)StringToInteger(parts[1]);
     }
   if(StringSplit(end_time, ':', parts) == 2)
     {
      m_end_hour = (int)StringToInteger(parts[0]);
      m_end_min  = (int)StringToInteger(parts[1]);
     }
  }

//+------------------------------------------------------------------+
//| CSessionAnalyzer: Checks if a given time is within the session.  |
//+------------------------------------------------------------------+
bool CSessionAnalyzer::IsTimeInSession(const MqlDateTime &dt)
  {
   int current_time_in_minutes = dt.hour * 60 + dt.min;
   int start_time_in_minutes = m_start_hour * 60 + m_start_min;
   int end_time_in_minutes = m_end_hour * 60 + m_end_min;

   if(end_time_in_minutes < start_time_in_minutes)
     {
      return (current_time_in_minutes >= start_time_in_minutes || current_time_in_minutes < end_time_in_minutes);
     }
   else
     {
      return (current_time_in_minutes >= start_time_in_minutes && current_time_in_minutes < end_time_in_minutes);
     }
  }

//+------------------------------------------------------------------+
//| CSessionAnalyzer: Deletes all objects created by this instance   |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Cleanup(void)
  {
   if(!m_enabled)
      return;
   ObjectsDeleteAll(0, m_prefix);
  }

//+------------------------------------------------------------------+
//| CSessionAnalyzer: Main update logic                              |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Update(const int rates_total, const datetime &time[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[])
  {
   if(!m_enabled)
      return;

   Cleanup();

   bool in_session = false;
   int session_start_bar = -1;
   double session_high = 0, session_low = 0;
   long session_id = 0;

   double cumulative_tpv = 0, cumulative_vol = 0, prev_vwap = 0;
   double cumulative_price = 0;
   int bar_count = 0;
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;

   for(int i = 1; i < rates_total; i++)
     {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);

      bool is_in_current_session = IsTimeInSession(dt);

      if(is_in_current_session && !in_session)
        {
         in_session = true;
         session_start_bar = i;
         session_high = high[i];
         session_low = low[i];
         session_id = (long)time[i] - (dt.hour*3600 + dt.min*60 + dt.sec);
         cumulative_tpv = 0;
         cumulative_vol = 0;
         prev_vwap = 0;
         cumulative_price = 0;
         bar_count = 0;
         sum_x = 0;
         sum_y = 0;
         sum_xy = 0;
         sum_x2 = 0;
        }
      else
         if(!is_in_current_session && in_session)
           {
            in_session = false;
            // Final drawing is now handled by the real-time update logic below
           }

      if(in_session)
        {
         if(high[i] > session_high)
            session_high = high[i];
         if(low[i] < session_low)
            session_low = low[i];

         if(m_show_vwap)
           {
            double typical_price = (high[i] + low[i] + close[i]) / 3.0;
            long current_volume = (m_volume_type == VOLUME_TICK) ? tick_volume[i] : volume[i];
            if(current_volume < 1)
               current_volume = 1;
            cumulative_tpv += typical_price * (double)current_volume;
            cumulative_vol += (double)current_volume;
            double current_vwap = (cumulative_vol > 0) ? cumulative_tpv / cumulative_vol : 0;
            if(prev_vwap > 0)
              {
               string vwap_line_name = m_prefix + "VWAP_" + (string)time[i];
               ObjectCreate(0, vwap_line_name, OBJ_TREND, 0, time[i-1], prev_vwap, time[i], current_vwap);
               ObjectSetInteger(0, vwap_line_name, OBJPROP_COLOR, m_color);
               ObjectSetInteger(0, vwap_line_name, OBJPROP_WIDTH, 2);
              }
            prev_vwap = current_vwap;
           }

         if(m_show_mean || m_show_linreg)
           {
            cumulative_price += close[i];
            double x = bar_count;
            double y = close[i];
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
            bar_count++;
           }

         // --- Real-time drawing of all components for the current session ---
         string box_name = m_prefix + "Box_" + (string)session_id;
         if(ObjectFind(0, box_name) < 0)
           {
            ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, time[session_start_bar], session_high, time[i], session_low);
            ObjectSetInteger(0, box_name, OBJPROP_COLOR, m_color);
            ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
            ObjectSetInteger(0, box_name, OBJPROP_FILL, m_fill_box);
           }
         else
           {
            ObjectSetDouble(0, box_name, OBJPROP_PRICE, 0, session_high);
            ObjectSetDouble(0, box_name, OBJPROP_PRICE, 1, session_low);
            ObjectSetInteger(0, box_name, OBJPROP_TIME, 1, time[i]);
           }

         if(m_show_mean && bar_count > 0)
           {
            double mean_price = cumulative_price / bar_count;
            string mean_line_name = m_prefix + "Mean_" + (string)session_id;
            if(ObjectFind(0, mean_line_name) < 0)
               ObjectCreate(0, mean_line_name, OBJ_TREND, 0, time[session_start_bar], mean_price, time[i], mean_price);
            else
              {
               // CORRECTED: Update both price points to keep the line horizontal
               ObjectSetDouble(0, mean_line_name, OBJPROP_PRICE, 0, mean_price);
               ObjectSetDouble(0, mean_line_name, OBJPROP_PRICE, 1, mean_price);
               ObjectSetInteger(0, mean_line_name, OBJPROP_TIME, 1, time[i]);
              }
            ObjectSetInteger(0, mean_line_name, OBJPROP_COLOR, m_color);
            ObjectSetInteger(0, mean_line_name, OBJPROP_STYLE, STYLE_DOT);
           }

         if(m_show_linreg && bar_count > 1)
           {
            double b = (bar_count * sum_xy - sum_x * sum_y) / (bar_count * sum_x2 - sum_x * sum_x);
            double a = (sum_y - b * sum_x) / bar_count;
            double start_price = a;
            double end_price = a + b * (bar_count - 1);
            string lr_line_name = m_prefix + "LinReg_" + (string)session_id;
            if(ObjectFind(0, lr_line_name) < 0)
               ObjectCreate(0, lr_line_name, OBJ_TREND, 0, time[session_start_bar], start_price, time[i], end_price);
            else
              {
               ObjectMove(0, lr_line_name, 0, time[session_start_bar], start_price);
               ObjectMove(0, lr_line_name, 1, time[i], end_price);
              }
            ObjectSetInteger(0, lr_line_name, OBJPROP_COLOR, m_color);
            ObjectSetInteger(0, lr_line_name, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, lr_line_name, OBJPROP_WIDTH, 2);
           }
        }
     }
  }

//--- Input Parameters ---
input group "Display Settings"
input bool                InpFillBoxes  = false;
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Pre-Market Session (Broker Time)"
input bool   InpPreMarket_Enable = true;
input string InpPreMarket_Start  = "08:00";
input string InpPreMarket_End    = "09:30";
input color  InpPreMarket_Color  = C'33,150,243';
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
input color  InpCore_Color  = C'255,87,34';
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
input color  InpPostMarket_Color  = C'103,58,183';
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

   g_pre_market_analyzer = new CSessionAnalyzer();
   if(CheckPointer(g_pre_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_pre_market_analyzer.Init(InpPreMarket_Enable, InpPreMarket_Start, InpPreMarket_End, InpPreMarket_Color, InpFillBoxes, InpPreMarket_VWAP, InpPreMarket_Mean, InpPreMarket_LinReg, InpVolumeType, "PreMarket_");

   g_core_market_analyzer = new CSessionAnalyzer();
   if(CheckPointer(g_core_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_core_market_analyzer.Init(InpCore_Enable, InpCore_Start, InpCore_End, InpCore_Color, InpFillBoxes, InpCore_VWAP, InpCore_Mean, InpCore_LinReg, InpVolumeType, "CoreMarket_");

   g_post_market_analyzer = new CSessionAnalyzer();
   if(CheckPointer(g_post_market_analyzer) == POINTER_INVALID)
      return INIT_FAILED;
   g_post_market_analyzer.Init(InpPostMarket_Enable, InpPostMarket_Start, InpPostMarket_End, InpPostMarket_Color, InpFillBoxes, InpPostMarket_VWAP, InpPostMarket_Mean, InpPostMarket_LinReg, InpVolumeType, "PostMarket_");

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis");
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

   if(CheckPointer(g_pre_market_analyzer) != POINTER_INVALID)
      g_pre_market_analyzer.Update(rates_total, time, high, low, close, tick_volume, volume);

   if(CheckPointer(g_core_market_analyzer) != POINTER_INVALID)
      g_core_market_analyzer.Update(rates_total, time, high, low, close, tick_volume, volume);

   if(CheckPointer(g_post_market_analyzer) != POINTER_INVALID)
      g_post_market_analyzer.Update(rates_total, time, high, low, close, tick_volume, volume);

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
