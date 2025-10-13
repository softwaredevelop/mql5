//+------------------------------------------------------------------+
//|                                 Session_Analysis_Calculator.mqh  |
//|      Calculation engine for drawing session boxes and analytics. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\HeikinAshi_Tools.mqh>

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CSessionAnalyzer (Base Class)                 |
//|                                                                  |
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
   bool              m_show_vwap;
   bool              m_show_mean;
   bool              m_show_linreg;
   ENUM_APPLIED_VOLUME m_volume_type;

   //--- Internal source buffers
   double            m_src_high[], m_src_low[], m_src_close[], m_src_price[];

   bool              IsTimeInSession(const MqlDateTime &dt);
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);

public:
   void              Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_vwap, bool show_mean, bool show_linreg, ENUM_APPLIED_VOLUME vol_type, string prefix);
   void              Update(const int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], ENUM_APPLIED_PRICE price_type);
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

   if(end_time_in_minutes < start_time_in_minutes) // Overnight session (e.g., 22:00 to 04:00)
     {
      return (current_time_in_minutes >= start_time_in_minutes || current_time_in_minutes < end_time_in_minutes);
     }
   else // Same-day session
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
void CSessionAnalyzer::Update(const int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], ENUM_APPLIED_PRICE price_type)
  {
   if(!m_enabled || rates_total < 2)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close, price_type))
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
         session_high = m_src_high[i];
         session_low = m_src_low[i];
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
            // Session ended, no action needed as drawing is real-time
           }

      if(in_session)
        {
         session_high = MathMax(session_high, m_src_high[i]);
         session_low  = MathMin(session_low, m_src_low[i]);

         if(m_show_vwap)
           {
            double typical_price = (m_src_high[i] + m_src_low[i] + m_src_close[i]) / 3.0;
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
            cumulative_price += m_src_price[i];
            double x = bar_count;
            double y = m_src_price[i];
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
               ObjectSetDouble(0, mean_line_name, OBJPROP_PRICE, 0, mean_price);
               ObjectSetDouble(0, mean_line_name, OBJPROP_PRICE, 1, mean_price);
               ObjectSetInteger(0, mean_line_name, OBJPROP_TIME, 1, time[i]);
              }
            ObjectSetInteger(0, mean_line_name, OBJPROP_COLOR, m_color);
            ObjectSetInteger(0, mean_line_name, OBJPROP_STYLE, STYLE_DOT);
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
  }

//+------------------------------------------------------------------+
//| CSessionAnalyzer: Prepares the standard source data.             |
//+------------------------------------------------------------------+
bool CSessionAnalyzer::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);

   ArrayResize(m_src_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_src_price, open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_src_price, high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_src_price, low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (high[i]+low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (high[i]+low[i]+close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (high[i]+low[i]+2*close[i])/4.0;
         break;
      default:
         ArrayCopy(m_src_price, close, 0, 0, rates_total);
         break;
     }
   return true;
  }

//+==================================================================+
//|                                                                  |
//|           CLASS 2: CSessionAnalyzer_HA (Heikin Ashi)             |
//|                                                                  |
//+==================================================================+
class CSessionAnalyzer_HA : public CSessionAnalyzer
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };

//+------------------------------------------------------------------+
//| CSessionAnalyzer_HA: Prepares the HA source data.                |
//+------------------------------------------------------------------+
bool CSessionAnalyzer_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
//--- CORRECTED SECTION: Declare all local HA arrays ---
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open,  rates_total);
   ArrayResize(ha_high,  rates_total);
   ArrayResize(ha_low,   rates_total);
   ArrayResize(ha_close, rates_total);

//--- Calculate all HA values into the local arrays
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);

//--- Now, copy the calculated HA values to the class member arrays for analysis
   ArrayCopy(m_src_high,  ha_high,  0, 0, rates_total);
   ArrayCopy(m_src_low,   ha_low,   0, 0, rates_total);
   ArrayCopy(m_src_close, ha_close, 0, 0, rates_total);

//--- Finally, prepare the specific m_src_price array based on user's choice
   ArrayResize(m_src_price, rates_total);
   switch(price_type)
     {
      case PRICE_OPEN:
         ArrayCopy(m_src_price, ha_open, 0, 0, rates_total);
         break;
      case PRICE_HIGH:
         ArrayCopy(m_src_price, ha_high, 0, 0, rates_total);
         break;
      case PRICE_LOW:
         ArrayCopy(m_src_price, ha_low, 0, 0, rates_total);
         break;
      case PRICE_MEDIAN:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (ha_high[i]+ha_low[i])/2.0;
         break;
      case PRICE_TYPICAL:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (ha_high[i]+ha_low[i]+ha_close[i])/3.0;
         break;
      case PRICE_WEIGHTED:
         for(int i=0; i<rates_total; i++)
            m_src_price[i] = (ha_high[i]+ha_low[i]+2*ha_close[i])/4.0;
         break;
      default: // PRICE_CLOSE
         ArrayCopy(m_src_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
