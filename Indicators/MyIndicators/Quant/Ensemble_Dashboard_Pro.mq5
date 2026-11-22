//+------------------------------------------------------------------+
//|                                     Ensemble_Dashboard_Pro.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.00" // Enterprise Edition: Multi-Asset Dual-Horizon Consensus Scanner
#property description "Multi-Asset Dual-Horizon Ensemble Consensus Scanner with 1-Click Chart Switching."
#property description "Aggregates 9 indicators across Trend, Momentum, Volatility, and Volume into real-time ratings."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Included Engines & Core Tools ---
#include <MyIncludes\Ensemble_Voting_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Asset Selection Settings ==="
input string            InpCustomSymbols        = "";                    // Custom Symbols (Comma separated, empty for Market Watch)
input int               InpMaxSymbols           = 12;                    // Maximum Symbols to Display
input int               InpRefreshSeconds       = 3;                     // Background Timer Fallback (Seconds)

input group "=== Slot 1: Tactical Flow Horizon ==="
input string            InpSlot1Label           = "Tactical";            // Slot 1 Custom Label
input ENUM_TIMEFRAMES   InpSlot1TF              = PERIOD_M15;            // Slot 1 Timeframe

input group "=== Slot 2: Strategic Context Horizon ==="
input string            InpSlot2Label           = "Strategic";           // Slot 2 Custom Label
input ENUM_TIMEFRAMES   InpSlot2TF              = PERIOD_H1;             // Slot 2 Timeframe

input group "=== Universal Price & Consensus Thresholds ==="
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice  = PRICE_CLOSE_STD;      // Global Price Source (Standard / HA)
input int               InpSignalThreshold      = 20;                    // Buy / Sell Threshold Level
input int               InpStrongThreshold      = 60;                    // Strong Consensus Threshold Level
input int               InpConsensusSmoothing   = 3;                     // Consensus Smoothing (EMA Length)
input double            InpNeutralZone          = 5.0;                   // Component Neutral Zone (Half-Width around 50)

input group "=== Signal Line Settings ==="
input int               InpSignalPeriod         = 9;                     // Internal Signal MA Period
input ENUM_MA_TYPE      InpSignalMAType         = EMA;                   // Internal Signal MA Algorithm

input group "=== Component Toggles & Weights ==="
input bool              InpMaCrossEnable        = true;                  // 1. EMA Cross Voter
input double            InpMaCrossWeight        = 1.0;                   // EMA Cross Weight
input bool              InpPriceMaEnable        = true;                  // 2. Price vs SMA Voter
input double            InpPriceMaWeight        = 1.0;                   // Price vs SMA Weight
input bool              InpRsiEnable            = true;                  // 3. RSI Voter
input double            InpRsiWeight            = 1.0;                   // RSI Weight
input bool              InpMacdEnable           = true;                  // 4. MACD Voter
input double            InpMacdWeight           = 1.0;                   // MACD Weight
input bool              InpStochEnable          = true;                  // 5. Fast Stochastic %K Voter
input double            InpStochWeight          = 1.0;                   // Fast Stochastic %K Weight
input bool              InpBbEnable             = true;                  // 6. Bollinger %B Voter
input double            InpBbWeight             = 1.0;                   // Bollinger %B Weight
input bool              InpDonchianEnable       = true;                  // 7. Donchian Position Voter
input double            InpDonchianWeight       = 1.0;                   // Donchian Position Weight
input bool              InpObvEnable            = true;                  // 8. OBV Trend Voter
input double            InpObvWeight            = 1.0;                   // OBV Trend Weight
input bool              InpMfiEnable            = true;                  // 9. MFI Voter
input double            InpMfiWeight            = 1.0;                   // MFI Weight

input group "=== Dashboard Placement & Typography ==="
input int               InpTableX               = 20;                    // Table X Offset (From Left)
input int               InpTableY               = 35;                    // Table Y Offset (From Top)
input int               InpFontSize             = 8;                     // UI Font Size

//--- Global Variables ---
string g_symbols[];
int    g_symbols_total  = 0;
string g_prefix         = "";
bool   g_updating       = false;
ulong  g_last_update_ms = 0;

