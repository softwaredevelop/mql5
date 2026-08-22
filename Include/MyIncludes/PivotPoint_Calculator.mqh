//+------------------------------------------------------------------+
//|                                        PivotPoint_Calculator.mqh |
//|      Engine for calculating various Pivot Point types.           |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.10"

enum ENUM_PIVOT_TYPE
  {
   PIVOT_CLASSIC,
   PIVOT_FIBONACCI,
   PIVOT_WOODIE,
   PIVOT_CAMARILLA,
   PIVOT_DEMARK
  };

enum ENUM_PIVOT_SOURCE
  {
   PIVOT_SRC_STANDARD,
   PIVOT_SRC_HEIKIN_ASHI
  };

struct PivotLevels
  {
   double            PP;
   double            R1, R2, R3;
   double            S1, S2, S3;
   datetime          period_start;
  };

//+==================================================================+
//|             CLASS: CPivotPointCalculator                         |
//+==================================================================+
class CPivotPointCalculator
  {
protected:
   ENUM_PIVOT_TYPE   m_type;
   ENUM_PIVOT_SOURCE m_source;

   // Cache for O(1) performance
   datetime          m_last_calc_time;
   PivotLevels       m_last_levels;

public:
                     CPivotPointCalculator(void) : m_last_calc_time(0) {};
   virtual          ~CPivotPointCalculator(void) {};

   bool              Init(ENUM_PIVOT_TYPE type, ENUM_PIVOT_SOURCE source);
   bool              CalculateLevels(datetime current_time, ENUM_TIMEFRAMES tf, PivotLevels &out_levels);
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CPivotPointCalculator::Init(ENUM_PIVOT_TYPE type, ENUM_PIVOT_SOURCE source)
  {
   m_type = type;
   m_source = source;
   m_last_calc_time = 0;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate Levels                                                 |
//+------------------------------------------------------------------+
bool CPivotPointCalculator::CalculateLevels(datetime current_time, ENUM_TIMEFRAMES tf, PivotLevels &out_levels)
  {
   int current_bar_shift = iBarShift(_Symbol, tf, current_time, false);
   if(current_bar_shift < 0)
      return false;

   datetime htf_time = iTime(_Symbol, tf, current_bar_shift);
   if(htf_time == 0)
      return false;

// Optimization: Return cached result if same HTF bar
   if(htf_time == m_last_calc_time && m_last_calc_time != 0)
     {
      out_levels = m_last_levels;
      return true;
     }

// Fetch completed previous HTF bar data
   int htf_index = current_bar_shift + 1;

   double o_arr[1], h_arr[1], l_arr[1], c_arr[1];

   if(CopyOpen(_Symbol, tf, htf_index, 1, o_arr) <= 0 ||
      CopyHigh(_Symbol, tf, htf_index, 1, h_arr) <= 0 ||
      CopyLow(_Symbol, tf, htf_index, 1, l_arr) <= 0 ||
      CopyClose(_Symbol, tf, htf_index, 1, c_arr) <= 0)
      return false;

   double O = o_arr[0];
   double H = h_arr[0];
   double L = l_arr[0];
   double C = c_arr[0];

// Heikin Ashi Transformation
   if(m_source == PIVOT_SRC_HEIKIN_ASHI)
     {
      double ha_close = (O + H + L + C) / 4.0;

      double po_arr[1], pc_arr[1];
      if(CopyOpen(_Symbol, tf, htf_index + 1, 1, po_arr) > 0 &&
         CopyClose(_Symbol, tf, htf_index + 1, 1, pc_arr) > 0)
        {
         double ha_open = (po_arr[0] + pc_arr[0]) / 2.0;
         double ha_high = MathMax(H, MathMax(ha_open, ha_close));
         double ha_low  = MathMin(L, MathMin(ha_open, ha_close));

         O = ha_open;
         H = ha_high;
         L = ha_low;
         C = ha_close;
        }
     }

   double range = H - L;

   switch(m_type)
     {
      case PIVOT_CLASSIC:
         out_levels.PP = (H + L + C) / 3.0;
         out_levels.R1 = 2.0 * out_levels.PP - L;
         out_levels.S1 = 2.0 * out_levels.PP - H;
         out_levels.R2 = out_levels.PP + range;
         out_levels.S2 = out_levels.PP - range;
         out_levels.R3 = H + 2.0 * (out_levels.PP - L);
         out_levels.S3 = L - 2.0 * (H - out_levels.PP);
         break;

      case PIVOT_FIBONACCI:
         out_levels.PP = (H + L + C) / 3.0;
         out_levels.R1 = out_levels.PP + 0.382 * range;
         out_levels.S1 = out_levels.PP - 0.382 * range;
         out_levels.R2 = out_levels.PP + 0.618 * range;
         out_levels.S2 = out_levels.PP - 0.618 * range;
         out_levels.R3 = out_levels.PP + 1.000 * range;
         out_levels.S3 = out_levels.PP - 1.000 * range;
         break;

      case PIVOT_WOODIE:
         out_levels.PP = (H + L + 2.0 * C) / 4.0;
         out_levels.R1 = 2.0 * out_levels.PP - L;
         out_levels.S1 = 2.0 * out_levels.PP - H;
         out_levels.R2 = out_levels.PP + range;
         out_levels.S2 = out_levels.PP - range;
         out_levels.R3 = H + 2.0 * (out_levels.PP - L);
         out_levels.S3 = L - 2.0 * (H - out_levels.PP);
         break;

      case PIVOT_CAMARILLA:
         out_levels.PP = (H + L + C) / 3.0;
         out_levels.R3 = C + range * 1.1 / 4.0;
         out_levels.S3 = C - range * 1.1 / 4.0;
         out_levels.R2 = C + range * 1.1 / 6.0;
         out_levels.S2 = C - range * 1.1 / 6.0;
         out_levels.R1 = C + range * 1.1 / 12.0;
         out_levels.S1 = C - range * 1.1 / 12.0;
         break;

      case PIVOT_DEMARK:
        {
         double X;
         if(C < O)
            X = H + 2.0 * L + C;
         else
            if(C > O)
               X = 2.0 * H + L + C;
            else
               X = H + L + 2.0 * C;

         out_levels.PP = X / 4.0;
         out_levels.R1 = X / 2.0 - L;
         out_levels.S1 = X / 2.0 - H;
         out_levels.R2 = EMPTY_VALUE;
         out_levels.S2 = EMPTY_VALUE;
         out_levels.R3 = EMPTY_VALUE;
         out_levels.S3 = EMPTY_VALUE;
         break;
        }
     }

   out_levels.period_start = htf_time;

// Store Cache
   m_last_calc_time = htf_time;
   m_last_levels    = out_levels;

   return true;
  }
//+------------------------------------------------------------------+
