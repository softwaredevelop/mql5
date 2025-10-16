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
   bool              m_show_mean;
   bool              m_show_linreg;

   double            m_src_high[], m_src_low[], m_src_price[];

   bool              IsTimeInSession(const MqlDateTime &dt);
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);
   void              DrawSession(int start_bar, int end_bar, long session_id, const datetime &time[]);

public:
   void              Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_mean, bool show_linreg, string prefix);
   void              Update(const int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type);
   void              Cleanup(void);
  };

//+------------------------------------------------------------------+
void CSessionAnalyzer::Init(bool enabled, string start_time, string end_time, color box_color, bool fill_box, bool show_mean, bool show_linreg, string prefix)
  {
   m_enabled     = enabled;
   m_prefix      = prefix;
   m_color       = box_color;
   m_fill_box    = fill_box;
   m_show_mean   = show_mean;
   m_show_linreg = show_linreg;

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
void CSessionAnalyzer::Update(const int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   if(!m_enabled || rates_total < 2)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close, price_type))
      return;

   bool in_session = false;
   int session_start_bar = -1;

   for(int i = 1; i < rates_total; i++)
     {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      bool is_in_current_session = IsTimeInSession(dt);

      if(is_in_current_session && !in_session)
        {
         in_session = true;
         session_start_bar = i;
        }
      else
         if(!is_in_current_session && in_session)
           {
            in_session = false;
            MqlDateTime start_dt;
            TimeToStruct(time[session_start_bar], start_dt);
            long session_id = (long)time[session_start_bar] - (start_dt.hour * 3600 + start_dt.min * 60 + start_dt.sec);
            DrawSession(session_start_bar, i - 1, session_id, time);
            session_start_bar = -1;
           }
     }

   if(in_session && session_start_bar != -1)
     {
      MqlDateTime start_dt;
      TimeToStruct(time[session_start_bar], start_dt);
      long session_id = (long)time[session_start_bar] - (start_dt.hour * 3600 + start_dt.min * 60 + start_dt.sec);
      DrawSession(session_start_bar, rates_total - 1, session_id, time);
     }
  }

//+------------------------------------------------------------------+
void CSessionAnalyzer::DrawSession(int start_bar, int end_bar, long session_id, const datetime &time[])
  {
   if(start_bar < 0 || end_bar < start_bar)
      return;

   double session_high = m_src_high[ArrayMaximum(m_src_high, start_bar, end_bar - start_bar + 1)];
   double session_low = m_src_low[ArrayMinimum(m_src_low, start_bar, end_bar - start_bar + 1)];

   string box_name = m_prefix + "Box_" + (string)session_id;
   if(ObjectFind(0, box_name) < 0)
     {
      ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, time[start_bar], session_high, time[end_bar], session_low);
      ObjectSetInteger(0, box_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, box_name, OBJPROP_FILL, m_fill_box);
     }
   else
     {
      ObjectMove(0, box_name, 0, time[start_bar], session_high);
      ObjectMove(0, box_name, 1, time[end_bar], session_low);
     }

// --- Calculation for Mean and Linear Regression Lines ---
// NOTE: The calculation is based on the m_src_price array, which is determined by the user's InpSourcePrice input.
// The standard MT5 Regression Channel object calculates its centerline based on PRICE_MEDIAN ((High+Low)/2).
// To match the built-in object perfectly, the user must select PRICE_MEDIAN as the source price.
// Using other sources like PRICE_TYPICAL or PRICE_CLOSE will result in a valid, but different, regression line.
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
           }
        }
     }
  }

//+------------------------------------------------------------------+
bool CSessionAnalyzer::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
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
class CSessionAnalyzer_HA : public CSessionAnalyzer
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type) override;
  };
//+------------------------------------------------------------------+
bool CSessionAnalyzer_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[], ENUM_APPLIED_PRICE price_type)
  {
   double ha_open[], ha_high[], ha_low[], ha_close[];
   ArrayResize(ha_open,  rates_total);
   ArrayResize(ha_high,  rates_total);
   ArrayResize(ha_low,   rates_total);
   ArrayResize(ha_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
   ArrayCopy(m_src_high,  ha_high,  0, 0, rates_total);
   ArrayCopy(m_src_low,   ha_low,   0, 0, rates_total);
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
      default:
         ArrayCopy(m_src_price, ha_close, 0, 0, rates_total);
         break;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