//+------------------------------------------------------------------+
//| Data Structure for Snapshot Output per Horizon                   |
//+------------------------------------------------------------------+
struct SEnsembleHorizonData
  {
   double            consensus;
   double            agreement;
   string            rating_text;
   color             bg_color;
   color             text_color;
   bool              is_ready;
  };

//+------------------------------------------------------------------+
//| Helper: Map Score to Rating Badge Properties                     |
//+------------------------------------------------------------------+
void MapScoreToBadge(const double score, string &out_text, color &out_bg, color &out_txt)
  {
   if(score >= (double)InpStrongThreshold)
     {
      out_text = StringFormat("+%.0f STR BUY", score);
      out_bg   = clrMediumSeaGreen;
      out_txt  = clrWhite;
     }
   else
      if(score >= (double)InpSignalThreshold)
        {
         out_text = StringFormat("+%.0f BUY", score);
         out_bg   = clrSeaGreen;
         out_txt  = clrWhite;
        }
      else
         if(score <= -(double)InpStrongThreshold)
           {
            out_text = StringFormat("%.0f STR SELL", score);
            out_bg   = clrCrimson;
            out_txt  = clrWhite;
           }
         else
            if(score <= -(double)InpSignalThreshold)
              {
               out_text = StringFormat("%.0f SELL", score);
               out_bg   = clrIndianRed;
               out_txt  = clrWhite;
              }
            else
              {
               out_text = StringFormat("%s%.0f NEUTRAL", (score > 0 ? "+" : ""), score);
               out_bg   = clrWhite;
               out_txt  = clrDarkGray;
              }
  }

//+------------------------------------------------------------------+
//| Heap-Free Multi-Asset Ensemble Execution Engine (Stack-Based)    |
//+------------------------------------------------------------------+
bool GetEnsembleData(const string symbol, const ENUM_TIMEFRAMES tf, SEnsembleHorizonData &out_data)
  {
   out_data.is_ready = false;
   int required_bars = 220;

// 1. Data Readiness Check
   if(!CDataSync::EnsureHTFDataReady(symbol, tf, required_bars))
      return false;

   int bars_avail = iBars(symbol, tf);
   if(bars_avail < required_bars)
      return false;

   int count = MathMin(bars_avail, 1000);

// 2. Fetch Atomic OHLCV Data
   MqlRates rates[];
   if(CopyRates(symbol, tf, 0, count, rates) != count)
      return false;

   double h_open[], h_high[], h_low[], h_close[];
   double h_vol[];
   ArrayResize(h_open,  count);
   ArraySetAsSeries(h_open,  false);
   ArrayResize(h_high,  count);
   ArraySetAsSeries(h_high,  false);
   ArrayResize(h_low,   count);
   ArraySetAsSeries(h_low,   false);
   ArrayResize(h_close, count);
   ArraySetAsSeries(h_close, false);
   ArrayResize(h_vol,   count);
   ArraySetAsSeries(h_vol,   false);

   long vol_limit = (long)SymbolInfoDouble(symbol, SYMBOL_VOLUME_LIMIT);
   for(int i = 0; i < count; i++)
     {
      h_open[i]  = rates[i].open;
      h_high[i]  = rates[i].high;
      h_low[i]   = rates[i].low;
      h_close[i] = rates[i].close;
      h_vol[i]   = (vol_limit > 0 && rates[i].real_volume > 0) ? (double)rates[i].real_volume : (double)rates[i].tick_volume;
     }

// 3. Stack-Instantiated Calculator (Zero Heap Leak, 100% Thread Safe!)
   CEnsembleVotingCalculator calc;
   if(!calc.Init(InpNeutralZone, InpConsensusSmoothing, InpSignalPeriod, InpSignalMAType, InpSourcePrice,
                 InpMaCrossEnable, InpMaCrossWeight, 20, 50,
                 InpPriceMaEnable, InpPriceMaWeight, 200,
                 InpRsiEnable, InpRsiWeight, 14,
                 InpMacdEnable, InpMacdWeight, 12, 26, 9,
                 InpStochEnable, InpStochWeight, 14, 3,
                 InpBbEnable, InpBbWeight, 20, 2.0,
                 InpDonchianEnable, InpDonchianWeight, 20,
                 InpObvEnable, InpObvWeight, 20,
                 InpMfiEnable, InpMfiWeight, 14))
     {
      return false;
     }

   double consensus_out[], signal_out[], raw_out[], agree_out[];
   ArrayResize(consensus_out, count);
   ArraySetAsSeries(consensus_out, false);
   ArrayResize(signal_out,    count);
   ArraySetAsSeries(signal_out,    false);
   ArrayResize(raw_out,       count);
   ArraySetAsSeries(raw_out,       false);
   ArrayResize(agree_out,     count);
   ArraySetAsSeries(agree_out,     false);

   calc.Calculate(count, 0, h_open, h_high, h_low, h_close, h_vol, consensus_out, signal_out, raw_out, agree_out);

// Extract latest closed bar metrics
   int target_bar = count - 1;
   out_data.consensus = consensus_out[target_bar];
   out_data.agreement = agree_out[target_bar];
   out_data.is_ready  = true;

   MapScoreToBadge(out_data.consensus, out_data.rating_text, out_data.bg_color, out_data.text_color);
   return true;
  }

