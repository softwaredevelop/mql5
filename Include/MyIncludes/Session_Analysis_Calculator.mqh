//+------------------------------------------------------------------+
//|                                 Session_Analysis_Calculator.mqh  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.22" // Patched PRICE_WEIGHTED indexing error and disabled trendline infinite rays
#property description "Stateful calculator implementing session-box analysis with advanced ray bounds."

#ifndef SESSION_ANALYSIS_CALCULATOR_MQH
#define SESSION_ANALYSIS_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|           CLASS 1: CSessionAnalyzer (Base Class)                 |
//+==================================================================+
class CSessionAnalyzer
  {
protected:
   int               m_start_hour, m_start_min;
   int               m_end_hour, m_end_min;
   color             m_color;
   string            m_prefix;
   bool              m_enabled;
   bool              m_fill_box;
   bool              m_show_mean;
   bool              m_show_linreg;
   int               m_max_history_days; // Limit object history

   //--- Persistent Data Buffers
   double            m_src_high[], m_src_low[], m_src_price[];

   //--- Persistent State for Incremental Logic
   bool              m_in_session;
   int               m_session_start_bar;
   datetime          m_session_start_time;

   bool              IsTimeInSession(const MqlDateTime &dt);

   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

   void              DrawSession(int start_bar, int end_bar, long session_id, const datetime &time[]);

public:
                     CSessionAnalyzer(void);
   virtual          ~CSessionAnalyzer(void) {};

   void              Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_mean, bool show_linreg, string prefix, int max_history_days);

   void              Update(int rates_total, int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

   void              Cleanup(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionAnalyzer::CSessionAnalyzer(void)
  {
   m_in_session = false;
   m_session_start_bar = -1;
   m_session_start_time = 0;
   m_max_history_days = 0;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_mean, bool show_linreg, string prefix, int max_history_days)
  {
   m_enabled     = enabled;
   m_prefix      = prefix;
   m_color       = box_color;
   m_fill_box    = fill_box;
   m_show_mean   = show_mean;
   m_show_linreg = show_linreg;
   m_max_history_days = max_history_days;

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
//| Helper                                                           |
//+------------------------------------------------------------------+
bool CSessionAnalyzer::IsTimeInSession(const MqlDateTime &dt)
  {
   int current_time_in_minutes = dt.hour * 60 + dt.min;
   int start_time_in_minutes = m_start_hour * 60 + m_start_min;
   int end_time_in_minutes = m_end_hour * 60 + m_end_min;

   if(end_time_in_minutes < start_time_in_minutes) // Overnight session
      return (current_time_in_minutes >= start_time_in_minutes || current_time_in_minutes < end_time_in_minutes);
   else // Same-day session
      return (current_time_in_minutes >= start_time_in_minutes && current_time_in_minutes < end_time_in_minutes);
  }

//+------------------------------------------------------------------+
//| Cleanup                                                          |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Cleanup(void)
  {
   ObjectsDeleteAll(0, m_prefix);
  }

//+------------------------------------------------------------------+
//| Update: High Performance O(1) State-Persistent Tracking          |
//+------------------------------------------------------------------+
void CSessionAnalyzer::Update(int rates_total, int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   if(!m_enabled || rates_total < 2)
      return;

   int start_index = 0;

//--- Incremental state preservation
   if(prev_calculated == 0)
     {
      m_in_session = false;
      m_session_start_bar = -1;
      m_session_start_time = 0;
      start_index = 0;
     }
   else
     {
      start_index = prev_calculated - 1;
     }

//--- Enforce chronological safety on price caches
   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high,  rates_total);
      ArrayResize(m_src_low,   rates_total);
      ArrayResize(m_src_price, rates_total);

      ArraySetAsSeries(m_src_high,  false);
      ArraySetAsSeries(m_src_low,   false);
      ArraySetAsSeries(m_src_price, false);
     }

   if(!PrepareSourceData(rates_total, start_index, open, high, low, close, price_type))
      return;

// Calculate cutoff time for history limit
   datetime cutoff_time = 0;
   if(m_max_history_days > 0)
      cutoff_time = TimeCurrent() - m_max_history_days * 86400;

   int i = start_index;
   if(i == 0)
      i = 1;

//--- Sequential scanning loop (Runs O(1) on live ticks!)
   for(; i < rates_total; i++)
     {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      bool is_in_current_session = IsTimeInSession(dt);

      if(is_in_current_session && !m_in_session)
        {
         m_in_session = true;
         m_session_start_bar = i;
         m_session_start_time = time[i];
        }
      else
         if(!is_in_current_session && m_in_session)
           {
            m_in_session = false;

            // Draw/Update completed session
            if(time[i] >= cutoff_time)
              {
               MqlDateTime start_dt;
               TimeToStruct(m_session_start_time, start_dt);
               long session_id = (long)m_session_start_time - (start_dt.hour * 3600 + start_dt.min * 60 + start_dt.sec);

               DrawSession(m_session_start_bar, i - 1, session_id, time);
              }
            m_session_start_bar = -1;
           }

      // Live update of active forming session on every tick
      if(m_in_session)
        {
         if(time[i] >= cutoff_time)
           {
            MqlDateTime start_dt;
            TimeToStruct(m_session_start_time, start_dt);
            long session_id = (long)m_session_start_time - (start_dt.hour * 3600 + start_dt.min * 60 + start_dt.sec);

            DrawSession(m_session_start_bar, i, session_id, time);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| DrawSession: Flicker-free Object Modification                    |
//+------------------------------------------------------------------+
void CSessionAnalyzer::DrawSession(int start_bar, int end_bar, long session_id, const datetime &time[])
  {
   if(start_bar < 0 || end_bar < start_bar)
      return;

   int count = end_bar - start_bar + 1;
   int high_idx = ArrayMaximum(m_src_high, start_bar, count);
   int low_idx = ArrayMinimum(m_src_low, start_bar, count);

   double session_high = m_src_high[high_idx];
   double session_low = m_src_low[low_idx];

   string box_name = m_prefix + "Box_" + (string)session_id;
   if(ObjectFind(0, box_name) < 0)
     {
      ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, time[start_bar], session_high, time[end_bar], session_low);
      ObjectSetInteger(0, box_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, box_name, OBJPROP_FILL, m_fill_box);
      ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectMove(0, box_name, 0, time[start_bar], session_high);
      ObjectMove(0, box_name, 1, time[end_bar], session_low);
     }

// --- Mean and LinReg ---
   if(m_show_mean || m_show_linreg)
     {
      double cumulative_price = 0;
      double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;

      for(int i = start_bar; i <= end_bar; i++)
        {
         cumulative_price += m_src_price[i];
         double x = i - start_bar;
         double y = m_src_price[i];
         sum_x += x;
         sum_y += y;
         sum_xy += x * y;
         sum_x2 += x * x;
        }

      int bar_count = end_bar - start_bar + 1;
      if(m_show_mean && bar_count > 0)
        {
         double mean_price = cumulative_price / bar_count;
         string mean_line_name = m_prefix + "Mean_" + (string)session_id;
         if(ObjectFind(0, mean_line_name) < 0)
            ObjectCreate(0, mean_line_name, OBJ_TREND, 0, time[start_bar], mean_price, time[end_bar], mean_price);
         else
           {
            ObjectMove(0, mean_line_name, 0, time[start_bar], mean_price);
            ObjectMove(0, mean_line_name, 1, time[end_bar], mean_price);
           }
         ObjectSetInteger(0, mean_line_name, OBJPROP_COLOR, m_color);
         ObjectSetInteger(0, mean_line_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, mean_line_name, OBJPROP_SELECTABLE, false);
         // Prevent infinite trendline extension (Force boundary locking)
         ObjectSetInteger(0, mean_line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, mean_line_name, OBJPROP_RAY_LEFT, false);
        }
      if(m_show_linreg && bar_count > 1)
        {
         double denominator = (bar_count * sum_x2 - sum_x * sum_x);
         if(denominator != 0)
           {
            double b = (bar_count * sum_xy - sum_x * sum_y) / denominator;
            double a = (sum_y - b * sum_x) / bar_count;
            double start_price = a;
            double end_price = a + b * (bar_count - 1);
            string lr_line_name = m_prefix + "LinReg_" + (string)session_id;
            if(ObjectFind(0, lr_line_name) < 0)
               ObjectCreate(0, lr_line_name, OBJ_TREND, 0, time[start_bar], start_price, time[end_bar], end_price);
            else
              {
               ObjectMove(0, lr_line_name, 0, time[start_bar], start_price);
               ObjectMove(0, lr_line_name, 1, time[end_bar], end_price);
              }
            ObjectSetInteger(0, lr_line_name, OBJPROP_COLOR, m_color);
            ObjectSetInteger(0, lr_line_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lr_line_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lr_line_name, OBJPROP_SELECTABLE, false);
            // Prevent infinite trendline extension (Force boundary locking)
            ObjectSetInteger(0, lr_line_name, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lr_line_name, OBJPROP_RAY_LEFT, false);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Fixed formula errors)                       |
//+------------------------------------------------------------------+
bool CSessionAnalyzer::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i] = high[i];
      m_src_low[i]  = low[i];

      switch(price_type)
        {
         case PRICE_OPEN:
            m_src_price[i] = open[i];
            break;
         case PRICE_HIGH:
            m_src_price[i] = high[i];
            break;
         case PRICE_LOW:
            m_src_price[i] = low[i];
            break;
         case PRICE_MEDIAN:
            m_src_price[i] = (high[i] + low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_src_price[i] = (high[i] + low[i] + close[i]) / 3.0;
            break;
         // FIXED: Changed close[i * 2.0] crash to proper 2.0 * close[i] value weighting
         case PRICE_WEIGHTED:
            m_src_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
            break;
         default:
            m_src_price[i] = close[i];
            break;
        }
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CSessionAnalyzer_HA (Heikin Ashi)           |
//+==================================================================+
class CSessionAnalyzer_HA : public CSessionAnalyzer
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double                 m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized & Fixed)            |
//+------------------------------------------------------------------+
bool CSessionAnalyzer_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open,  rates_total);
      ArrayResize(m_ha_high,  rates_total);
      ArrayResize(m_ha_low,   rates_total);
      ArrayResize(m_ha_close, rates_total);

      ArraySetAsSeries(m_ha_open,  false);
      ArraySetAsSeries(m_ha_high,  false);
      ArraySetAsSeries(m_ha_low,   false);
      ArraySetAsSeries(m_ha_close, false);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_src_high[i] = m_ha_high[i];
      m_src_low[i]  = m_ha_low[i];

      switch(price_type)
        {
         case PRICE_OPEN:
            m_src_price[i] = m_ha_open[i];
            break;
         case PRICE_HIGH:
            m_src_price[i] = m_ha_high[i];
            break;
         case PRICE_LOW:
            m_src_price[i] = m_ha_low[i];
            break;
         case PRICE_MEDIAN:
            m_src_price[i] = (m_ha_high[i] + m_ha_low[i]) * 0.5;
            break;
         case PRICE_TYPICAL:
            m_src_price[i] = (m_ha_high[i] + m_ha_low[i] + m_ha_close[i]) / 3.0;
            break;
         // FIXED: Changed m_ha_close[i * 2.0] crash to proper 2.0 * m_ha_close[i] value weighting
         case PRICE_WEIGHTED:
            m_src_price[i] = (m_ha_high[i] + m_ha_low[i] + 2.0 * m_ha_close[i]) * 0.25;
            break;
         default:
            m_src_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }

#endif // SESSION_ANALYSIS_CALCULATOR_MQH
//+------------------------------------------------------------------+
