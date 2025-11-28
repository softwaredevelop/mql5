//+------------------------------------------------------------------+
//|                                            MurreyMath_Drawer.mqh |
//|                               Handles graphical objects for MML. |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMurreyMathDrawer
  {
private:
   long              m_chart_id;
   string            m_prefix;
   string            m_font_face;
   int               m_font_size;
   bool              m_label_side_right; // Converted from enum in Init

   color             m_colors[13];
   int               m_widths[13];
   string            m_line_text[13];

   void              CreateOrMoveHLine(int index, double price);
   void              CreateOrMoveText(int index, datetime time, double price);

public:
                     CMurreyMathDrawer(void);
                    ~CMurreyMathDrawer(void);

   void              Init(string prefix, string font, int size, bool right_side);
   void              SetLineStyles(const color &colors[], const int &widths[]);
   void              Draw(const datetime &time[], const double &levels[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMurreyMathDrawer::CMurreyMathDrawer(void) : m_chart_id(0)
  {
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
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMurreyMathDrawer::~CMurreyMathDrawer(void)
  {
   if(m_chart_id != 0 && m_prefix != "")
      ObjectsDeleteAll(m_chart_id, m_prefix);
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::Init(string prefix, string font, int size, bool right_side)
  {
   m_chart_id = ChartID();
   m_prefix = prefix;
   m_font_face = font;
   m_font_size = size;
   m_label_side_right = right_side;

// Cleanup old objects immediately
   ObjectsDeleteAll(m_chart_id, m_prefix);
  }

//+------------------------------------------------------------------+
//| Set Styles                                                       |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::SetLineStyles(const color &colors[], const int &widths[])
  {
   ArrayCopy(m_colors, colors);
   ArrayCopy(m_widths, widths);
  }

//+------------------------------------------------------------------+
//| Main Draw Method                                                 |
//+------------------------------------------------------------------+
void CMurreyMathDrawer::Draw(const datetime &time[], const double &levels[])
  {
   int rates_total = ArraySize(time);
   if(rates_total < 2)
      return;

   int first_bar_idx = (int)ChartGetInteger(m_chart_id, CHART_FIRST_VISIBLE_BAR, 0);

// Logic for label positioning based on original code
   if(m_label_side_right)
     {
      first_bar_idx = 1; // Or logic to push to right
     }

   if(first_bar_idx < 1 || first_bar_idx >= rates_total)
      return;

   datetime label_time = time[first_bar_idx - 1];

   for(int i = 0; i < 13; i++)
     {
      CreateOrMoveHLine(i, levels[i]);
      CreateOrMoveText(i, label_time, levels[i]);
     }

   ChartRedraw(m_chart_id);
  }

//+------------------------------------------------------------------+
//| Helper: Create/Move Line                                         |
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
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectMove(m_chart_id, name, 0, 0, price);
     }
  }

//+------------------------------------------------------------------+
//| Helper: Create/Move Text                                         |
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
      ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectMove(m_chart_id, name, 0, time, price);
     }
  }
//+------------------------------------------------------------------+