//+------------------------------------------------------------------+
//| Parse Symbols from Input String or Market Watch                  |
//+------------------------------------------------------------------+
void ParseSymbols()
  {
   ArrayFree(g_symbols);

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
         if(valid_count >= InpMaxSymbols)
            break;
        }
      g_symbols_total = valid_count;
     }
   else
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
         if(count >= InpMaxSymbols)
            break;
        }
      g_symbols_total = count;
     }
  }

//+------------------------------------------------------------------+
//| Helper: Create Flat Dashboard Cell Button                        |
//+------------------------------------------------------------------+
void CreateCell(const string name, const string text, const int x, const int y, const int w, const int h,
                const color bg_color, const color text_color, const bool selectable = false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetString(0,  name, OBJPROP_FONT, "Trebuchet MS");
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

//+------------------------------------------------------------------+
//| Render Full Dual-Horizon Dashboard Grid                          |
//+------------------------------------------------------------------+
void RenderDashboard()
  {
   if(g_updating || g_symbols_total <= 0)
      return;

   g_updating = true;

   int col_w_sym   = 85;
   int col_w_slot1 = 100;
   int col_w_slot2 = 100;
   int col_w_agree = 55;
   int col_w_bias  = 110;
   int row_h       = 20;

// 1. Render Table Header Row
   int header_y = InpTableY;
   string s1_tf = StringSubstr(EnumToString(InpSlot1TF), 7);
   string s2_tf = StringSubstr(EnumToString(InpSlot2TF), 7);

   string s1_head = InpSlot1Label + " (" + s1_tf + ")";
   string s2_head = InpSlot2Label + " (" + s2_tf + ")";

   int cur_x = InpTableX;
   CreateCell(g_prefix + "H_Sym",   "Symbol",     cur_x, header_y, col_w_sym,   row_h, clrDarkSlateGray, clrWhite);
   cur_x += col_w_sym + 2;
   CreateCell(g_prefix + "H_Slot1", s1_head,      cur_x, header_y, col_w_slot1, row_h, clrDarkSlateGray, clrWhite);
   cur_x += col_w_slot1 + 2;
   CreateCell(g_prefix + "H_Slot2", s2_head,      cur_x, header_y, col_w_slot2, row_h, clrDarkSlateGray, clrWhite);
   cur_x += col_w_slot2 + 2;
   CreateCell(g_prefix + "H_Agree", "Agree",      cur_x, header_y, col_w_agree, row_h, clrDarkSlateGray, clrWhite);
   cur_x += col_w_agree + 2;
   CreateCell(g_prefix + "H_Bias",  "Confluence", cur_x, header_y, col_w_bias,  row_h, clrDarkSlateGray, clrWhite);

// 2. Loop and Calculate Each Asset Row
   for(int r = 0; r < g_symbols_total; r++)
     {
      string sym = g_symbols[r];
      int row_y = InpTableY + row_h + 2 + (r * (row_h + 2));

      // Clickable Symbol Button (1-Click Chart Switcher)
      CreateCell(g_prefix + "_SymBtn_" + sym, sym, InpTableX, row_y, col_w_sym, row_h, clrLightGray, clrBlack, true);

      // Compute Slot 1 and Slot 2 Data
      SEnsembleHorizonData data1, data2;
      GetEnsembleData(sym, InpSlot1TF, data1);
      GetEnsembleData(sym, InpSlot2TF, data2);

      // Render Slot 1 Cell
      cur_x = InpTableX + col_w_sym + 2;
      if(data1.is_ready)
         CreateCell(g_prefix + "_S1_" + sym, data1.rating_text, cur_x, row_y, col_w_slot1, row_h, data1.bg_color, data1.text_color);
      else
         CreateCell(g_prefix + "_S1_" + sym, "Sync...", cur_x, row_y, col_w_slot1, row_h, clrWhite, clrSilver);

      // Render Slot 2 Cell
      cur_x += col_w_slot1 + 2;
      if(data2.is_ready)
         CreateCell(g_prefix + "_S2_" + sym, data2.rating_text, cur_x, row_y, col_w_slot2, row_h, data2.bg_color, data2.text_color);
      else
         CreateCell(g_prefix + "_S2_" + sym, "Sync...", cur_x, row_y, col_w_slot2, row_h, clrWhite, clrSilver);

      // Render Agreement Cell
      cur_x += col_w_slot2 + 2;
      if(data1.is_ready)
         CreateCell(g_prefix + "_Agr_" + sym, StringFormat("%.0f%%", data1.agreement), cur_x, row_y, col_w_agree, row_h, clrWhite, clrBlack);
      else
         CreateCell(g_prefix + "_Agr_" + sym, "—", cur_x, row_y, col_w_agree, row_h, clrWhite, clrSilver);

      // Render Macro Confluence Cell
      cur_x += col_w_agree + 2;
      string conf_text = "SYNC";
      color  conf_bg   = clrWhite;
      color  conf_txt  = clrBlack;

      if(data1.is_ready && data2.is_ready)
        {
         bool s1_bull = (data1.consensus >= (double)InpSignalThreshold);
         bool s1_bear = (data1.consensus <= -(double)InpSignalThreshold);
         bool s2_bull = (data2.consensus >= (double)InpSignalThreshold);
         bool s2_bear = (data2.consensus <= -(double)InpSignalThreshold);

         if(s1_bull && s2_bull)
           {
            conf_text = "STRONG BULL";
            conf_bg   = clrMediumSeaGreen;
            conf_txt  = clrWhite;
           }
         else
            if(s1_bear && s2_bear)
              {
               conf_text = "STRONG BEAR";
               conf_bg   = clrCrimson;
               conf_txt  = clrWhite;
              }
            else
               if((s1_bull && s2_bear) || (s1_bear && s2_bull))
                 {
                  conf_text = "CONFLICT";
                  conf_bg   = clrKhaki;
                  conf_txt  = clrBlack;
                 }
               else
                  if(s2_bull && !s1_bear)
                    {
                     conf_text = "PULLBACK (L)";
                     conf_bg   = clrLightCyan;
                     conf_txt  = clrDarkSlateBlue;
                    }
                  else
                     if(s2_bear && !s1_bull)
                       {
                        conf_text = "PULLBACK (S)";
                        conf_bg   = clrMistyRose;
                        conf_txt  = clrDarkRed;
                       }
                     else
                       {
                        conf_text = "NEUTRAL";
                        conf_bg   = clrWhite;
                        conf_txt  = clrDarkGray;
                       }
        }

      CreateCell(g_prefix + "_Conf_" + sym, conf_text, cur_x, row_y, col_w_bias, row_h, conf_bg, conf_txt);
     }

   ChartRedraw(0);
   g_updating = false;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_updating = false;
   g_last_update_ms = 0;
   g_prefix = StringFormat("ENS_DASH_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   ParseSymbols();
   RenderDashboard();

   EventSetTimer(InpRefreshSeconds);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Calculation Loop                                |
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
// Rate throttling: Maximum 5 scans per second (200ms)
   ulong current_ms = GetTickCount64();
   if(current_ms - g_last_update_ms >= 200)
     {
      g_last_update_ms = current_ms;
      RenderDashboard();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderDashboard();
  }

//+------------------------------------------------------------------+
//| OnChartEvent (Interactive 1-Click Chart Switcher)                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam, g_prefix) == 0 && StringFind(sparam, "_SymBtn_") != -1)
        {
         string symbol = ObjectGetString(0, sparam, OBJPROP_TEXT);
         if(symbol != "" && symbol != NULL)
           {
            ChartSetSymbolPeriod(0, symbol, _Period);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw(0);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
