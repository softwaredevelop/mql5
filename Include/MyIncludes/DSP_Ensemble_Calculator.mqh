//+------------------------------------------------------------------+
//|                                    DSP_Ensemble_Calculator.mqh   |
//|      Cybernetic Zero-Lag Ensemble Voting DSP Engine (8 Voters)   |
//|      Unites: MAMA, Ehlers Smoother, Laguerre RSI, Cyber Cycle,   |
//|              Roofing Filter, Ehlers Bands, TTM Squeeze, V_PRES   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"

#ifndef DSP_ENSEMBLE_CALCULATOR_MQH
#define DSP_ENSEMBLE_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\MAMA_Calculator.mqh>
#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>
#include <MyIncludes\Laguerre_RSI_Calculator.mqh>
#include <MyIncludes\Cyber_Cycle_Calculator.mqh>
#include <MyIncludes\Roofing_Filter_Calculator.mqh>
#include <MyIncludes\Ehlers_Bands_Calculator.mqh>
#include <MyIncludes\Squeeze_Calculator.mqh>
#include <MyIncludes\VolumePressure_Calculator.mqh>

//--- Component Snapshot Structure for Future Dashboard HUDs
struct SDSPComponentVote
  {
   string            name;
   string            family;
   int               vote;           // +1 Bullish, -1 Bearish, 0 Neutral
   double            weight;
   bool              enabled;
   bool              is_valid;
  };

