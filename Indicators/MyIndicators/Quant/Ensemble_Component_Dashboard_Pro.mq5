//+------------------------------------------------------------------+
//|                                Ensemble_Component_Dashboard_Pro.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "3.00" // Enterprise Edition: Single-Asset 9-Component Grid Inspector HUD
#property description "Institutional Single-Asset Ensemble Component Inspector HUD."
#property description "Renders a robust flat-grid dashboard detailing votes, weights, and ratings for all 9 models."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Included Engines & Core Tools ---
#include <MyIncludes\Ensemble_Voting_Calculator.mqh>
#include <MyIncludes\DataSync_Tools.mqh>

//--- Input Parameters ---
input group "=== Timeframe & Analysis Horizon ==="
input ENUM_TIMEFRAMES           InpTimeframe             = PERIOD_CURRENT;       // Calculation Timeframe (Current or HTF)

input group "=== Universal Price & Consensus Thresholds ==="
input ENUM_APPLIED_PRICE_HA_ALL InpSourcePrice           = PRICE_CLOSE_STD;      // Global Price Source (Standard / HA)
input int                       InpSignalThreshold       = 20;                   // Buy / Sell Threshold Level
input int                       InpStrongThreshold       = 60;                   // Strong Consensus Threshold Level
input int                       InpConsensusSmoothing    = 3;                    // Consensus Smoothing (EMA Length)
input double                    InpNeutralZone           = 5.0;                  // Component Neutral Zone (Half-Width around 50)

input group "=== Signal Line Settings ==="
input int                       InpSignalPeriod          = 9;                    // Internal Signal MA Period
input ENUM_MA_TYPE              InpSignalMAType          = EMA;                  // Internal Signal MA Algorithm

input group "=== 1. Trend Components ==="
input bool                      InpMaCrossEnable         = true;                 // EMA Cross Voter
input double                    InpMaCrossWeight         = 1.0;                  // EMA Cross Weight
input int                       InpMaCrossFast           = 20;                   // Fast EMA Length
input int                       InpMaCrossSlow           = 50;                   // Slow EMA Length
input bool                      InpPriceMaEnable         = true;                 // Price vs SMA Voter
input double                    InpPriceMaWeight         = 1.0;                  // Price vs SMA Weight
input int                       InpPriceMaLength         = 200;                  // Trend SMA Length (Macro Baseline)

input group "=== 2. Momentum Components ==="
input bool                      InpRsiEnable             = true;                 // RSI Voter
input double                    InpRsiWeight             = 1.0;                  // RSI Weight
input int                       InpRsiLength             = 14;                   // RSI Lookback Length
input bool                      InpMacdEnable            = true;                 // MACD Voter
input double                    InpMacdWeight            = 1.0;                  // MACD Weight
input int                       InpMacdFast              = 12;                   // MACD Fast EMA
input int                       InpMacdSlow              = 26;                   // MACD Slow EMA
input int                       InpMacdSignal            = 9;                    // MACD Signal EMA
input bool                      InpStochEnable           = true;                 // Fast Stochastic %K Voter
input double                    InpStochWeight           = 1.0;                  // Fast Stochastic %K Weight
input int                       InpStochLength           = 14;                   // Fast %K Lookback Length
input int                       InpStochSmooth           = 3;                    // %D Smoothing Length

input group "=== 3. Channel & Volatility Components ==="
input bool                      InpBbEnable              = true;                 // Bollinger %B Voter
input double                    InpBbWeight              = 1.0;                  // Bollinger %B Weight
input int                       InpBbLength              = 20;                   // Bollinger Bands Length
input double                    InpBbMult                = 2.0;                  // Bollinger Bands Deviation Multiplier
input bool                      InpDonchianEnable        = true;                 // Donchian Position Voter
input double                    InpDonchianWeight        = 1.0;                  // Donchian Position Weight
input int                       InpDonchianLength        = 20;                   // Donchian Channel Lookback

input group "=== 4. Volume Components ==="
input bool                      InpObvEnable             = true;                 // OBV Trend Voter
input double                    InpObvWeight             = 1.0;                  // OBV Trend Weight
input int                       InpObvLength             = 20;                   // OBV Signal EMA Length
input bool                      InpMfiEnable             = true;                 // MFI Voter
input double                    InpMfiWeight             = 1.0;                  // MFI Weight
input int                       InpMfiLength             = 14;                   // MFI Lookback Length

input group "=== Dashboard Placement & Typography ==="
input ENUM_BASE_CORNER          InpDashboardCorner       = CORNER_LEFT_UPPER;    // Dashboard Anchor Corner
input int                       InpTableX                = 20;                   // Table X Offset (Pixels)
input int                       InpTableY                = 35;                   // Table Y Offset (Pixels)
input int                       InpFontSize              = 8;                    // UI Font Size
input int                       InpRefreshSeconds        = 2;                    // Background Timer Fallback (Seconds)

//--- Global Variables ---
string g_prefix         = "";
bool   g_updating       = false;
ulong  g_last_update_ms = 0;

