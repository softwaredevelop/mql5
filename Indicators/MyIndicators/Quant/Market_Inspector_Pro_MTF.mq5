//+------------------------------------------------------------------+
//|                                     Market_Inspector_Pro_MTF.mq5 |
//|                    Real-Time Dashboard - iCustom Architecture    |
//|                    Copyright 2026, xxxxxxxx                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Active Trading Panel using MTF Indicators via iCustom."
#property indicator_chart_window
#property indicator_plots 0

//--- Visual Settings
input group             "Visual Layout"
input int               InpXOffset        = 20;
input int               InpYOffset        = 30;
input int               InpFontSize       = 9;
input color             InpColorBase      = clrSilver;
input color             InpColorHead      = clrGold;
input color             InpColorTxt       = clrSilver;
input color             InpColorLbl       = clrGray;
input ENUM_BASE_CORNER  InpCorner         = CORNER_LEFT_UPPER;

//--- Timeframes
input group             "Timeframes"
input ENUM_TIMEFRAMES   InpTFSlow         = PERIOD_H1;  // Context
input ENUM_TIMEFRAMES   InpTFMid          = PERIOD_M15; // Flow
input ENUM_TIMEFRAMES   InpTFFast         = PERIOD_M5;  // Trigger

//--- Indicator Settings (Must match source files!)
input group             "Settings"
input string            InpBenchmark      = "US500";
input string            InpForexBench     = "DX";
input int               InpBetaLookback   = 60;

input int InpVHFPeriod=28;
input int InpR2Period=20;
input int InpVScorePeriod=20;
input int InpAutoCorrPeriod=20;
input int InpATRPeriod=14;
input int InpRVOLPeriod=20;
input double InpLaguerreGamma=0.5;

input int InpTSI_Slow=25;
input int InpTSI_Fast=13;
input int InpTSI_Signal=13;
input int InpSqueezeLength=20;
input double InpBBMult=2.0;
input double InpKCMult=1.5;
input int InpSqueezeMom=12;
input int InpVelPeriod=3;

//--- Handles
int h_alpha_h1, h_beta_h1;
int h_vhf_h1, h_r2_h1, h_tsi_h1;
int h_vscore_m15, h_ac_m15, h_sqz_m15;
int h_vhf_m15, h_r2_m15, h_tsi_m15;
int h_vola_reg_m15; // Uses VolatilityRegime_MTF_Pro
int h_vel_m5, h_tsi_m5;
int h_rvol_m15, h_rvol_m5; // For Thrust & Absorption
int h_atr_m5; // For Cost & Absorption
int h_abs;

// --- Enums needed for iCustom calls (must match source file definition)
enum ENUM_AB_MODE { MODE_ALPHA, MODE_BETA };
enum ENUM_VHF_MODE { VHF_MODE_CLOSE_ONLY, VHF_MODE_HIGH_LOW };
// Need this enum for V-Score Input
enum ENUM_VWAP_PERIOD
  {
   PERIOD_SESSION,
   PERIOD_WEEK,
   PERIOD_MONTH,
   PERIOD_CUSTOM_SESSION
  };

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
// Helper to format path. Assuming indicators are in root or same folder based on terminal.
// Typically iCustom uses "IndicatorName" if in same folder.

// --- H1 HANDLES ---
// AlphaBeta MTF: Params(TF, Mode, Lookback, Bench, ForexBench)
   h_alpha_h1 = iCustom(_Symbol, Period(), "AlphaBeta_MTF_Pro", InpTFSlow, MODE_ALPHA, InpBetaLookback, InpBenchmark, InpForexBench);
   h_beta_h1  = iCustom(_Symbol, Period(), "AlphaBeta_MTF_Pro", InpTFSlow, MODE_BETA, InpBetaLookback, InpBenchmark, InpForexBench);

// VHF MTF: Params(TF, Period, Mode, Price)
   h_vhf_h1   = iCustom(_Symbol, Period(), "VHF_MTF_Pro", InpTFSlow, InpVHFPeriod, VHF_MODE_HIGH_LOW, PRICE_CLOSE);

