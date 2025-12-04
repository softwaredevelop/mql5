//+------------------------------------------------------------------+
//|                                 Session_Analysis_Calculator.mqh  |
//|      VERSION 2.10: Added history limit for objects.              |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

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
CSessionAnalyzer::CSessionAnalyzer(void)
  {
   m_in_session = false;
   m_session_start_bar = -1;
   m_session_start_time = 0;
   m_max_history_days = 0;
  }

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
void CSessionAnalyzer::Cleanup(void)
  {
   ObjectsDeleteAll(0, m_prefix);
  }

//+------------------------------------------------------------------+
// Main Update Method
//+------------------------------------------------------------------+
void CSessionAnalyzer::Update(int rates_total, int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   if(!m_enabled || rates_total < 2)
      return;

// Force full recalculation logic for stability (as requested)
// But we use the structure that supports incremental if needed later.
// Here we reset state every time because OnCalculate passes prev_calculated but we might want to redraw.
// Actually, to fix the "bloat" issue, we must redraw only visible/recent history.

// Reset state for full recalc
   int start_index = 0;
   m_in_session = false;
   m_session_start_bar = -1;
   m_session_start_time = 0;

// Note: We don't call Cleanup() here every tick because it causes flickering.
// We rely on ObjectFind/ObjectMove inside DrawSession.
// However, if we change history limit, old objects might remain.
// Ideally, Cleanup() should be called if parameters change (OnInit).

   if(ArraySize(m_src_high) != rates_total)
     {
      ArrayResize(m_src_high, rates_total);
      ArrayResize(m_src_low, rates_total);
      ArrayResize(m_src_price, rates_total);
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

            // Only draw if session end time is newer than cutoff
            if(time[i] >= cutoff_time)
              {
               MqlDateTime start_dt;
               TimeToStruct(m_session_start_time, start_dt);
               long session_id = (long)m_session_start_time - (start_dt.hour * 3600 + start_dt.min * 60 + start_dt.sec);

               DrawSession(m_session_start_bar, i - 1, session_id, time);
              }
            m_session_start_bar = -1;
           }

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
           }
        }
     }
  }

//+------------------------------------------------------------------+
bool CSessionAnalyzer::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
// Optimized copy loop
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
            m_src_price[i] = (high[i]+low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_src_price[i] = (high[i]+low[i]+close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_src_price[i] = (high[i]+low[i]+2*close[i])/4.0;
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
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| Prepare Source Data (Heikin Ashi - Optimized)                    |
//+------------------------------------------------------------------+
bool CSessionAnalyzer_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
//--- Note: Since we force start_index=0 in Update for full recalc, this will recalc HA too.
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to source buffers (Optimized loop)
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
            m_src_price[i] = (m_ha_high[i]+m_ha_low[i])/2.0;
            break;
         case PRICE_TYPICAL:
            m_src_price[i] = (m_ha_high[i]+m_ha_low[i]+m_ha_close[i])/3.0;
            break;
         case PRICE_WEIGHTED:
            m_src_price[i] = (m_ha_high[i]+m_ha_low[i]+2*m_ha_close[i])/4.0;
            break;
         default:
            m_src_price[i] = m_ha_close[i];
            break;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
