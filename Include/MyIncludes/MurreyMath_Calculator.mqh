//+------------------------------------------------------------------+
//|                                        MurreyMath_Calculator.mqh |
//|                             Calculation engine for Murrey Math.  |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMurreyMathCalculator
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_period;
   int               m_step_back;

public:
                     CMurreyMathCalculator(void);
                    ~CMurreyMathCalculator(void) {};

   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, int step_back);
   bool              Calculate(double &levels[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMurreyMathCalculator::CMurreyMathCalculator(void) : m_period(64), m_step_back(0)
  {
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CMurreyMathCalculator::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, int step_back)
  {
   m_symbol    = symbol;
   m_timeframe = timeframe;
   m_period    = period;
   m_step_back = step_back;
   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation Method (Original Logic Preserved)               |
//+------------------------------------------------------------------+
bool CMurreyMathCalculator::Calculate(double &levels[])
  {
   if(ArraySize(levels) < 13)
      ArrayResize(levels, 13);

   int bars_to_copy = m_period + m_step_back;
   if(bars_to_copy <= 0)
      bars_to_copy = 1;

//--- 1. Check available bars (Safety check)
   int bars_available = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars_available < bars_to_copy)
      return false; // Not enough data yet

   double htf_high[], htf_low[];

//--- 2. Copy Data
   int copied_high = CopyHigh(m_symbol, m_timeframe, 0, bars_to_copy, htf_high);
   int copied_low  = CopyLow(m_symbol, m_timeframe, 0, bars_to_copy, htf_low);

   if(copied_high < bars_to_copy || copied_low < bars_to_copy)
      return false; // Copy failed

//--- 3. Set as non-series for calculation
   ArraySetAsSeries(htf_high, false);
   ArraySetAsSeries(htf_low, false);

   int rates_total = ArraySize(htf_high);
   int start_pos = rates_total - 1 - m_step_back;

//--- 4. Find High/Low in range
   int min_idx = ArrayMinimum(htf_low, start_pos - m_period + 1, m_period);
   int max_idx = ArrayMaximum(htf_high, start_pos - m_period + 1, m_period);

   if(min_idx < 0 || max_idx < 0)
      return false;

   double v1 = htf_low[min_idx];
   double v2 = htf_high[max_idx];

//--- 5. Murrey Math Algorithm (Original)
   double fractal = 0;
   if((v2 <= 250000) && (v2 > 25000))
      fractal = 100000;
   else
      if((v2 <= 25000) && (v2 > 2500))
         fractal = 10000;
      else
         if((v2 <= 2500) && (v2 > 250))
            fractal = 1000;
         else
            if((v2 <= 250) && (v2 > 25))
               fractal = 100;
            else
               if((v2 <= 25) && (v2 > 12.5))
                  fractal = 12.5;
               else
                  if((v2 <= 12.5) && (v2 > 6.25))
                     fractal = 12.5;
                  else
                     if((v2 <= 6.25) && (v2 > 3.125))
                        fractal = 6.25;
                     else
                        if((v2 <= 3.125) && (v2 > 1.5625))
                           fractal = 3.125;
                        else
                           if((v2 <= 1.5625) && (v2 > 0.390625))
                              fractal = 1.5625;
                           else
                              if((v2 <= 0.390625) && (v2 > 0))
                                 fractal = 0.1953125;

   if(fractal == 0)
      return false;

   double range = v2 - v1;
   if(range <= 0)
      return false;

   double sum = MathFloor(MathLog(fractal / range) / MathLog(2));
   double octave = fractal * (MathPow(0.5, sum));
   double mn = MathFloor(v1 / octave) * octave;
   double mx;
   if(mn + octave > v2)
      mx = mn + octave;
   else
      mx = mn + (2 * octave);

   double x1=0, x2=0, x3=0, x4=0, x5=0, x6=0;
   if((v1 >= (3 * (mx - mn) / 16 + mn)) && (v2 <= (9 * (mx - mn) / 16 + mn)))
      x2 = mn + (mx - mn) / 2;
   if((v1 >= (mn - (mx - mn) / 8)) && (v2 <= (5 * (mx - mn) / 8 + mn)) && (x2 == 0))
      x1 = mn + (mx - mn) / 2;
   if((v1 >= (mn + 7 * (mx - mn) / 16)) && (v2 <= (13 * (mx - mn) / 16 + mn)))
      x4 = mn + 3 * (mx - mn) / 4;
   if((v1 >= (mn + 3 * (mx - mn) / 8)) && (v2 <= (9 * (mx - mn) / 8 + mn)) && (x4 == 0))
      x5 = mx;
   if((v1 >= (mn + (mx - mn) / 8)) && (v2 <= (7 * (mx - mn) / 8 + mn)) && (x1 == 0) && (x2 == 0) && (x4 == 0) && (x5 == 0))
      x3 = mn + 3 * (mx - mn) / 4;
   if((x1 + x2 + x3 + x4 + x5) == 0)
      x6 = mx;

   double finalH = x1 + x2 + x3 + x4 + x5 + x6;

   double y1=0, y2=0, y3=0, y4=0, y5=0, y6=0;
   if(x1 > 0)
      y1 = mn;
   if(x2 > 0)
      y2 = mn + (mx - mn) / 4;
   if(x3 > 0)
      y3 = mn + (mx - mn) / 4;
   if(x4 > 0)
      y4 = mn + (mx - mn) / 2;
   if(x5 > 0)
      y5 = mn + (mx - mn) / 2;
   if((finalH > 0) && ((y1 + y2 + y3 + y4 + y5) == 0))
      y6 = mn;

   double finalL = y1 + y2 + y3 + y4 + y5 + y6;

   double dmml = (finalH - finalL) / 8;
   if(dmml <= 0)
      return false;

   levels[0] = (finalL - dmml * 2);
   for(int i = 1; i < 13; i++)
      levels[i] = levels[i - 1] + dmml;

   return true;
  }
//+------------------------------------------------------------------+
