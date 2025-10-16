//+------------------------------------------------------------------+
//|                                       Murrey_Math_Line_X.mq5     |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "2.50" // REFACTORED: Robust handling of MTF history loading
#property description "A clean, self-contained, object-oriented Murrey Math Lines indicator with MTF support."

#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| CLASS: CMurreyMathCalculator                                     |
//| Handles the core MTF calculation for Murrey Math levels.         |
//+------------------------------------------------------------------+
class CMurreyMathCalculator
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_period;
   int               m_step_back;

public:
                     CMurreyMathCalculator(string symbol, ENUM_TIMEFRAMES timeframe, int period, int step_back);
                    ~CMurreyMathCalculator(void) {};

   bool              CalculateLevels(double &levels[]);
  };

//+------------------------------------------------------------------+
//| CMurreyMathCalculator: Constructor                               |
//+------------------------------------------------------------------+
CMurreyMathCalculator::CMurreyMathCalculator(string symbol, ENUM_TIMEFRAMES timeframe, int period, int step_back) :
   m_symbol(symbol), m_timeframe(timeframe), m_period(period), m_step_back(step_back)
  {
  }

//+------------------------------------------------------------------+
//| CMurreyMathCalculator: The core MTF calculation algorithm        |
//+------------------------------------------------------------------+
bool CMurreyMathCalculator::CalculateLevels(double &levels[])
  {
   int bars_to_copy = m_period + m_step_back;
   if(bars_to_copy <= 0)
      bars_to_copy = 1;

   double htf_high[], htf_low[];

// REFACTORED: Check available bars before copying to avoid unnecessary errors
   int bars_available = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars_available < bars_to_copy)
     {
      // Silently fail, OnCalculate will try again on the next tick
      return false;
     }

   int copied_high = CopyHigh(m_symbol, m_timeframe, 0, bars_to_copy, htf_high);
   int copied_low = CopyLow(m_symbol, m_timeframe, 0, bars_to_copy, htf_low);