// R2 MTF: Params(TF, Period, Level)
   h_r2_h1    = iCustom(_Symbol, Period(), "LinReg_R2_MTF_Pro", InpTFSlow, InpR2Period, 0.7);

// TSI MTF: Params(TF, Slow, Fast, Signal, Price)
   h_tsi_h1 = iCustom(_Symbol, Period(), "TSI_MTF_Simple_Pro", InpTFSlow, InpTSI_Slow, InpTSI_Fast, InpTSI_Signal, PRICE_CLOSE);

// --- M15 HANDLES ---
   h_vscore_m15 = iCustom(_Symbol, Period(), "VScore_MTF_Pro", InpTFMid, InpVScorePeriod, PERIOD_SESSION);
   h_ac_m15     = iCustom(_Symbol, Period(), "AutoCorr_MTF_Pro", InpTFMid, InpAutoCorrPeriod, 0.1);

// Vol Regime MTF: Params(TF, Fast, Slow, Thresh)
   h_vola_reg_m15 = iCustom(_Symbol, Period(), "VolatilityRegime_MTF_Pro", InpTFMid, 5, 50, 1.0);

// Squeeze MTF: Params(TF, Len, BB, KC, Mom, Price)
   h_sqz_m15    = iCustom(_Symbol, Period(), "Squeeze_MTF_Pro", InpTFMid, InpSqueezeLength, InpBBMult, InpKCMult, InpSqueezeMom, PRICE_CLOSE);

   h_vhf_m15    = iCustom(_Symbol, Period(), "VHF_MTF_Pro", InpTFMid, InpVHFPeriod, VHF_MODE_HIGH_LOW, PRICE_CLOSE);
   h_r2_m15     = iCustom(_Symbol, Period(), "LinReg_R2_MTF_Pro", InpTFMid, InpR2Period, 0.7);
   h_tsi_m15 = iCustom(_Symbol, Period(), "TSI_MTF_Simple_Pro", InpTFMid, InpTSI_Slow, InpTSI_Fast, InpTSI_Signal, PRICE_CLOSE);

// RVOL MTF: Params(TF, Period, Thresh)
   h_rvol_m15   = iCustom(_Symbol, Period(), "RVOL_MTF_Pro", InpTFMid, InpRVOLPeriod, 2.0);

// --- M5 HANDLES ---
// Velocity MTF: Params(TF, VelP, ATRP, Thresh, ShowSpeed)
   h_vel_m5     = iCustom(_Symbol, Period(), "Velocity_MTF_Pro", InpTFFast, InpVelPeriod, InpATRPeriod, 1.0, false);

   h_rvol_m5    = iCustom(_Symbol, Period(), "RVOL_MTF_Pro", InpTFFast, InpRVOLPeriod, 2.0);
   h_tsi_m5  = iCustom(_Symbol, Period(), "TSI_MTF_Simple_Pro", InpTFFast, InpTSI_Slow, InpTSI_Fast, InpTSI_Signal, PRICE_CLOSE);

// Need generic ATR for Cost. Using iATR on M5.
   h_atr_m5     = iATR(_Symbol, InpTFFast, InpATRPeriod);

// --- COMPOSITE ---
// Absorption MTF (Run on M15) -> iCustom takes params: ATRPeriod, RVOLPeriod, History
// Input InpTFMid is M15.
   h_abs = iCustom(_Symbol, InpTFMid, "Absorption_Pro", InpATRPeriod, InpRVOLPeriod, 500, false);
   if(h_abs == INVALID_HANDLE)
      Print("Absorption Handle Error");

