//+------------------------------------------------------------------+
//|                                        Symbol_Switcher_Pro.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "1.20"
#property description "Ultra-Lightweight 3x9 Multi-Asset Symbol Switcher Matrix."
#property description "Clean borderless grid with solid foreground Z-order buttons and 1-click chart switching."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Anchor Corner Enum
enum ENUM_SWITCHER_CORNER
  {
   CORNER_BOTTOM_LEFT = CORNER_LEFT_LOWER, // Anchor: Bottom-Left Corner
   CORNER_TOP_LEFT    = CORNER_LEFT_UPPER  // Anchor: Top-Left Corner
  };

//--- Grid Dimensional Constants
#define GRID_COLUMNS 3
#define GRID_ROWS    9
#define MAX_BUTTONS  27

//--- Input Parameters ---
input group "--- Asset Selection Settings ---"
input string                 InpCustomSymbols   = "";                  // Custom Symbols (Comma separated, empty for Market Watch)

input group "--- Dashboard Placement & Sizing ---"
input ENUM_SWITCHER_CORNER   InpAnchorCorner    = CORNER_BOTTOM_LEFT;  // Dashboard Anchor Corner
input int                    InpTableX          = 20;                  // Offset X (Pixels from Left)
input int                    InpTableY          = 30;                  // Offset Y (Pixels from Corner)
input int                    InpButtonWidth     = 85;                  // Button Width (Pixels)
input int                    InpButtonHeight    = 22;                  // Button Height (Pixels)
input int                    InpGap             = 2;                   // Gap between cells (Pixels)
input int                    InpFontSize        = 9;                   // Font Size

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "--- Color Customization (V-Score Dashboard Palette) ---"
input color                  InpColorActiveBg   = clrDeepSkyBlue;      // Active Symbol Background
input color                  InpColorActiveTxt  = clrWhite;            // Active Symbol Text
input color                  InpColorIdleBg     = clrLightGray;        // Inactive Symbol Background (Solid Gray)
input color                  InpColorIdleTxt    = clrBlack;            // Inactive Symbol Text

//--- Internal State
string g_symbols[];
int    g_symbols_count = 0;
string g_prefix        = "";

//+------------------------------------------------------------------+
//| Parse Symbols from Input String or Market Watch                  |
//+------------------------------------------------------------------+
void ParseSymbols()
  {
   ArrayFree(g_symbols);
   g_symbols_count = 0;

// Mode A: Parse User-Defined Comma-Separated List
   if(InpCustomSymbols != "" && InpCustomSymbols != NULL)
     {
      string temp[];
      int split = StringSplit(InpCustomSymbols, ',', temp);
      int valid_count = 0;

      for(int i = 0; i < split; i++)
        {
         string sym = temp[i];
         StringTrimLeft(sym);
         StringTrimRight(sym);

         if(sym != "" && SymbolInfoInteger(sym, SYMBOL_SELECT) != 0)
           {
            ArrayResize(g_symbols, valid_count + 1);
            g_symbols[valid_count] = sym;
            valid_count++;
           }
         if(valid_count >= MAX_BUTTONS)
            break;
        }
      g_symbols_count = valid_count;
     }
   else // Mode B: Collect from Active Market Watch
     {
      int total = SymbolsTotal(true);
      int count = 0;

      for(int i = 0; i < total; i++)
        {
         string sym = SymbolName(i, true);
         if(sym != "" && sym != NULL)
           {
            ArrayResize(g_symbols, count + 1);
            g_symbols[count] = sym;
            count++;
           }
         if(count >= MAX_BUTTONS)
            break;
        }
      g_symbols_count = count;
     }
  }

//+------------------------------------------------------------------+
//| Create or Update Native Button Primitive (Forefront Z-Order 100) |
//+------------------------------------------------------------------+
void CreateButton(const string name, const string text, const int x, const int y, const int w, const int h, const color bg_color, const color text_color)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, InpAnchorCorner);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0,  name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);       // Pure foreground: above all chart drawings
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);       // Maximum priority
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

//+------------------------------------------------------------------+
//| Render Solid Foreground 3x9 Grid (No Backplate)                  |
//+------------------------------------------------------------------+
void RenderGrid()
  {
   if(g_symbols_count <= 0)
      return;

   int num_rows = MathMin(g_symbols_count, GRID_ROWS);
   string active_chart_sym = _Symbol;

   for(int k = 0; k < g_symbols_count; k++)
     {
      int col = k / GRID_ROWS;
      int row = k % GRID_ROWS;

      if(col >= GRID_COLUMNS)
         break;

      int x = InpTableX + col * (InpButtonWidth + InpGap);
      int y = 0;

      // Coordinate Geometry: Row 0 is visually at the top in both modes
      if(InpAnchorCorner == CORNER_BOTTOM_LEFT)
        {
         y = InpTableY + (num_rows - 1 - row) * (InpButtonHeight + InpGap);
        }
      else // CORNER_TOP_LEFT
        {
         y = InpTableY + row * (InpButtonHeight + InpGap);
        }

      string sym = g_symbols[k];
      string btn_name = g_prefix + "Btn_" + IntegerToString(k);

      // Contrast Active Asset vs Inactive Assets
      bool is_current = (sym == active_chart_sym);
      color bg_col    = is_current ? InpColorActiveBg  : InpColorIdleBg;
      color txt_col   = is_current ? InpColorActiveTxt : InpColorIdleTxt;

      CreateButton(btn_name, sym, x, y, InpButtonWidth, InpButtonHeight, bg_col, txt_col);
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_prefix = StringFormat("SSW_%I64d_", ChartID());

// Clean any prior artifacts from this chart instance
   ObjectsDeleteAll(0, g_prefix);

// Load Asset Manifest
   ParseSymbols();

// Draw Clean Grid
   RenderGrid();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Wipe all graphical objects completely
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation iteration                           |
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
// Zero-overhead mandate: No calculation cycles executed on ticks
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Interactive Chart Event Handler (1-Click Chart Switching)        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
// Intercept User Button Clicks
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam, g_prefix + "Btn_") == 0)
        {
         string target_symbol = ObjectGetString(0, sparam, OBJPROP_TEXT);

         if(target_symbol != "" && target_symbol != NULL)
           {
            // Reset button physical state to prevent sticking
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

            // Switch Active Chart to Selected Symbol (Preserves Chart Timeframe & Indicators)
            if(target_symbol != _Symbol)
              {
               ChartSetSymbolPeriod(0, target_symbol, _Period);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
