//+------------------------------------------------------------------+
//|                                 Ensemble_Voting_Calculator.mqh   |
//|      Multi-Indicator Consensus & Ensemble Voting DSP Engine      |
//|      VERSION 2.00: Fast Stochastic, Universal Price Routing      |
//|                    & Secondary Signal Line Engine                |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.00"

#ifndef ENSEMBLE_VOTING_CALCULATOR_MQH
#define ENSEMBLE_VOTING_CALCULATOR_MQH

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\RSI_Engine.mqh>
#include <MyIncludes\MACD_Calculator.mqh>
#include <MyIncludes\StochasticFast_Calculator.mqh>
#include <MyIncludes\Bollinger_Bands_Calculator.mqh>
#include <MyIncludes\Donchian_Calculator.mqh>
#include <MyIncludes\OBV_Calculator.mqh>
#include <MyIncludes\MFI_Calculator.mqh>

//--- Individual Component Snapshot for Future Dashboard HUD
struct SComponentVote
  {
   string            name;
   string            family;
   int               vote;           // +1 Bullish, -1 Bearish, 0 Neutral
   double            weight;
   bool              enabled;
   bool              is_valid;
  };

//+==================================================================+
//| CLASS: CEnsembleVotingCalculator                                 |
//+==================================================================+
class CEnsembleVotingCalculator
  {
private:
   //--- Embedded Headless DSP Engines
   CMovingAverageCalculator    m_ema_fast;
   CMovingAverageCalculator    m_ema_slow;
   CMovingAverageCalculator    m_sma_trend;
   CRSIEngine                 *m_rsi_engine;
   CMACDCalculator            *m_macd_engine;
   CStochasticFastCalculator  *m_stoch_engine;
   CBollingerBandsCalculator  *m_bb_engine;
   CDonchianCalculator         m_donchian_engine;
   COBVCalculator              m_obv_engine;
   CMFICalculator              m_mfi_engine;
   CMovingAverageCalculator    m_smoothing_engine;
   CMovingAverageCalculator    m_signal_engine;

   //--- Configuration Settings
   double                    m_neutral_zone;
   int                       m_smoothing_period;
   int                       m_signal_period;
   ENUM_MA_TYPE              m_signal_ma_type;
   ENUM_APPLIED_PRICE_HA_ALL m_source_price;

   //--- Component Weights & Toggles
   bool              m_en_ema_cross;
   double            m_w_ema_cross;
   bool              m_en_price_sma;
   double            m_w_price_sma;
   bool              m_en_rsi;
   double            m_w_rsi;
   bool              m_en_macd;
   double            m_w_macd;
   bool              m_en_stoch;
   double            m_w_stoch;
   bool              m_en_bb;
   double            m_w_bb;
   bool              m_en_donchian;
   double            m_w_donchian;
   bool              m_en_obv;
   double            m_w_obv;
   bool              m_en_mfi;
   double            m_w_mfi;

   //--- Internal Working Buffers
   double            m_buf_ema_fast[];
   double            m_buf_ema_slow[];
   double            m_buf_sma_trend[];
   double            m_buf_rsi[];
   double            m_buf_macd[];
   double            m_buf_signal[];
   double            m_buf_hist[];
   double            m_buf_stoch_k[];
   double            m_buf_stoch_d[];
   double            m_buf_bb_ma[];
   double            m_buf_bb_up[];
   double            m_buf_bb_low[];
   double            m_buf_bb_price[];
   double            m_buf_don_up[];
   double            m_buf_don_mid[];
   double            m_buf_don_low[];
   double            m_buf_obv[];
   double            m_buf_obv_sig[];
   double            m_buf_mfi[];
   double            m_buf_mfi_sig[];

   double            m_raw_score[];
   double            m_consensus_internal[];

   //--- Voting Primitive Functions
   int               DirectionVote(const double a, const double b) const
     {
      if(a == EMPTY_VALUE || b == EMPTY_VALUE)
         return 0;
      return (a > b) ? 1 : (a < b ? -1 : 0);
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

public:
                     CEnsembleVotingCalculator(void);
                    ~CEnsembleVotingCalculator(void);

   bool              Init(const double neutral_zone, const int smoothing_p,
                          const int signal_p, const ENUM_MA_TYPE signal_ma,
                          const ENUM_APPLIED_PRICE_HA_ALL price_source,
                          const bool en_ema_cross, const double w_ema_cross, const int ema_fast_p, const int ema_slow_p,
                          const bool en_price_sma, const double w_price_sma, const int sma_trend_p,
                          const bool en_rsi, const double w_rsi, const int rsi_p,
                          const bool en_macd, const double w_macd, const int macd_fast_p, const int macd_slow_p, const int macd_sig_p,
                          const bool en_stoch, const double w_stoch, const int stoch_k_p, const int stoch_d_p,
                          const bool en_bb, const double w_bb, const int bb_p, const double bb_mult,
                          const bool en_donchian, const double w_donchian, const int don_p,
                          const bool en_obv, const double w_obv, const int obv_ema_p,
                          const bool en_mfi, const double w_mfi, const int mfi_p);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const long &volume[],
                               double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[]);

   void              Calculate(const int rates_total, const int prev_calculated,
                               const double &open[], const double &high[], const double &low[], const double &close[],
                               const double &volume[],
                               double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[]);

   void              GetLatestSnapshot(SComponentVote &out_components[], int &out_bull_votes, int &out_bear_votes, int &out_neutral_votes) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEnsembleVotingCalculator::CEnsembleVotingCalculator(void) : m_rsi_engine(NULL),
   m_macd_engine(NULL),
   m_stoch_engine(NULL),
   m_bb_engine(NULL),
   m_neutral_zone(5.0),
   m_smoothing_period(3),
   m_signal_period(9),
   m_signal_ma_type(EMA),
   m_source_price(PRICE_CLOSE_STD)
  {
   ArraySetAsSeries(m_buf_ema_fast,      false);
   ArraySetAsSeries(m_buf_ema_slow,      false);
   ArraySetAsSeries(m_buf_sma_trend,     false);
   ArraySetAsSeries(m_buf_rsi,           false);
   ArraySetAsSeries(m_buf_macd,          false);
   ArraySetAsSeries(m_buf_signal,        false);
   ArraySetAsSeries(m_buf_hist,          false);
   ArraySetAsSeries(m_buf_stoch_k,       false);
   ArraySetAsSeries(m_buf_stoch_d,       false);
   ArraySetAsSeries(m_buf_bb_ma,         false);
   ArraySetAsSeries(m_buf_bb_up,         false);
   ArraySetAsSeries(m_buf_bb_low,        false);
   ArraySetAsSeries(m_buf_bb_price,      false);
   ArraySetAsSeries(m_buf_don_up,        false);
   ArraySetAsSeries(m_buf_don_mid,       false);
   ArraySetAsSeries(m_buf_don_low,       false);
   ArraySetAsSeries(m_buf_obv,           false);
   ArraySetAsSeries(m_buf_obv_sig,       false);
   ArraySetAsSeries(m_buf_mfi,           false);
   ArraySetAsSeries(m_buf_mfi_sig,       false);
   ArraySetAsSeries(m_raw_score,         false);
   ArraySetAsSeries(m_consensus_internal,false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEnsembleVotingCalculator::~CEnsembleVotingCalculator(void)
  {
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID && m_rsi_engine != NULL)
     {
      delete m_rsi_engine;
      m_rsi_engine = NULL;
     }
   if(CheckPointer(m_macd_engine) != POINTER_INVALID && m_macd_engine != NULL)
     {
      delete m_macd_engine;
      m_macd_engine = NULL;
     }
   if(CheckPointer(m_stoch_engine) != POINTER_INVALID && m_stoch_engine != NULL)
     {
      delete m_stoch_engine;
      m_stoch_engine = NULL;
     }
   if(CheckPointer(m_bb_engine) != POINTER_INVALID && m_bb_engine != NULL)
     {
      delete m_bb_engine;
      m_bb_engine = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Comprehensive Initialization with Universal Price Routing        |
//+------------------------------------------------------------------+
bool CEnsembleVotingCalculator::Init(const double neutral_zone, const int smoothing_p,
                                     const int signal_p, const ENUM_MA_TYPE signal_ma,
                                     const ENUM_APPLIED_PRICE_HA_ALL price_source,
                                     const bool en_ema_cross, const double w_ema_cross, const int ema_fast_p, const int ema_slow_p,
                                     const bool en_price_sma, const double w_price_sma, const int sma_trend_p,
                                     const bool en_rsi, const double w_rsi, const int rsi_p,
                                     const bool en_macd, const double w_macd, const int macd_fast_p, const int macd_slow_p, const int macd_sig_p,
                                     const bool en_stoch, const double w_stoch, const int stoch_k_p, const int stoch_d_p,
                                     const bool en_bb, const double w_bb, const int bb_p, const double bb_mult,
                                     const bool en_donchian, const double w_donchian, const int don_p,
                                     const bool en_obv, const double w_obv, const int obv_ema_p,
                                     const bool en_mfi, const double w_mfi, const int mfi_p)
  {
   m_neutral_zone     = neutral_zone;
   m_smoothing_period = MathMax(1, smoothing_p);
   m_signal_period    = MathMax(1, signal_p);
   m_signal_ma_type   = signal_ma;
   m_source_price     = price_source;

   m_en_ema_cross = en_ema_cross;
   m_w_ema_cross = w_ema_cross;
   m_en_price_sma = en_price_sma;
   m_w_price_sma = w_price_sma;
   m_en_rsi       = en_rsi;
   m_w_rsi       = w_rsi;
   m_en_macd      = en_macd;
   m_w_macd      = w_macd;
   m_en_stoch     = en_stoch;
   m_w_stoch     = w_stoch;
   m_en_bb        = en_bb;
   m_w_bb        = w_bb;
   m_en_donchian  = en_donchian;
   m_w_donchian  = w_donchian;
   m_en_obv       = en_obv;
   m_w_obv       = w_obv;
   m_en_mfi       = en_mfi;
   m_w_mfi       = w_mfi;

   bool is_ha = (m_source_price <= PRICE_HA_CLOSE);

// 1. Trend Engines
   if(!m_ema_fast.Init(ema_fast_p, EMA))
      return false;
   if(!m_ema_slow.Init(ema_slow_p, EMA))
      return false;
   if(!m_sma_trend.Init(sma_trend_p, SMA))
      return false;

// 2. Momentum Engines (Instantiate Standard or HA variants)
   if(CheckPointer(m_rsi_engine) != POINTER_INVALID && m_rsi_engine != NULL)
      delete m_rsi_engine;
   m_rsi_engine = is_ha ? (CRSIEngine*)(new CRSIEngine_HA()) : (CRSIEngine*)(new CRSIEngine());
   if(!m_rsi_engine.Init(rsi_p))
      return false;

   if(CheckPointer(m_macd_engine) != POINTER_INVALID && m_macd_engine != NULL)
      delete m_macd_engine;
   m_macd_engine = is_ha ? (CMACDCalculator*)(new CMACDCalculator_HA()) : (CMACDCalculator*)(new CMACDCalculator());
   if(!m_macd_engine.Init(macd_fast_p, macd_slow_p, macd_sig_p, EMA, EMA, m_source_price))
      return false;

   if(CheckPointer(m_stoch_engine) != POINTER_INVALID && m_stoch_engine != NULL)
      delete m_stoch_engine;
   m_stoch_engine = is_ha ? (CStochasticFastCalculator*)(new CStochasticFastCalculator_HA()) : (CStochasticFastCalculator*)(new CStochasticFastCalculator());
   if(!m_stoch_engine.Init(stoch_k_p, stoch_d_p, SMA))
      return false;

// 3. Volatility & Channel Engines
   if(CheckPointer(m_bb_engine) != POINTER_INVALID && m_bb_engine != NULL)
      delete m_bb_engine;
   m_bb_engine = is_ha ? (CBollingerBandsCalculator*)(new CBollingerBandsCalculator_HA()) : (CBollingerBandsCalculator*)(new CBollingerBandsCalculator());
   if(!m_bb_engine.Init(bb_p, bb_mult, SMA, m_source_price))
      return false;

   ENUM_DONCHIAN_PRICE_TYPE don_p_type = is_ha ? PRICE_DONCHIAN_HEIKIN_ASHI : PRICE_DONCHIAN_STANDARD;
   if(!m_donchian_engine.Init(don_p, don_p, 0, don_p_type))
      return false;

// 4. Volume Engines
   if(!m_obv_engine.Init(obv_ema_p, EMA, m_source_price))
      return false;
   if(!m_mfi_engine.Init(mfi_p, 9, EMA, m_source_price))
      return false;

// 5. Consensus Smoothing & Secondary Signal Line Engines
   if(!m_smoothing_engine.Init(m_smoothing_period, EMA))
      return false;
   if(!m_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate with Long Volume Overload                              |
//+------------------------------------------------------------------+
void CEnsembleVotingCalculator::Calculate(const int rates_total, const int prev_calculated,
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
void CEnsembleVotingCalculator::Calculate(const int rates_total, const int prev_calculated,
      const double &open[], const double &high[], const double &low[], const double &close[],
      const double &volume[],
      double &consensus_out[], double &signal_out[], double &raw_score_out[], double &agreement_out[])
  {
   if(rates_total < 30)
      return;

// Allocate all internal registers with capacity reservation
   if(ArraySize(m_raw_score) != rates_total)
     {
      ArrayResize(m_buf_ema_fast,        rates_total, 2048);
      ArrayResize(m_buf_ema_slow,        rates_total, 2048);
      ArrayResize(m_buf_sma_trend,       rates_total, 2048);
      ArrayResize(m_buf_rsi,             rates_total, 2048);
      ArrayResize(m_buf_macd,            rates_total, 2048);
      ArrayResize(m_buf_signal,          rates_total, 2048);
      ArrayResize(m_buf_hist,            rates_total, 2048);
      ArrayResize(m_buf_stoch_k,         rates_total, 2048);
      ArrayResize(m_buf_stoch_d,         rates_total, 2048);
      ArrayResize(m_buf_bb_ma,           rates_total, 2048);
      ArrayResize(m_buf_bb_up,           rates_total, 2048);
      ArrayResize(m_buf_bb_low,          rates_total, 2048);
      ArrayResize(m_buf_bb_price,        rates_total, 2048);
      ArrayResize(m_buf_don_up,          rates_total, 2048);
      ArrayResize(m_buf_don_mid,         rates_total, 2048);
      ArrayResize(m_buf_don_low,         rates_total, 2048);
      ArrayResize(m_buf_obv,             rates_total, 2048);
      ArrayResize(m_buf_obv_sig,         rates_total, 2048);
      ArrayResize(m_buf_mfi,             rates_total, 2048);
      ArrayResize(m_buf_mfi_sig,         rates_total, 2048);
      ArrayResize(m_raw_score,           rates_total, 2048);
      ArrayResize(m_consensus_internal,  rates_total, 2048);

      ArraySetAsSeries(m_raw_score,          false);
      ArraySetAsSeries(m_consensus_internal, false);
     }

   ENUM_APPLIED_PRICE price_type = (m_source_price <= PRICE_HA_CLOSE) ?
                                   (ENUM_APPLIED_PRICE)(-((int)m_source_price) - 1) :
                                   (ENUM_APPLIED_PRICE)m_source_price;

// 1. Execute All 9 Headless DSP Engines
   m_ema_fast.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_ema_fast);
   m_ema_slow.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_ema_slow);
   m_sma_trend.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_sma_trend);
   m_rsi_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_buf_rsi);
   m_macd_engine.Calculate(rates_total, prev_calculated, open, high, low, close, volume, m_buf_macd, m_buf_signal, m_buf_hist);
   m_stoch_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_stoch_k, m_buf_stoch_d);
   m_bb_engine.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, volume, m_buf_bb_ma, m_buf_bb_up, m_buf_bb_low);
   m_bb_engine.GetPriceBuffer(m_buf_bb_price);
   m_donchian_engine.Calculate(rates_total, prev_calculated, open, high, low, close, m_buf_don_up, m_buf_don_mid, m_buf_don_low);
   m_obv_engine.Calculate(rates_total, prev_calculated, open, high, low, close, volume, m_buf_obv, m_buf_obv_sig);
   m_mfi_engine.Calculate(rates_total, prev_calculated, open, high, low, close, volume, m_buf_mfi, m_buf_mfi_sig);

   int loop_start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// 2. Voting Tally Loop
   for(int i = loop_start; i < rates_total; i++)
     {
      double c_price = m_buf_bb_price[i];

      // A) Trend Votes
      int v_ema_cross = DirectionVote(m_buf_ema_fast[i], m_buf_ema_slow[i]);
      int v_price_sma = DirectionVote(c_price, m_buf_sma_trend[i]);

      // B) Momentum Votes
      int v_rsi   = MidlineVote(m_buf_rsi[i], m_neutral_zone);
      int v_macd  = DirectionVote(m_buf_macd[i], m_buf_signal[i]);
      int v_stoch = MidlineVote(m_buf_stoch_k[i], m_neutral_zone);

      // C) Volatility & Channel Scaled Votes (0 to 100)
      double bb_width = m_buf_bb_up[i] - m_buf_bb_low[i];
      double bb_pct   = (bb_width > 0.0) ? (100.0 * (c_price - m_buf_bb_low[i]) / bb_width) : 50.0;
      int v_bb        = MidlineVote(bb_pct, m_neutral_zone);

      double don_width = m_buf_don_up[i] - m_buf_don_low[i];
      double don_pct   = (don_width > 0.0) ? (100.0 * (c_price - m_buf_don_low[i]) / don_width) : 50.0;
      int v_donchian   = MidlineVote(don_pct, m_neutral_zone);

      // D) Volume Votes
      int v_obv = DirectionVote(m_buf_obv[i], m_buf_obv_sig[i]);
      int v_mfi = MidlineVote(m_buf_mfi[i], m_neutral_zone);

      // E) Validity Flags
      bool valid_ema_cross = (m_buf_ema_fast[i] != EMPTY_VALUE && m_buf_ema_slow[i] != EMPTY_VALUE);
      bool valid_price_sma = (m_buf_sma_trend[i] != EMPTY_VALUE);
      bool valid_rsi       = (m_buf_rsi[i] != EMPTY_VALUE);
      bool valid_macd      = (m_buf_signal[i] != EMPTY_VALUE);
      bool valid_stoch     = (m_buf_stoch_k[i] != EMPTY_VALUE);
      bool valid_bb        = (m_buf_bb_up[i] != EMPTY_VALUE && m_buf_bb_low[i] != EMPTY_VALUE);
      bool valid_donchian  = (m_buf_don_up[i] != EMPTY_VALUE && m_buf_don_low[i] != EMPTY_VALUE);
      bool valid_obv       = (m_buf_obv_sig[i] != EMPTY_VALUE);
      bool valid_mfi       = (m_buf_mfi[i] != EMPTY_VALUE);

      // F) Weighted Consensus Aggregation
      double active_weight = 0.0;
      double bull_weight   = 0.0;
      double bear_weight   = 0.0;

#define TALLY_VOTE(en, valid, w, v) \
         if(en && valid) { \
            active_weight += w; \
            if(v > 0) bull_weight += w; \
            else if(v < 0) bear_weight += w; \
         }

      TALLY_VOTE(m_en_ema_cross, valid_ema_cross, m_w_ema_cross, v_ema_cross);
      TALLY_VOTE(m_en_price_sma, valid_price_sma, m_w_price_sma, v_price_sma);
      TALLY_VOTE(m_en_rsi,       valid_rsi,       m_w_rsi,       v_rsi);
      TALLY_VOTE(m_en_macd,      valid_macd,      m_w_macd,      v_macd);
      TALLY_VOTE(m_en_stoch,     valid_stoch,     m_w_stoch,     v_stoch);
      TALLY_VOTE(m_en_bb,        valid_bb,        m_w_bb,        v_bb);
      TALLY_VOTE(m_en_donchian,  valid_donchian,  m_w_donchian,  v_donchian);
      TALLY_VOTE(m_en_obv,       valid_obv,       m_w_obv,       v_obv);
      TALLY_VOTE(m_en_mfi,       valid_mfi,       m_w_mfi,       v_mfi);
#undef TALLY_VOTE

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
//| Extract Latest Bar Component Snapshot                            |
//+------------------------------------------------------------------+
void CEnsembleVotingCalculator::GetLatestSnapshot(SComponentVote &out_components[], int &out_bull_votes, int &out_bear_votes, int &out_neutral_votes) const
  {
   ArrayResize(out_components, 9);
   out_bull_votes    = 0;
   out_bear_votes    = 0;
   out_neutral_votes = 0;

   int last = ArraySize(m_raw_score) - 1;
   if(last < 0)
      return;

#define SET_COMP(idx, n, f, en, w, v, valid) \
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

   bool v_ema = (m_buf_ema_fast[last] != EMPTY_VALUE && m_buf_ema_slow[last] != EMPTY_VALUE);
   SET_COMP(0, "EMA Cross", "Trend", m_en_ema_cross, m_w_ema_cross, DirectionVote(m_buf_ema_fast[last], m_buf_ema_slow[last]), v_ema);

   bool v_sma = (m_buf_sma_trend[last] != EMPTY_VALUE);
   SET_COMP(1, "Price vs SMA", "Trend", m_en_price_sma, m_w_price_sma, DirectionVote(m_buf_bb_price[last], m_buf_sma_trend[last]), v_sma);

   bool v_rsi = (m_buf_rsi[last] != EMPTY_VALUE);
   SET_COMP(2, "RSI", "Momentum", m_en_rsi, m_w_rsi, MidlineVote(m_buf_rsi[last], m_neutral_zone), v_rsi);

   bool v_macd = (m_buf_signal[last] != EMPTY_VALUE);
   SET_COMP(3, "MACD", "Momentum", m_en_macd, m_w_macd, DirectionVote(m_buf_macd[last], m_buf_signal[last]), v_macd);

   bool v_stoch = (m_buf_stoch_k[last] != EMPTY_VALUE);
   SET_COMP(4, "Stochastic %K", "Momentum", m_en_stoch, m_w_stoch, MidlineVote(m_buf_stoch_k[last], m_neutral_zone), v_stoch);

   double bb_w = m_buf_bb_up[last] - m_buf_bb_low[last];
   double bb_p = (bb_w > 0.0) ? (100.0 * (m_buf_bb_price[last] - m_buf_bb_low[last]) / bb_w) : 50.0;
   bool v_bb = (m_buf_bb_up[last] != EMPTY_VALUE && m_buf_bb_low[last] != EMPTY_VALUE);
   SET_COMP(5, "Bollinger %B", "Volatility", m_en_bb, m_w_bb, MidlineVote(bb_p, m_neutral_zone), v_bb);

   double don_w = m_buf_don_up[last] - m_buf_don_low[last];
   double don_p = (don_w > 0.0) ? (100.0 * (m_buf_bb_price[last] - m_buf_don_low[last]) / don_w) : 50.0;
   bool v_don = (m_buf_don_up[last] != EMPTY_VALUE && m_buf_don_low[last] != EMPTY_VALUE);
   SET_COMP(6, "Donchian", "Channel", m_en_donchian, m_w_donchian, MidlineVote(don_p, m_neutral_zone), v_don);

   bool v_obv = (m_buf_obv_sig[last] != EMPTY_VALUE);
   SET_COMP(7, "OBV Trend", "Volume", m_en_obv, m_w_obv, DirectionVote(m_buf_obv[last], m_buf_obv_sig[last]), v_obv);

   bool v_mfi = (m_buf_mfi[last] != EMPTY_VALUE);
   SET_COMP(8, "MFI", "Volume", m_en_mfi, m_w_mfi, MidlineVote(m_buf_mfi[last], m_neutral_zone), v_mfi);

#undef SET_COMP
  }

#endif // ENSEMBLE_VOTING_CALCULATOR_MQH
//+------------------------------------------------------------------+
