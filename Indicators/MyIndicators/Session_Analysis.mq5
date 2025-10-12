//+------------------------------------------------------------------+
//|                                              Session_Analysis.mq5|
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.20" // Added option to fill boxes
#property description "Draws boxes around Pre-Market, Core, and Post-Market sessions."
#property description "Times are based on broker's server time."
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| CLASS: CSessionBoxer                                             |
//| Manages the drawing and updating of a single session box.        |
//+------------------------------------------------------------------+
class CSessionBoxer
  {
private:
   int               m_start_hour, m_start_min;
   int               m_end_hour, m_end_min;
   color             m_color;
   string            m_prefix;
   bool              m_enabled;
   bool              m_fill_box; // New member for fill property

   bool              IsTimeInSession(const MqlDateTime &dt);

public:
   void              Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, string prefix);
   void              Update(const int rates_total, const datetime &time[], const double &high[], const double &low[]);
   void              Cleanup(void);
  };

//+------------------------------------------------------------------+
//| CSessionBoxer: Initialization                                    |
//+------------------------------------------------------------------+
void CSessionBoxer::Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, string prefix)
  {
   m_enabled   = enabled;
   m_prefix    = prefix;
   m_color     = box_color;
   m_fill_box  = fill_box;

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
//| CSessionBoxer: Checks if a given time is within the session.     |
//+------------------------------------------------------------------+
bool CSessionBoxer::IsTimeInSession(const MqlDateTime &dt)
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
//| CSessionBoxer: Deletes all objects created by this instance      |
//+------------------------------------------------------------------+
void CSessionBoxer::Cleanup(void)
  {
   if(!m_enabled)
      return;
   for(int i = ObjectsTotal(0, -1, OBJ_RECTANGLE) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, OBJ_RECTANGLE);
      if(StringFind(name, m_prefix) == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }

//+------------------------------------------------------------------+
//| CSessionBoxer: Main update logic                                 |
//+------------------------------------------------------------------+
void CSessionBoxer::Update(const int rates_total, const datetime &time[], const double &high[], const double &low[])
  {
   if(!m_enabled)
      return;

   Cleanup();

   bool in_session = false;
   int session_start_bar = -1;
   double session_high = 0;
   double session_low = 0;
   long session_id = 0;

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
         session_id = (long)time[i] - (dt.hour*3600 + dt.min*60 + dt.sec); // Use day start as ID
        }
      else
         if(!is_in_current_session && in_session)
           {
            in_session = false;
            if(session_start_bar != -1 && i > session_start_bar)
              {
               string obj_name = m_prefix + (string)session_id;
               ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time[session_start_bar], session_high, time[i-1], session_low);
               ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
               ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
               ObjectSetInteger(0, obj_name, OBJPROP_FILL, m_fill_box); // Use input for fill
              }
           }

      if(in_session)
        {
         if(high[i] > session_high)
            session_high = high[i];
         if(low[i] < session_low)
            session_low = low[i];

         if(i == rates_total - 1)
           {
            string obj_name = m_prefix + (string)session_id;
            if(ObjectFind(0, obj_name) < 0)
              {
               ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time[session_start_bar], session_high, time[i], session_low);
               ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
               ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
               ObjectSetInteger(0, obj_name, OBJPROP_FILL, m_fill_box); // Use input for fill
              }
            else
              {
               ObjectSetDouble(0, obj_name, OBJPROP_PRICE, 0, session_high);
               ObjectSetDouble(0, obj_name, OBJPROP_PRICE, 1, session_low);
               ObjectSetInteger(0, obj_name, OBJPROP_TIME, 1, time[i]);
              }
           }
        }
     }
  }

//--- Input Parameters ---
input group "Display Settings"
input bool   InpFillBoxes      = false; // Fill Session Boxes

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Pre-Market Session (Broker Time)"
input bool   InpPreMarket_Enable = true;
input string InpPreMarket_Start  = "08:00";
input string InpPreMarket_End    = "09:30";
input color  InpPreMarket_Color  = C'33,150,243';  // Blue

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Core Trading Session (Broker Time)"
input bool   InpCore_Enable = true;
input string InpCore_Start  = "09:30";
input string InpCore_End    = "16:00";
input color  InpCore_Color  = C'255,87,34';   // Deep Orange

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "Post-Market Session (Broker Time)"
input bool   InpPostMarket_Enable = true;
input string InpPostMarket_Start  = "16:00";
input string InpPostMarket_End    = "20:00";
input color  InpPostMarket_Color  = C'103,58,183'; // Deep Purple

//--- Global Variables ---
CSessionBoxer *g_pre_market_boxer;
CSessionBoxer *g_core_market_boxer;
CSessionBoxer *g_post_market_boxer;
datetime g_last_bar_time;

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_last_bar_time = 0;

   g_pre_market_boxer = new CSessionBoxer();
   if(CheckPointer(g_pre_market_boxer) == POINTER_INVALID)
      return INIT_FAILED;
   g_pre_market_boxer.Init(InpPreMarket_Enable, InpPreMarket_Start, InpPreMarket_End, InpPreMarket_Color, InpFillBoxes, "PreMarketBox_");

   g_core_market_boxer = new CSessionBoxer();
   if(CheckPointer(g_core_market_boxer) == POINTER_INVALID)
      return INIT_FAILED;
   g_core_market_boxer.Init(InpCore_Enable, InpCore_Start, InpCore_End, InpCore_Color, InpFillBoxes, "CoreMarketBox_");

   g_post_market_boxer = new CSessionBoxer();
   if(CheckPointer(g_post_market_boxer) == POINTER_INVALID)
      return INIT_FAILED;
   g_post_market_boxer.Init(InpPostMarket_Enable, InpPostMarket_Start, InpPostMarket_End, InpPostMarket_Color, InpFillBoxes, "PostMarketBox_");

   IndicatorSetString(INDICATOR_SHORTNAME, "Session Analysis");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_pre_market_boxer) != POINTER_INVALID)
     {
      g_pre_market_boxer.Cleanup();
      delete g_pre_market_boxer;
     }
   if(CheckPointer(g_core_market_boxer) != POINTER_INVALID)
     {
      g_core_market_boxer.Cleanup();
      delete g_core_market_boxer;
     }
   if(CheckPointer(g_post_market_boxer) != POINTER_INVALID)
     {
      g_post_market_boxer.Cleanup();
      delete g_post_market_boxer;
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int, const datetime& time[], const double &open[], const double &high[], const double &low[], const double &close[], const long&[], const long&[], const int&[])
  {
   if(time[rates_total - 1] == g_last_bar_time && rates_total > 1)
      return(rates_total);
   g_last_bar_time = time[rates_total - 1];

   if(CheckPointer(g_pre_market_boxer) != POINTER_INVALID)
      g_pre_market_boxer.Update(rates_total, time, high, low);

   if(CheckPointer(g_core_market_boxer) != POINTER_INVALID)
      g_core_market_boxer.Update(rates_total, time, high, low);

   if(CheckPointer(g_post_market_boxer) != POINTER_INVALID)
      g_post_market_boxer.Update(rates_total, time, high, low);

   ChartRedraw();
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