//+==================================================================+
//| CLASS: CDSPEnsembleCalculator                                    |
//+==================================================================+
class CDSPEnsembleCalculator
  {
private:
   //--- Embedded 8 Headless DSP Engines + Smoothing & Signal Engines
   CMAMACalculator           *m_mama_calc;
   CEhlersSmootherCalculator  m_smoother_calc;
   CLaguerreRSICalculator    *m_lrsi_calc;
   CCyberCycleCalculator     *m_cyber_calc;
   CRoofingFilterCalculator  *m_roofing_calc;
   CEhlersBandsCalculator     m_bands_calc;
   CSqueezeCalculator         m_squeeze_calc;
   CVolumePressureCalculator  m_vp_calc;

   CMovingAverageCalculator   m_smoothing_engine;
   CMovingAverageCalculator   m_signal_engine;

   //--- Global Settings
   double                    m_neutral_zone;
   double                    m_vp_neutral_zone;
   int                       m_smoothing_period;
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Component Periods (For Validity Guards)
   int                       m_smoother_period;
   int                       m_roof_hp_period;
   int                       m_roof_ss_period;
   int                       m_bands_smooth_period;
   int                       m_bands_period;
   int                       m_sqz_period;
   int                       m_sqz_atr_period;
   int                       m_sqz_mom_period;
   int                       m_vp_smooth_period;
   ENUM_MA_TYPE              m_vp_ma_type;

   //--- Component Toggles & Weights
   bool              m_en_mama;
   double            m_w_mama;
   bool              m_en_smoother;
   double            m_w_smoother;
   bool              m_en_lrsi;
   double            m_w_lrsi;
   bool              m_en_cyber;
   double            m_w_cyber;
   bool              m_en_roofing;
   double            m_w_roofing;
   bool              m_en_bands;
   double            m_w_bands;
   bool              m_en_squeeze;
   double            m_w_squeeze;
   bool              m_en_vp;
   double            m_w_vp;

   //--- Persistent Working Buffers
   double            m_buf_mama[], m_buf_fama[];
   double            m_buf_smoother[];
   double            m_buf_lrsi[], m_buf_lrsi_sig[];
   double            m_buf_cyber[], m_buf_cyber_sig[];
   double            m_buf_roofing[];
   double            m_buf_bands_up[], m_buf_bands_lo[], m_buf_bands_mid[], m_buf_price[];
   double            m_buf_sqz_mom[], m_buf_sqz_mom_col[], m_buf_sqz_dot[], m_buf_sqz_dot_col[];
   double            m_buf_vp[];

   double            m_raw_score[];
   double            m_consensus_internal[];

   //--- Voting Helpers
   int               DirectionVote(const double a, const double b) const
     {
      if(a == EMPTY_VALUE || b == EMPTY_VALUE)
         return 0;
      return (a > b) ? 1 : (a < b ? -1 : 0);
     }

   int               ZeroPolarityVote(const double val, const double dead_zone = 0.0) const
     {
      if(val == EMPTY_VALUE)
         return 0;
      if(val > dead_zone)
         return 1;
      if(val < -dead_zone)
         return -1;
      return 0;
     }

   int               MidlineVote(const double val, const double buffer) const
     {
      if(val == EMPTY_VALUE)
         return 0;
      if(val > 50.0 + buffer)
         return 1;
      if(val < 50.0 - buffer)
         return -1;
      return 0;
     }

   void              CleanupPointers(void);

public:
                     CDSPEnsembleCalculator(void);
                    ~CDSPEnsembleCalculator(void);

   bool              Init(const double neutral_zone, const int smoothing_p,
                          const int signal_p, const ENUM_MA_TYPE signal_ma,
                          const ENUM_APPLIED_PRICE_HA_ALL price_source,
                          // 1. MAMA
                          const bool en_mama, const double w_mama, const double mama_fast, const double mama_slow,
                          // 2. Ehlers Smoother
                          const bool en_smoother, const double w_smoother, const ENUM_SMOOTHER_TYPE smoother_type, const int smoother_p,
                          // 3. Laguerre RSI
                          const bool en_lrsi, const double w_lrsi, const double lrsi_gamma,
                          // 4. Cyber Cycle
                          const bool en_cyber, const double w_cyber, const double cyber_alpha,
                          // 5. Roofing Filter
                          const bool en_roofing, const double w_roofing, const int roof_hp_p, const int roof_ss_p,
                          // 6. Ehlers Bands
                          const bool en_bands, const double w_bands, const int bands_smooth_p, const int bands_p, const double bands_mult, const ENUM_EHLERS_BANDS_MODE bands_mode,
                          // 7. Squeeze
                          const bool en_squeeze, const double w_squeeze, const int sqz_p, const double sqz_bb_mult, const int sqz_atr_p, const double sqz_kc_mult, const int sqz_mom_p,
                          // 8. Volume Pressure
                          const bool en_vp, const double w_vp, const int vp_smooth_p, const ENUM_MA_TYPE vp_ma_type, const double vp_neutral_zone);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[]);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const double &volume[],
                               double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[]);

   void              GetLatestSnapshot(SDSPComponentVote &out_components[], int &out_bull_votes, int &out_bear_votes, int &out_neutral_votes) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDSPEnsembleCalculator::CDSPEnsembleCalculator(void) : m_mama_calc(NULL),
   m_lrsi_calc(NULL),
   m_cyber_calc(NULL),
   m_roofing_calc(NULL),
   m_neutral_zone(5.0),
   m_vp_neutral_zone(0.10),
   m_smoothing_period(3),
   m_signal_period(9),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_buf_mama,           false);
   ArraySetAsSeries(m_buf_fama,           false);
   ArraySetAsSeries(m_buf_smoother,       false);
   ArraySetAsSeries(m_buf_lrsi,           false);
   ArraySetAsSeries(m_buf_lrsi_sig,       false);
   ArraySetAsSeries(m_buf_cyber,          false);
   ArraySetAsSeries(m_buf_cyber_sig,      false);
   ArraySetAsSeries(m_buf_roofing,        false);
   ArraySetAsSeries(m_buf_bands_up,       false);
   ArraySetAsSeries(m_buf_bands_lo,       false);
   ArraySetAsSeries(m_buf_bands_mid,      false);
   ArraySetAsSeries(m_buf_price,          false);
   ArraySetAsSeries(m_buf_sqz_mom,        false);
   ArraySetAsSeries(m_buf_sqz_mom_col,    false);
   ArraySetAsSeries(m_buf_sqz_dot,        false);
   ArraySetAsSeries(m_buf_sqz_dot_col,    false);
   ArraySetAsSeries(m_buf_vp,             false);
   ArraySetAsSeries(m_raw_score,          false);
   ArraySetAsSeries(m_consensus_internal, false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDSPEnsembleCalculator::~CDSPEnsembleCalculator(void)
  {
   CleanupPointers();
  }

//+------------------------------------------------------------------+
//| Safe Pointer Cleanup                                             |
//+------------------------------------------------------------------+
void CDSPEnsembleCalculator::CleanupPointers(void)
  {
   if(CheckPointer(m_mama_calc) != POINTER_INVALID && m_mama_calc != NULL)
     {
      delete m_mama_calc;
      m_mama_calc    = NULL;
     }
   if(CheckPointer(m_lrsi_calc) != POINTER_INVALID && m_lrsi_calc != NULL)
     {
      delete m_lrsi_calc;
      m_lrsi_calc    = NULL;
     }
   if(CheckPointer(m_cyber_calc) != POINTER_INVALID && m_cyber_calc != NULL)
     {
      delete m_cyber_calc;
      m_cyber_calc   = NULL;
     }
   if(CheckPointer(m_roofing_calc) != POINTER_INVALID && m_roofing_calc != NULL)
     {
      delete m_roofing_calc;
      m_roofing_calc = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Master Initialization of All 8 DSP Component Engines             |
//+------------------------------------------------------------------+
bool CDSPEnsembleCalculator::Init(const double neutral_zone, const int smoothing_p,
                                  const int signal_p, const ENUM_MA_TYPE signal_ma,
                                  const ENUM_APPLIED_PRICE_HA_ALL price_source,
                                  const bool en_mama, const double w_mama, const double mama_fast, const double mama_slow,
                                  const bool en_smoother, const double w_smoother, const ENUM_SMOOTHER_TYPE smoother_type, const int smoother_p,
                                  const bool en_lrsi, const double w_lrsi, const double lrsi_gamma,
                                  const bool en_cyber, const double w_cyber, const double cyber_alpha,
                                  const bool en_roofing, const double w_roofing, const int roof_hp_p, const int roof_ss_p,
                                  const bool en_bands, const double w_bands, const int bands_smooth_p, const int bands_p, const double bands_mult, const ENUM_EHLERS_BANDS_MODE bands_mode,
                                  const bool en_squeeze, const double w_squeeze, const int sqz_p, const double sqz_bb_mult, const int sqz_atr_p, const double sqz_kc_mult, const int sqz_mom_p,
                                  const bool en_vp, const double w_vp, const int vp_smooth_p, const ENUM_MA_TYPE vp_ma_type, const double vp_neutral_zone)
  {
   CleanupPointers();

   m_neutral_zone     = neutral_zone;
   m_vp_neutral_zone  = vp_neutral_zone;
   m_smoothing_period = MathMax(1, smoothing_p);
   m_signal_period    = MathMax(1, signal_p);
   m_signal_ma_type   = signal_ma;
   m_source_price     = price_source;

   m_smoother_period     = MathMax(2, smoother_p);
   m_roof_hp_period      = MathMax(10, roof_hp_p);
   m_roof_ss_period      = MathMax(2, roof_ss_p);
   m_bands_smooth_period = MathMax(2, bands_smooth_p);
   m_bands_period        = MathMax(2, bands_p);
   m_sqz_period          = MathMax(5, sqz_p);
   m_sqz_atr_period      = MathMax(1, sqz_atr_p);
   m_sqz_mom_period      = MathMax(2, sqz_mom_p);
   m_vp_smooth_period    = MathMax(1, vp_smooth_p);
   m_vp_ma_type          = vp_ma_type;

   m_en_mama     = en_mama;
   m_w_mama     = w_mama;
   m_en_smoother = en_smoother;
   m_w_smoother = w_smoother;
   m_en_lrsi     = en_lrsi;
   m_w_lrsi     = w_lrsi;
   m_en_cyber    = en_cyber;
   m_w_cyber    = w_cyber;
   m_en_roofing  = en_roofing;
   m_w_roofing  = w_roofing;
   m_en_bands    = en_bands;
   m_w_bands    = w_bands;
   m_en_squeeze  = en_squeeze;
   m_w_squeeze  = w_squeeze;
   m_en_vp       = en_vp;
   m_w_vp       = w_vp;

   bool is_ha = (m_source_price <= PRICE_HA_CLOSE);

// 1. MAMA
   m_mama_calc = is_ha ? (CMAMACalculator*)(new CMAMACalculator_HA()) : (CMAMACalculator*)(new CMAMACalculator());
   if(CheckPointer(m_mama_calc) == POINTER_INVALID || !m_mama_calc.Init(mama_fast, mama_slow))
      return false;

// 2. Ehlers Smoother
   if(!m_smoother_calc.Init(m_smoother_period, smoother_type, SOURCE_PRICE, m_source_price))
      return false;

// 3. Laguerre RSI
   m_lrsi_calc = is_ha ? (CLaguerreRSICalculator*)(new CLaguerreRSICalculator_HA()) : (CLaguerreRSICalculator*)(new CLaguerreRSICalculator());
   if(CheckPointer(m_lrsi_calc) == POINTER_INVALID || !m_lrsi_calc.Init(lrsi_gamma, 3, EMA, m_source_price))
      return false;

// 4. Cyber Cycle (Uses classic 1-bar delay quadrature trigger)
   m_cyber_calc = is_ha ? (CCyberCycleCalculator*)(new CCyberCycleCalculator_HA()) : (CCyberCycleCalculator*)(new CCyberCycleCalculator());
   if(CheckPointer(m_cyber_calc) == POINTER_INVALID || !m_cyber_calc.Init(cyber_alpha, SIGNAL_DELAY_1BAR, 3, SMA))
      return false;

// 5. Roofing Filter
   m_roofing_calc = is_ha ? (CRoofingFilterCalculator*)(new CRoofingFilterCalculator_HA()) : (CRoofingFilterCalculator*)(new CRoofingFilterCalculator());
   if(CheckPointer(m_roofing_calc) == POINTER_INVALID || !m_roofing_calc.Init(m_roof_hp_period, m_roof_ss_period))
      return false;

// 6. Ehlers Bands
   if(!m_bands_calc.Init(m_bands_smooth_period, m_bands_period, bands_mult, smoother_type, bands_mode, m_source_price))
      return false;

// 7. Squeeze
   if(!m_squeeze_calc.Init(m_sqz_period, sqz_bb_mult, m_sqz_atr_period, sqz_kc_mult, ATR_SOURCE_STANDARD, m_sqz_mom_period, m_source_price))
      return false;

// 8. Volume Pressure
   if(!m_vp_calc.Init(m_vp_smooth_period, m_vp_ma_type, is_ha))
      return false;

// 9. Consensus & Signal Line Engines
   if(!m_smoothing_engine.Init(m_smoothing_period, EMA))
      return false;
   if(!m_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate with Long Volume Overload                              |
//+------------------------------------------------------------------+
void CDSPEnsembleCalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const long &volume[],
                                       double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[])
  {
   double d_vol[];
   ArrayResize(d_vol, rates_total, 2048);
   ArraySetAsSeries(d_vol, false);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
      d_vol[i] = (volume[i] < 1) ? 1.0 : (double)volume[i];

   Calculate(rates_total, prev_calculated, open, high, low, close, d_vol, consensus_out, signal_out, raw_score_out, agreement_out);
  }

//+------------------------------------------------------------------+
//| Primary Multi-Engine Execution & Consensus Tally                 |
//+------------------------------------------------------------------+
void CDSPEnsembleCalculator::Calculate(const int rates_total, const int prev_calculated,
                                       const double &open[], const double &high[], const double &low[], const double &close[],
                                       const double &volume[],
                                       double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[])
  {
   if(rates_total < 60)
      return;

// Pre-resize ALL working buffers safely with capacity reservation
   if(ArraySize(m_raw_score) != rates_total)
     {
      ArrayResize(m_buf_mama,           rates_total, 2048);
      ArrayResize(m_buf_fama,           rates_total, 2048);
      ArrayResize(m_buf_smoother,       rates_total, 2048);
      ArrayResize(m_buf_lrsi,           rates_total, 2048);
      ArrayResize(m_buf_lrsi_sig,       rates_total, 2048);
      ArrayResize(m_buf_cyber,          rates_total, 2048);
      ArrayResize(m_buf_cyber_sig,      rates_total, 2048);
      ArrayResize(m_buf_roofing,        rates_total, 2048);
      ArrayResize(m_buf_bands_up,       rates_total, 2048);
      ArrayResize(m_buf_bands_lo,       rates_total, 2048);
      ArrayResize(m_buf_bands_mid,      rates_total, 2048);
      ArrayResize(m_buf_price,          rates_total, 2048);
      ArrayResize(m_buf_sqz_mom,        rates_total, 2048);
      ArrayResize(m_buf_sqz_mom_col,    rates_total, 2048);
      ArrayResize(m_buf_sqz_dot,        rates_total, 2048);
      ArrayResize(m_buf_sqz_dot_col,    rates_total, 2048);
      ArrayResize(m_buf_vp,             rates_total, 2048);
      ArrayResize(m_raw_score,          rates_total, 2048);
      ArrayResize(m_consensus_internal, rates_total, 2048);
     }

   ENUM_APPLIED_PRICE price_type = (m_source_price <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)m_source_price) - 1) :
                                   (ENUM_APPLIED_PRICE)m_source_price;

// 1. Execute All 8 Headless DSP Engines
   m_mama_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_mama, m_buf_fama);
   m_smoother_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_smoother);
   m_lrsi_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_lrsi, m_buf_lrsi_sig);
   m_cyber_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_cyber, m_buf_cyber_sig);
   m_roofing_calc.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_roofing);
   m_bands_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_bands_up, m_buf_bands_lo, m_buf_bands_mid);
   m_bands_calc.GetPriceBuffer(m_buf_price);
   m_squeeze_calc.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_sqz_mom, m_buf_sqz_mom_col, m_buf_sqz_dot, m_buf_sqz_dot_col);
   m_vp_calc.Calculate(rates_total, prev_calculated, open, high, low, close, volume, m_buf_vp);

   int loop_start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 2. Voting Tally Loop
   for(int i = loop_start; i < rates_total; i++)
     {
      double c_price = m_buf_price[i]; // Synchronized Standard or HA price!

      // A) Trend & Smoother Votes
      int v_mama     = DirectionVote(m_buf_mama[i], m_buf_fama[i]);
      int v_smoother = DirectionVote(c_price, m_buf_smoother[i]);

      // B) Momentum & Cycle Votes
      int v_lrsi     = MidlineVote(m_buf_lrsi[i], m_neutral_zone);
      int v_cyber    = DirectionVote(m_buf_cyber[i], m_buf_cyber_sig[i]);
      int v_roofing  = ZeroPolarityVote(m_buf_roofing[i], 0.0);

      // C) Volatility & Squeeze Votes
      double b_width = m_buf_bands_up[i] - m_buf_bands_lo[i];
      double b_pct   = (b_width > 0.0) ? (100.0 * (c_price - m_buf_bands_lo[i]) / b_width) : 50.0;
      int v_bands    = MidlineVote(b_pct, m_neutral_zone);
      int v_squeeze  = ZeroPolarityVote(m_buf_sqz_mom[i], 0.0);

      // D) Volume Pressure Vote
      int v_vp       = ZeroPolarityVote(m_buf_vp[i], m_vp_neutral_zone);

      // E) Validity Guards
      bool val_mama     = (i >= 50 && m_buf_mama[i] != EMPTY_VALUE && m_buf_fama[i] != EMPTY_VALUE);
      bool val_smoother = (i >= m_smoother_period && m_buf_smoother[i] != EMPTY_VALUE);
      bool val_lrsi     = (i >= 4 && m_buf_lrsi[i] != EMPTY_VALUE);
      bool val_cyber    = (i >= 8 && m_buf_cyber[i] != EMPTY_VALUE && m_buf_cyber_sig[i] != EMPTY_VALUE);
      bool val_roofing  = (i >= MathMax(m_roof_hp_period, m_roof_ss_period) && m_buf_roofing[i] != EMPTY_VALUE);
      bool val_bands    = (i >= MathMax(m_bands_smooth_period, m_bands_period) && m_buf_bands_up[i] != EMPTY_VALUE && m_buf_bands_lo[i] != EMPTY_VALUE);
      bool val_squeeze  = (i >= MathMax(m_sqz_period, m_sqz_atr_period) + m_sqz_mom_period && m_buf_sqz_mom[i] != EMPTY_VALUE);
      bool val_vp       = (i >= m_vp_smooth_period && m_buf_vp[i] != EMPTY_VALUE);

      // F) Weighted Aggregation
      double active_weight = 0.0;
      double bull_weight   = 0.0;
      double bear_weight   = 0.0;

#define DSP_TALLY(en, valid, w, v) \
         if(en && valid) { \
            active_weight += w; \
            if(v > 0) bull_weight += w; \
            else if(v < 0) bear_weight += w; \
         }

      DSP_TALLY(m_en_mama,     val_mama,     m_w_mama,     v_mama);
      DSP_TALLY(m_en_smoother, val_smoother, m_w_smoother, v_smoother);
      DSP_TALLY(m_en_lrsi,     val_lrsi,     m_w_lrsi,     v_lrsi);
      DSP_TALLY(m_en_cyber,    val_cyber,    m_w_cyber,    v_cyber);
      DSP_TALLY(m_en_roofing,  val_roofing,  m_w_roofing,  v_roofing);
      DSP_TALLY(m_en_bands,    val_bands,    m_w_bands,    v_bands);
      DSP_TALLY(m_en_squeeze,  val_squeeze,  m_w_squeeze,  v_squeeze);
      DSP_TALLY(m_en_vp,       val_vp,       m_w_vp,       v_vp);
#undef DSP_TALLY

      m_raw_score[i]   = (active_weight > 0.0) ? (100.0 * (bull_weight - bear_weight) / active_weight) : 0.0;
      raw_score_out[i] = m_raw_score[i];
      agreement_out[i] = (active_weight > 0.0) ? (100.0 * MathMax(bull_weight, bear_weight) / active_weight) : 0.0;
     }