// REFACTORED: Instead of printing an error, just return false.
// This indicates a temporary state, not a fatal error.
   if(copied_high < bars_to_copy || copied_low < bars_to_copy)
     {
      return false;
     }

   ArraySetAsSeries(htf_high, false);
   ArraySetAsSeries(htf_low, false);

   int rates_total = ArraySize(htf_high);
   int start_pos = rates_total - 1 - m_step_back;

   int min_idx = ArrayMinimum(htf_low, start_pos - m_period + 1, m_period);
   int max_idx = ArrayMaximum(htf_high, start_pos - m_period + 1, m_period);

   double v1 = htf_low[min_idx];
   double v2 = htf_high[max_idx];

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
//| CLASS: CMurreyMathDrawer (Unchanged)                             |
//+------------------------------------------------------------------+
class CMurreyMathDrawer
  {
private:
   long              m_chart_id;
   string            m_prefix;
   string            m_font_face;
   int               m_font_size;
   bool              m_label_side_right;
   color             m_colors[13];
   int               m_widths[13];
   string            m_line_text[13];
   void              CreateOrMoveHLine(int index, double price);
   void              CreateOrMoveText(int index, datetime time, double price);
public:
                     CMurreyMathDrawer(string prefix, string font, int size, bool right_side);
                    ~CMurreyMathDrawer(void);
   void              SetLineStyles(const color &colors[], const int &widths[]);
   void              DrawLevels(const datetime &time[], const double &levels[]);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMurreyMathDrawer::CMurreyMathDrawer(string prefix, string font, int size, bool right_side) : m_prefix(prefix), m_font_face(font), m_font_size(size), m_label_side_right(right_side)
  {
   m_chart_id = ChartID();
   m_line_text[0]  = "[-2/8]P Extreme Overshoot";
   m_line_text[1]  = "[-1/8]P Overshoot";
   m_line_text[2]  = "[0/8]P Ultimate Support";
   m_line_text[3]  = "[1/8]P Weak, Stop & Reverse";
   m_line_text[4]  = "[2/8]P Pivot, Reverse";
   m_line_text[5]  = "[3/8]P Bottom of Trading Range";
   m_line_text[6]  = "[4/8]P Major S/R Pivot";
   m_line_text[7]  = "[5/8]P Top of Trading Range";
   m_line_text[8]  = "[6/8]P Pivot, Reverse";
   m_line_text[9]  = "[7/8]P Weak, Stop & Reverse";
   m_line_text[10] = "[8/8]P Ultimate Resistance";
   m_line_text[11] = "[+1/8]P Overshoot";
   m_line_text[12] = "[+2/8]P Extreme Overshoot";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMurreyMathDrawer::~CMurreyMathDrawer(void) { ObjectsDeleteAll(m_chart_id, m_prefix); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::SetLineStyles(const color &colors[], const int &widths[]) { ArrayCopy(m_colors, colors); ArrayCopy(m_widths, widths); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::DrawLevels(const datetime &time[], const double &levels[])
  {
   int rates_total = ArraySize(time);
   if(rates_total < 2)
      return;
   int first_bar_idx = (int)ChartGetInteger(m_chart_id, CHART_FIRST_VISIBLE_BAR, 0);
   if(m_label_side_right)
     {
      first_bar_idx = 1;
     }
   if(first_bar_idx < 1 || first_bar_idx >= rates_total)
      return;
   datetime label_time = time[first_bar_idx - 1];
   for(int i = 0; i < 13; i++)
     {
      CreateOrMoveHLine(i, levels[i]);
      CreateOrMoveText(i, label_time, levels[i]);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::CreateOrMoveHLine(int index, double price)
  {
   string name = m_prefix + "line_" + (string)index;
   if(ObjectFind(m_chart_id, name) < 0)
     {
      ObjectCreate(m_chart_id, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(m_chart_id, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_colors[index]);
      ObjectSetInteger(m_chart_id, name, OBJPROP_WIDTH, m_widths[index]);
      ObjectSetInteger(m_chart_id, name, OBJPROP_BACK, true);
     }
   else
     {
      ObjectMove(m_chart_id, name, 0, 0, price);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::CreateOrMoveText(int index, datetime time, double price)
  {
   string name = m_prefix + "text_" + (string)index;
   if(ObjectFind(m_chart_id, name) < 0)
     {
      ObjectCreate(m_chart_id, name, OBJ_TEXT, 0, time, price);
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, m_line_text[index]);
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, m_font_size);
      ObjectSetString(m_chart_id, name, OBJPROP_FONT, m_font_face);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, m_colors[index]);
      ObjectSetInteger(m_chart_id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
     }
   else
     {
      ObjectMove(m_chart_id, name, 0, time, price);
     }
  }

//+------------------------------------------------------------------+
//| CLASS: CMurreyMathController                                     |
//+------------------------------------------------------------------+
class CMurreyMathController
  {
private:
   CMurreyMathCalculator *m_calculator;
   CMurreyMathDrawer     *m_drawer;
   double            m_mml_levels[13];
public:
                     CMurreyMathController(void);
                    ~CMurreyMathController(void);
   bool              Initialize(ENUM_TIMEFRAMES timeframe, int period, int stepBack, bool labelSideRight, string fontFace, int fontSize, string prefix);
   void              SetLineStyles(const color &colors[], const int &widths[]);
   bool              Update(const datetime &time[]); // REFACTORED: Returns bool for success
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMurreyMathController::CMurreyMathController(void) : m_calculator(NULL), m_drawer(NULL) { ArrayInitialize(m_mml_levels, 0.0); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMurreyMathController::~CMurreyMathController(void) { if(CheckPointer(m_calculator) != POINTER_INVALID) delete m_calculator; if(CheckPointer(m_drawer) != POINTER_INVALID) delete m_drawer; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMurreyMathController::Initialize(ENUM_TIMEFRAMES timeframe, int period, int stepBack, bool labelSideRight, string fontFace, int fontSize, string prefix)
  {
   m_calculator = new CMurreyMathCalculator(_Symbol, timeframe, period, stepBack);
   m_drawer = new CMurreyMathDrawer(prefix, fontFace, fontSize, labelSideRight);
   if(CheckPointer(m_calculator) == POINTER_INVALID || CheckPointer(m_drawer) == POINTER_INVALID)
     {
      Print("Failed to initialize Murrey Math components.");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CMurreyMathController::SetLineStyles(const color &colors[], const int &widths[]) { if(CheckPointer(m_drawer) != POINTER_INVALID) m_drawer.SetLineStyles(colors, widths); }
// REFACTORED: Update now returns true on success, false on failure.
bool CMurreyMathController::Update(const datetime &time[])
  {
   if(m_calculator.CalculateLevels(m_mml_levels))
     {
      m_drawer.DrawLevels(time, m_mml_levels);
      return true; // Success
     }
   return false; // Failure (e.g., not enough history yet)
  }

//--- Indicator Input Parameters (Unchanged) ---
input int InpPeriod = 64;
input ENUM_TIMEFRAMES InpUpperTimeframe = PERIOD_H4;
input int InpStepBack = 0;
enum enum_side { Left, Right };
input enum_side InpLabelSide = Left;
input group "Line Colors"
input color InpClr_m2_8 = clrDimGray;
input color InpClr_m1_8 = clrDimGray;
input color InpClr_0_8  = clrDarkOrange;
input color InpClr_1_8  = clrGoldenrod;
input color InpClr_2_8  = clrFireBrick;
input color InpClr_3_8  = clrSeaGreen;
input color InpClr_4_8  = clrRoyalBlue;
input color InpClr_5_8  = clrSeaGreen;
input color InpClr_6_8  = clrFireBrick;
input color InpClr_7_8  = clrGoldenrod;
input color InpClr_8_8  = clrDarkOrange;
input color InpClr_p1_8 = clrDimGray;
input color InpClr_p2_8 = clrDimGray;
input group "Line Widths"
input int InpWdth_m2_8 = 1;
input int InpWdth_m1_8 = 1;
input int InpWdth_0_8  = 1;
input int InpWdth_1_8  = 1;
input int InpWdth_2_8  = 1;
input int InpWdth_3_8  = 1;
input int InpWdth_4_8  = 1;
input int InpWdth_5_8  = 1;
input int InpWdth_6_8  = 1;
input int InpWdth_7_8  = 1;
input int InpWdth_8_8  = 1;
input int InpWdth_p1_8 = 1;
input int InpWdth_p2_8 = 1;
input group "Labels"
input string InpFontFace = "Verdana";
input int    InpFontSize = 10;
input string InpObjectPrefix = "MML-";

//--- Global controller object ---
CMurreyMathController *g_murreyMath;

//+------------------------------------------------------------------+
//| Custom indicator initialization function (Unchanged)             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_murreyMath = new CMurreyMathController();
   if(CheckPointer(g_murreyMath) == POINTER_INVALID)
     {
      Print("Error creating CMurreyMathController object.");
      return(INIT_FAILED);
     }
   ENUM_TIMEFRAMES calc_timeframe = (InpUpperTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpUpperTimeframe;
   if(!g_murreyMath.Initialize(calc_timeframe, InpPeriod, InpStepBack, (InpLabelSide == Right), InpFontFace, InpFontSize, InpObjectPrefix))
     {
      return(INIT_FAILED);
     }
   color colors[13];
   int widths[13];
   colors[0]=InpClr_m2_8;
   widths[0]=InpWdth_m2_8;
   colors[1]=InpClr_m1_8;
   widths[1]=InpWdth_m1_8;
   colors[2]=InpClr_0_8;
   widths[2]=InpWdth_0_8;
   colors[3]=InpClr_1_8;
   widths[3]=InpWdth_1_8;
   colors[4]=InpClr_2_8;
   widths[4]=InpWdth_2_8;
   colors[5]=InpClr_3_8;
   widths[5]=InpWdth_3_8;
   colors[6]=InpClr_4_8;
   widths[6]=InpWdth_4_8;
   colors[7]=InpClr_5_8;
   widths[7]=InpWdth_5_8;
   colors[8]=InpClr_6_8;
   widths[8]=InpWdth_6_8;
   colors[9]=InpClr_7_8;
   widths[9]=InpWdth_7_8;
   colors[10]=InpClr_8_8;
   widths[10]=InpWdth_8_8;
   colors[11]=InpClr_p1_8;
   widths[11]=InpWdth_p1_8;
   colors[12]=InpClr_p2_8;
   widths[12]=InpWdth_p2_8;
   g_murreyMath.SetLineStyles(colors, widths);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function (Unchanged)           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_murreyMath) != POINTER_INVALID)
      delete g_murreyMath;
  }

//+------------------------------------------------------------------+
//| REFACTORED: Custom indicator iteration function                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(CheckPointer(g_murreyMath) == POINTER_INVALID)
      return 0;

//--- This state variable tracks if the first successful calculation has happened
   static bool is_initialized = false;

//--- Phase 1: Initialization Loop ---
// Keep trying on every tick until the first calculation is successful
   if(!is_initialized)
     {
      if(g_murreyMath.Update(time))
        {
         is_initialized = true; // Success! Move to maintenance phase.
         ChartRedraw();
        }
      else
        {
         // Data not ready yet, try again on the next OnCalculate call.
         // We can draw a "Loading..." text to inform the user.
         Comment("Murrey Math: Loading ", EnumToString(InpUpperTimeframe), " data...");
         return(rates_total);
        }
     }

//--- Phase 2: Maintenance Mode ---
// Once initialized, only update on new HTF bars or chart scrolls.
   Comment(""); // Clear the "Loading..." message
   ArraySetAsSeries(time, true);

   ENUM_TIMEFRAMES calc_timeframe = (InpUpperTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpUpperTimeframe;

   static datetime last_htf_bar_time = 0;
   datetime htf_time[];
   bool new_htf_bar = false;

   if(CopyTime(_Symbol, calc_timeframe, 0, 1, htf_time) > 0)
     {
      if(htf_time[0] > last_htf_bar_time)
        {
         last_htf_bar_time = htf_time[0];
         new_htf_bar = true;
        }
     }

   static int last_first_visible_bar = -1;
   int current_first_visible_bar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   bool chart_scrolled = (current_first_visible_bar != last_first_visible_bar);
   last_first_visible_bar = current_first_visible_bar;

   if(new_htf_bar || chart_scrolled)
     {
      g_murreyMath.Update(time);
      ChartRedraw();
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