// Check Handles
   if(h_alpha_h1==INVALID_HANDLE || h_sqz_m15==INVALID_HANDLE || h_vel_m5==INVALID_HANDLE)
     {
      Print("Error creating iCustom handles. Check if indicators are compiled!");
      return INIT_FAILED;
     }

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "MIP_");
   IndicatorRelease(h_alpha_h1);
   IndicatorRelease(h_beta_h1);
   IndicatorRelease(h_vhf_h1);
   IndicatorRelease(h_r2_h1);
   IndicatorRelease(h_tsi_h1);

   IndicatorRelease(h_vscore_m15);
   IndicatorRelease(h_ac_m15);
   IndicatorRelease(h_vola_reg_m15);
   IndicatorRelease(h_sqz_m15);
   IndicatorRelease(h_vhf_m15);
   IndicatorRelease(h_r2_m15);
   IndicatorRelease(h_tsi_m15);
   IndicatorRelease(h_rvol_m15);

   IndicatorRelease(h_vel_m5);
   IndicatorRelease(h_rvol_m5);
   IndicatorRelease(h_tsi_m5);
   IndicatorRelease(h_atr_m5);

   IndicatorRelease(h_abs);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
  { return rates_total; }

void OnTimer() { if(TerminalInfoInteger(TERMINAL_CONNECTED)) DrawDashboard(); }

//+------------------------------------------------------------------+
//| Main Logic                                                       |
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   int y = InpYOffset;
   int row_h = 16;
   int col_w = 90;

// --- HEADER ---
// (Omit Global Sentiment logic for brevity or re-implement if needed, requires data fetch)
// Let's stick to Symbol first.
   string symbol_txt = _Symbol + " (" + StringSubstr(EnumToString(Period()), 7) + ")";
   CreateLabel("Head_Sym", symbol_txt, InpXOffset, y, clrGold, true);
   y+=row_h+10;

// --- L1: CONTEXT (H1) ---
   CreateLabel("T_L1", "CONTEXT (H1)", InpXOffset, y, InpColorHead);
   y+=row_h;

// Get Values (Index 0 = Current Live, Index 1 = Closed? MTF Indicators map HTF history to current bars)
// Usually Index 0 contains the current (live) mapping of the HTF bar.
   double alpha = GetVal(h_alpha_h1, 0); // Buffer 0
   double beta  = GetVal(h_beta_h1, 0);

   double vhf_h1 = GetVal(h_vhf_h1, 0);
   double r2_h1  = GetVal(h_r2_h1, 0);
   double tsi_h1_hist = GetVal(h_tsi_h1, 0); // Buffer 0 is Hist in MTF pro? Check source. Yes.

   DrawRow("Stats", "Alpha: "+DoubleToString(alpha,4), "Beta: "+DoubleToString(beta,3), y, col_w);
   y+=row_h;
   DrawRow("Qual", "VHF: "+DoubleToString(vhf_h1,3), "R2: "+DoubleToString(r2_h1,3), y, col_w);
   y+=row_h;
   DrawRow("Cycle", "TSI H: "+DoubleToString(tsi_h1_hist,3), "", y, col_w);
   y+=row_h+5;

// --- L2: FLOW (M15) ---
   CreateLabel("T_L2", "FLOW (M15)", InpXOffset, y, InpColorHead);
   y+=row_h;

   double vscore = GetVal(h_vscore_m15, 0);
   double ac = GetVal(h_ac_m15, 0);
   double vol_reg = GetVal(h_vola_reg_m15, 0);
// Squeeze: Buf 0=Mom, 1=Val(0), 2=Color.
// We need State (Color) and Mom.
   double sqz_mom = GetVal(h_sqz_m15, 0);
   double sqz_col = GetVal(h_sqz_m15, 2);
   string sqz_st = (sqz_col == 1.0) ? "ON" : "OFF";

   double vhf_m15 = GetVal(h_vhf_m15, 0);
   double r2_m15  = GetVal(h_r2_m15, 0);
   double tsi_m15_hist = GetVal(h_tsi_m15, 0);

   DrawRow("Val", "V-Sc: "+DoubleToString(vscore,3), "AC: "+DoubleToString(ac,3), y, col_w);
   y+=row_h;
   DrawRow("Vola", "Reg: "+DoubleToString(vol_reg,3), "SQZ: "+sqz_st, y, col_w);
   y+=row_h;
   DrawRow("Mom", "SqzM: "+DoubleToString(sqz_mom,3), "TSI H: "+DoubleToString(tsi_m15_hist,3), y, col_w);
   y+=row_h;
   DrawRow("Qual", "VHF: "+DoubleToString(vhf_m15,3), "R2: "+DoubleToString(r2_m15,3), y, col_w);
   y+=row_h+5;