// 3. Smooth the Raw Consensus Score with EMA
   m_smoothing_engine.CalculateOnArray(rates_total, prev_calculated, m_raw_score, m_consensus_internal, 0);

   for(int i = loop_start; i < rates_total; i++)
      consensus_out[i] = m_consensus_internal[i];

// 4. Calculate Secondary Signal Line over Consensus Series
   m_signal_engine.CalculateOnArray(rates_total, prev_calculated, m_consensus_internal, signal_out, 0);
  }

//+------------------------------------------------------------------+
//| Extract Latest Bar Component Snapshot for Future Dashboards      |
//+------------------------------------------------------------------+
void CDSPEnsembleCalculator::GetLatestSnapshot(SDSPComponentVote &out_components[], int &out_bull_votes, int &out_bear_votes, int &out_neutral_votes) const
  {
   ArrayResize(out_components, 8);
   out_bull_votes    = 0;
   out_bear_votes    = 0;
   out_neutral_votes = 0;

   int last = ArraySize(m_raw_score) - 1;
   if(last < 0)
      return;

#define SET_DSP_COMP(idx, n, f, en, w, v, valid) \
      out_components[idx].name     = n; \
      out_components[idx].family   = f; \
      out_components[idx].enabled  = en; \
      out_components[idx].weight   = w; \
      out_components[idx].is_valid = valid; \
      out_components[idx].vote     = valid ? v : 0; \
      if(en && valid) { \
         if(v > 0) out_bull_votes++; \
         else if(v < 0) out_bear_votes++; \
         else out_neutral_votes++; \
      }

   double c_price = m_buf_price[last];

   bool v_mama = (last >= 50 && m_buf_mama[last] != EMPTY_VALUE && m_buf_fama[last] != EMPTY_VALUE);
   SET_DSP_COMP(0, "MAMA/FAMA", "Trend", m_en_mama, m_w_mama, DirectionVote(m_buf_mama[last], m_buf_fama[last]), v_mama);

   bool v_smoother = (last >= m_smoother_period && m_buf_smoother[last] != EMPTY_VALUE);
   SET_DSP_COMP(1, "Ehlers Smoother", "Trend", m_en_smoother, m_w_smoother, DirectionVote(c_price, m_buf_smoother[last]), v_smoother);

   bool v_lrsi = (last >= 4 && m_buf_lrsi[last] != EMPTY_VALUE);
   SET_DSP_COMP(2, "Laguerre RSI", "Momentum", m_en_lrsi, m_w_lrsi, MidlineVote(m_buf_lrsi[last], m_neutral_zone), v_lrsi);

   bool v_cyber = (last >= 8 && m_buf_cyber[last] != EMPTY_VALUE && m_buf_cyber_sig[last] != EMPTY_VALUE);
   SET_DSP_COMP(3, "Cyber Cycle", "Cycle", m_en_cyber, m_w_cyber, DirectionVote(m_buf_cyber[last], m_buf_cyber_sig[last]), v_cyber);

   bool v_roof = (last >= MathMax(m_roof_hp_period, m_roof_ss_period) && m_buf_roofing[last] != EMPTY_VALUE);
   SET_DSP_COMP(4, "Roofing Filter", "Cycle", m_en_roofing, m_w_roofing, ZeroPolarityVote(m_buf_roofing[last], 0.0), v_roof);

   double bw = m_buf_bands_up[last] - m_buf_bands_lo[last];
   double bp = (bw > 0.0) ? (100.0 * (c_price - m_buf_bands_lo[last]) / bw) : 50.0;
   bool v_bands = (last >= MathMax(m_bands_smooth_period, m_bands_period) && m_buf_bands_up[last] != EMPTY_VALUE);
   SET_DSP_COMP(5, "Ehlers Bands %B", "Volatility", m_en_bands, m_w_bands, MidlineVote(bp, m_neutral_zone), v_bands);

   bool v_sqz = (last >= MathMax(m_sqz_period, m_sqz_atr_period) + m_sqz_mom_period && m_buf_sqz_mom[last] != EMPTY_VALUE);
   SET_DSP_COMP(6, "TTM Squeeze", "Squeeze", m_en_squeeze, m_w_squeeze, ZeroPolarityVote(m_buf_sqz_mom[last], 0.0), v_sqz);

   bool v_vp = (last >= m_vp_smooth_period && m_buf_vp[last] != EMPTY_VALUE);
   SET_DSP_COMP(7, "Volume Pressure", "Volume", m_en_vp, m_w_vp, ZeroPolarityVote(m_buf_vp[last], m_vp_neutral_zone), v_vp);

#undef SET_DSP_COMP
  }

#endif // DSP_ENSEMBLE_CALCULATOR_MQH
//+------------------------------------------------------------------+