//+------------------------------------------------------------------+
//| Helper: Create Flat Dashboard Cell Button                        |
//+------------------------------------------------------------------+
void CreateCell(const string name, const string text, const int x, const int y, const int w, const int h,
                const color bg_color, const color text_color, const bool selectable = false)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
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
//| Render Full Single-Asset Component Inspector Grid                |
//+------------------------------------------------------------------+
void RenderComponentHUD()
  {
   if(g_updating)
      return;
   g_updating = true;

   ENUM_TIMEFRAMES calc_tf = InpTimeframe;
   if(calc_tf == PERIOD_CURRENT)
      calc_tf = (ENUM_TIMEFRAMES)Period();

   int required_bars = 220;

// 1. Data Readiness Check
   if(!CDataSync::EnsureHTFDataReady(_Symbol, calc_tf, required_bars))
     {
      g_updating = false;
      return;
     }

   int bars_avail = iBars(_Symbol, calc_tf);
   if(bars_avail < required_bars)
     {
      g_updating = false;
      return;
     }

   int count = MathMin(bars_avail, 1000);

// 2. Fetch Atomic OHLCV Data
   MqlRates rates[];
   if(CopyRates(_Symbol, calc_tf, 0, count, rates) != count)
     {
      g_updating = false;
      return;
     }

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

   long vol_limit = (long)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   for(int i = 0; i < count; i++)
     {
      h_open[i]  = rates[i].open;
      h_high[i]  = rates[i].high;
      h_low[i]   = rates[i].low;
      h_close[i] = rates[i].close;
      h_vol[i]   = (vol_limit > 0 && rates[i].real_volume > 0) ? (double)rates[i].real_volume : (double)rates[i].tick_volume;
     }

// 3. Stack-Instantiated Headless Calculator (Zero Heap Leak, 100% Thread Safe!)
   CEnsembleVotingCalculator calc;
   if(!calc.Init(InpNeutralZone, InpConsensusSmoothing, InpSignalPeriod, InpSignalMAType, InpSourcePrice,
                 InpMaCrossEnable, InpMaCrossWeight, InpMaCrossFast, InpMaCrossSlow,
                 InpPriceMaEnable, InpPriceMaWeight, InpPriceMaLength,
                 InpRsiEnable, InpRsiWeight, InpRsiLength,
                 InpMacdEnable, InpMacdWeight, InpMacdFast, InpMacdSlow, InpMacdSignal,
                 InpStochEnable, InpStochWeight, InpStochLength, InpStochSmooth,
                 InpBbEnable, InpBbWeight, InpBbLength, InpBbMult,
                 InpDonchianEnable, InpDonchianWeight, InpDonchianLength,
                 InpObvEnable, InpObvWeight, InpObvLength,
                 InpMfiEnable, InpMfiWeight, InpMfiLength))
     {
      g_updating = false;
      return;
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

// Extract Component Snapshot & Metrics
   SComponentVote comps[];
   int bull_v = 0, bear_v = 0, neut_v = 0;
   calc.GetLatestSnapshot(comps, bull_v, bear_v, neut_v);

   int target_bar = count - 1;
   double current_consensus = consensus_out[target_bar];
   double current_agreement = agree_out[target_bar];

// 4. GUI Grid Geometry (Pixel Math)
   int col_w_comp = 105;
   int col_w_fam  = 75;
   int col_w_vote = 70;
   int col_w_wgt  = 45;
   int total_w    = col_w_comp + col_w_fam + col_w_vote + col_w_wgt + 6;
   int row_h      = 20;

// Header Row
   int cur_y = InpTableY;
   string tf_str = StringSubstr(EnumToString(calc_tf), 7);
   string title_txt = StringFormat("ENSEMBLE: %s (%s)", _Symbol, tf_str);

   CreateCell(g_prefix + "H_Title", title_txt, InpTableX, cur_y, total_w, row_h, clrDarkSlateGray, clrWhite);
   cur_y += row_h + 2;

// Column Sub-Headers
   int cur_x = InpTableX;
   CreateCell(g_prefix + "TH_Comp", "Component", cur_x, cur_y, col_w_comp, row_h, C'40,40,40', clrSilver);
   cur_x += col_w_comp + 2;
   CreateCell(g_prefix + "TH_Fam",  "Family",    cur_x, cur_y, col_w_fam,  row_h, C'40,40,40', clrSilver);
   cur_x += col_w_fam + 2;
   CreateCell(g_prefix + "TH_Vote", "Vote",      cur_x, cur_y, col_w_vote, row_h, C'40,40,40', clrSilver);
   cur_x += col_w_vote + 2;
   CreateCell(g_prefix + "TH_Wgt",  "Weight",    cur_x, cur_y, col_w_wgt,  row_h, C'40,40,40', clrSilver);
   cur_y += row_h + 2;

// 5. Render 9 Component Rows
   int total_comps = ArraySize(comps);
   for(int i = 0; i < total_comps; i++)
     {
      string v_str = "— NEUT";
      color  v_bg  = clrWhite;
      color  v_txt = clrDarkGray;

      if(comps[i].enabled && comps[i].is_valid)
        {
         if(comps[i].vote > 0)
           {
            v_str = "▲ BULL";
            v_bg = clrMediumSeaGreen;
            v_txt = clrWhite;
           }
         else
            if(comps[i].vote < 0)
              {
               v_str = "▼ BEAR";
               v_bg = clrCrimson;
               v_txt = clrWhite;
              }
            else
              {
               v_str = "— NEUT";
               v_bg = clrWhite;
               v_txt = clrDarkGray;
              }
        }
      else
         if(!comps[i].enabled)
           {
            v_str = "DISABLED";
            v_bg  = C'25,25,25';
            v_txt = clrGray;
           }

      color row_bg  = (i % 2 == 0) ? C'32,32,32' : C'26,26,26';
      color comp_txt = comps[i].enabled ? clrWhite : clrGray;

      cur_x = InpTableX;
      CreateCell(g_prefix + StringFormat("R_Comp_%d", i), comps[i].name, cur_x, cur_y, col_w_comp, row_h, row_bg, comp_txt);
      cur_x += col_w_comp + 2;
      CreateCell(g_prefix + StringFormat("R_Fam_%d",  i), comps[i].family, cur_x, cur_y, col_w_fam,  row_h, row_bg, clrSilver);
      cur_x += col_w_fam + 2;
      CreateCell(g_prefix + StringFormat("R_Vote_%d", i), v_str, cur_x, cur_y, col_w_vote, row_h, v_bg, v_txt);
      cur_x += col_w_vote + 2;
      CreateCell(g_prefix + StringFormat("R_Wgt_%d",  i), StringFormat("%.1f", comps[i].weight), cur_x, cur_y, col_w_wgt, row_h, row_bg, clrSilver);

      cur_y += row_h + 2;
     }

// 6. Summary Footer: Vote Tallies Row
   cur_x = InpTableX;
   int w_half = (total_w - 4) / 3;
   CreateCell(g_prefix + "F_Bull", StringFormat("▲ Bull: %d", bull_v), cur_x, cur_y, w_half, row_h, C'20,50,30', clrLightGreen);
   cur_x += w_half + 2;
   CreateCell(g_prefix + "F_Bear", StringFormat("▼ Bear: %d", bear_v), cur_x, cur_y, w_half, row_h, C'60,20,20', clrLightCoral);
   cur_x += w_half + 2;
   CreateCell(g_prefix + "F_Neut", StringFormat("— Neut: %d", neut_v), cur_x, cur_y, total_w - (w_half * 2 + 4), row_h, C'35,35,35', clrWhite);
   cur_y += row_h + 2;

// 7. Summary Footer: Consensus & Agreement Row
   cur_x = InpTableX;
   int w_cons = (total_w - 2) / 2;
   color cons_bg = (current_consensus > 0.0) ? C'15,45,25' : (current_consensus < 0.0 ? C'55,15,15' : C'30,30,30');
   color cons_txt = (current_consensus > 0.0) ? clrLightGreen : (current_consensus < 0.0 ? clrLightCoral : clrWhite);

   string cons_str = StringFormat("Consensus: %s%.1f", (current_consensus > 0.0 ? "+" : ""), current_consensus);
   string agree_str = StringFormat("Agreement: %.0f%%", current_agreement);

   CreateCell(g_prefix + "F_Cons", cons_str, cur_x, cur_y, w_cons, row_h, cons_bg, cons_txt);
   cur_x += w_cons + 2;
   CreateCell(g_prefix + "F_Agr", agree_str, cur_x, cur_y, total_w - w_cons - 2, row_h, C'30,30,30', clrWhite);
   cur_y += row_h + 2;

// 8. Rating Badge Banner (Full Width Highlight)
   string badge_txt = "RATING: NEUTRAL";
   color  badge_bg  = clrDarkGray;
   color  badge_txt_col = clrWhite;

   if(current_consensus >= (double)InpStrongThreshold)
     {
      badge_txt = "RATING: STRONG BUY";
      badge_bg  = clrMediumSeaGreen;
     }
   else
      if(current_consensus >= (double)InpSignalThreshold)
        {
         badge_txt = "RATING: BUY";
         badge_bg  = clrSeaGreen;
        }
      else
         if(current_consensus <= -(double)InpStrongThreshold)
           {
            badge_txt = "RATING: STRONG SELL";
            badge_bg  = clrCrimson;
           }
         else
            if(current_consensus <= -(double)InpSignalThreshold)
              {
               badge_txt = "RATING: SELL";
               badge_bg  = clrIndianRed;
              }

   CreateCell(g_prefix + "F_Rating", badge_txt, InpTableX, cur_y, total_w, row_h + 2, badge_bg, badge_txt_col);

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
   g_prefix = StringFormat("ENS_HUD_%I64d_", ChartID());

   ObjectsDeleteAll(0, g_prefix);

   RenderComponentHUD();

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
      RenderComponentHUD();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnTimer Event Handler                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   RenderComponentHUD();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