// --- L3: TRIGGER (M5) ---
   CreateLabel("T_L3", "TRIGGER (M5)", InpXOffset, y, InpColorHead);
   y+=row_h;

   double vel = GetVal(h_vel_m5, 0);
   double rvol_m5 = GetVal(h_rvol_m5, 0);
   double rvol_m15 = GetVal(h_rvol_m15, 0);
   double thrust = (rvol_m15>0) ? rvol_m5/rvol_m15 : 0;

   double atr_m5 = GetVal(h_atr_m5, 0);
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double cost = (atr_m5>0) ? ((double)spread * pt / atr_m5)*100.0 : 0;

   double tsi_m5_hist = GetVal(h_tsi_m5, 0);

   DrawRow("Action", "Vel: "+DoubleToString(vel,3), "Thrust: "+DoubleToString(thrust,3), y, col_w);
   y+=row_h;
   DrawRow("Data", "Cost: "+DoubleToString(cost,1)+"%", "TSI H: "+DoubleToString(tsi_m5_hist,3), y, col_w);
   y+=row_h+5;

// --- L4: COMPOSITE (Updated) ---
   CreateLabel("T_L4", "--- COMPOSITES ---", InpXOffset, y, InpColorHead);
   y+=row_h;

// 1. Absorption from Indicator
   double abs_buf[1];
   string absorp = "NO";

// Read Buffer 4 (State) from Last Closed Bar (Index 1) on M15 logic
// Why Index 1? Absorption pattern is confirmed when bar closes.
   if(CopyBuffer(h_abs, 4, 1, 1, abs_buf) > 0)
     {
      double st = abs_buf[0];
      if(st == 1.0)
        {
         absorp = "BULL ABS";
        }
      else
         if(st == -1.0)
           {
            absorp = "BEAR ABS";
           }
         else
            if(st == 2.0)
              {
               absorp = "CLIMAX";
              }
            else
               if(st == 0.5)
                 {
                  absorp = "NEUT ABS";
                 }
     }

// 2. MTF Align
   bool h1_bull = (tsi_h1_hist > 0);
   bool m15_bull = (tsi_m15_hist > 0);
   bool m5_bull = (tsi_m5_hist > 0);

   string mtf = "MIXED";
   if(h1_bull == m15_bull && m15_bull == m5_bull)
      mtf = "FULL " + (h1_bull ? "BULL" : "BEAR");
   else
      if(h1_bull == m15_bull)
         mtf = "MAJOR " + (h1_bull ? "BULL" : "BEAR");

//DrawRow("Signal", "Absorp: "+absorp, c_abs, "", clrNone, y, col_w);
   DrawRow("Signal", "Absorp: "+absorp, "MTF: "+mtf, y, col_w);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double GetVal(int handle, int buf_idx)
  {
   double b[1];
   if(CopyBuffer(handle, buf_idx, 0, 1, b) <= 0)
      return 0.0;
   return b[0]; // Current bar value
  }
// Include basic draw helpers same as before
void CreateLabel(string name, string text, int x, int y, color clr, bool bold=false)
  {
   string obj="MIP_"+name;
   if(ObjectFind(0,obj)<0)
     {
      ObjectCreate(0,obj,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,obj,OBJPROP_CORNER,InpCorner);
      ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,InpFontSize);
     }
   ObjectSetString(0,obj,OBJPROP_TEXT,text);
   ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,obj,OBJPROP_COLOR,clr);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawRow(string t, string v1, string v2, int y, int col_w)
  {
   CreateLabel(t+"_T", t, InpXOffset, y, InpColorLbl);
   CreateLabel(t+"_1", v1, InpXOffset+col_w, y, InpColorTxt);
   CreateLabel(t+"_2", v2, InpXOffset+(col_w*2)-10, y, InpColorTxt);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
