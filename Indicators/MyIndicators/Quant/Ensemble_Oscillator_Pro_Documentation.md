# Ensemble Oscillator Pro (v2.30)

## Institutional Multi-Timeframe Multi-Model Consensus Oscillator Suite Across Trend, Momentum, Volatility & Volume

**Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Ensemble Voting Philosophy

**Ensemble Oscillator Pro (v2.30)** is the flagship quantitative consensus oscillator of the Professional MQL5 Suite. Built upon the principles of **Ensemble Learning** and **Multi-Factor Quantitative Modeling**, it solves the fundamental flaw of single-indicator analysis: **correlation blindness and indicator redundancy**.

Most retail traders clutter their charts with 3 or 4 momentum oscillators (e.g. RSI, Stochastic, CCI) that simply duplicate the exact same price-rate-of-change information while completely ignoring macro trend direction, volatility boundaries, and institutional volume flow.

**Ensemble Oscillator Pro synthesizes 9 independent digital signal processing (DSP) engines across the 4 foundational pillars of market auction theory into a single, unified consensus score**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   ENSEMBLE VOTING: THE 4 PILLARS                       │
├─────────────────────┬──────────────────────────────────────────────────┤
│ 1. TREND PILLAR     │ • Fast EMA vs. Slow EMA Cross (Directional)      │
│                     │ • Price vs. 200 SMA Macro Baseline (Directional) │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 2. MOMENTUM PILLAR  │ • RSI (Midline with Neutral Noise Buffer)        │
│                     │ • MACD Line vs. Signal Line (Directional)        │
│                     │ • Fast Stochastic %K (Midline with Neutral Band) │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 3. VOLATILITY PILLAR│ • Bollinger %B (Normalized 0-100 Relative Range) │
│                     │ • Donchian Channel Position % (Scaled Range)     │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 4. VOLUME PILLAR    │ • OBV Trend (On Balance Volume vs. Signal EMA)   │
│                     │ • Money Flow Index (Volume-Weighted RSI Flow)    │
└─────────────────────┴──────────────────────────────────────────────────┘
```

---

## 2. Component Taxonomy & Voting Engine Mechanics

```text
               RAW MARKET OHLCV & TICK / REAL VOLUME INPUT
                                    │
    ┌─────────────────┬─────────────┴───┬─────────────────┬─────────────────┐
    ▼                 ▼                 ▼                 ▼                 ▼
Trend Family   Momentum Family   Volatility Family  Volume Family    Universal Price
(EMA/SMA)       (RSI/MACD/Stoch)    (BB %B / Donchian) (OBV / MFI)     Routing Engine
    │                 │                 │                 │                 │
    └─────────────────┼─────────────────┴─────────────────┘                 │
                      ▼                                                     │
         Discrete Component Voting Engine                                   │
      Each voter casts: +1 (Bull), -1 (Bear), 0 (Neutral)                   │
                      │                                                     │
                      ▼                                                     │
        Weighted Consensus Aggregator (0 to 100)                            │
      Raw Score = 100 · (BullWeight - BearWeight) / ActiveWeight            │
                      │                                                     │
                      ▼                                                     │
         EMA Consensus Smoothing Engine (Length 3)                          │
                      │                                                     │
         ┌────────────┴────────────┐                                        │
         ▼                         ▼                                        │
Consensus Score Line/Histogram  14-Model Signal Line                        │
(Threshold-Colored -20 to +20)  (MovingAverage_Engine.mqh)                  │
```

### 2.1. Discrete Voting State Machines

Every component independently casts a discrete directional vote on every bar:

- **$+1$ (Bullish Vote):** Positive trend, upper half of channel, bullish momentum, or volume accumulation.
- **$-1$ (Bearish Vote):** Negative trend, lower half of channel, bearish momentum, or volume distribution.
- **$0$ (Neutral Vote):** Market oscillator trading inside the configured `InpNeutralZone` (dead zone around the 50 midline).

### 2.2. Voting Logic Specifications

#### A) Directional Votes (`DirectionVote(a, b)`)

Used for relative series position (fast vs. slow, or value vs. average):
$$\text{Vote}(a, b) = \begin{cases} +1 & \text{if } a > b \\ -1 & \text{if } a < b \\ 0 & \text{otherwise} \end{cases}$$

1. **EMA Cross:** $\text{FastEMA}_t$ vs. $\text{SlowEMA}_t$.
2. **Price vs. SMA:** $\text{Close}_t$ vs. $\text{SMA200}_t$.
3. **MACD:** $\text{MACD Line}_t$ vs. $\text{Signal Line}_t$.
4. **OBV Trend:** $\text{OBV}_t$ vs. $\text{OBV EMA}_t$.

#### B) Midline Bounded Votes (`MidlineVote(val, buffer)`)

Used for oscillators bounded to $0 \dots 100$. Incorporates the half-width neutral buffer $Z$ (`InpNeutralZone`, default $5.0$):
$$\text{Vote}(val, Z) = \begin{cases} +1 & \text{if } val > 50.0 + Z \quad (\text{Upper Bullish Regime}) \\ -1 & \text{if } val < 50.0 - Z \quad (\text{Lower Bearish Regime}) \\ 0 & \text{if } 50.0 - Z \le val \le 50.0 + Z \quad (\text{Neutral Indecision}) \end{cases}$$
5. **RSI:** Evaluated against $50 \pm Z$.
6. **Fast Stochastic %K:** Smooth Fast %K evaluated against $50 \pm Z$.
7. **Bollinger %B (Normalized):**
   $$\text{BandWidth}_t = \text{UpperBB}_t - \text{LowerBB}_t$$
   $$\text{\%B}_t = \begin{cases} 100 \times \frac{\text{Close}_t - \text{LowerBB}_t}{\text{BandWidth}_t} & \text{if } \text{BandWidth}_t > 0 \\ 50.0 & \text{otherwise} \end{cases}$$
8. **Donchian Channel Position % (Normalized):**
   $$\text{DonchianWidth}_t = \text{UpperDonchian}_t - \text{LowerDonchian}_t$$
   $$\text{Donchian\%}_t = \begin{cases} 100 \times \frac{\text{Close}_t - \text{LowerDonchian}_t}{\text{DonchianWidth}_t} & \text{if } \text{DonchianWidth}_t > 0 \\ 50.0 & \text{otherwise} \end{cases}$$
9. **Money Flow Index (MFI):** Volume-weighted RSI flow evaluated against $50 \pm Z$.

---

## 3. Consensus Scoring, Weighting & Agreement Mathematics

Each voter possesses an independent weight $W_i \in [0.0, 10.0]$ and an enable toggle. A voter is only tallied if it is enabled **and** has sufficient historical bars to be valid.

### 3.1. Active and Directional Weight Aggregation

$$\text{ActiveWeight}_t = \sum_{i \in \text{Valid}} W_i$$
$$\text{BullWeight}_t = \sum_{i \in \text{Valid}, \text{Vote}_i = +1} W_i, \quad\quad \text{BearWeight}_t = \sum_{i \in \text{Valid}, \text{Vote}_i = -1} W_i$$

### 3.2. Raw Consensus Score

The net directional balance scaled to a normalized $[-100.0, +100.0]$ domain:
$$\text{RawScore}_t = \begin{cases} 100 \times \frac{\text{BullWeight}_t - \text{BearWeight}_t}{\text{ActiveWeight}_t} & \text{if } \text{ActiveWeight}_t > 0 \\ 0.0 & \text{otherwise} \end{cases}$$

### 3.3. Consensus Smoothing (EMA Filter)

To prevent flickering along threshold boundaries, the raw score is smoothed via a low-lag Exponential Moving Average (`InpConsensusSmoothing`, default 3):
$$\text{Consensus}_t = \text{EMA}(\text{RawScore}, \text{InpConsensusSmoothing})_t$$

### 3.4. The Agreement Metric (%)

Quantifies the supermajority percentage of active capital aligned on the dominant side:
$$\text{Agreement}_t = \begin{cases} 100 \times \frac{\max(\text{BullWeight}_t, \text{BearWeight}_t)}{\text{ActiveWeight}_t} & \text{if } \text{ActiveWeight}_t > 0 \\ 0.0 & \text{otherwise} \end{cases}$$
*Interpretation:* An Agreement reading of $100\%$ indicates absolute unanimous alignment across all 9 components. An Agreement near $50\%$ indicates complete market gridlock and conflict.

### 3.5. Rating Bands Taxonomy

```text
  Consensus Score      Rating Band         Visual Action / Interpretation
  ───────────────      ───────────         ──────────────────────────────────────────────────
  >= +60.0             STRONG BUY          Supermajority Bullish Expansion (Max Trend Weight)
  +20.0 ... +60.0      BUY                 Actionable Bullish Consensus (Exited Neutral Zone)
  -20.0 ... +20.0      NEUTRAL             Indecision / Chop Zone (Colored Gray on Histogram)
  -60.0 ... -20.0      SELL                Actionable Bearish Consensus (Exited Neutral Zone)
  <= -60.0             STRONG SELL         Supermajority Bearish Expansion (Max Trend Weight)
```

---

## 4. Invariant 2-Plot / 3-Buffer Architecture & Visual Modes

To eliminate MetaTrader 5's internal plot-to-buffer shifting bugs, `Ensemble_Oscillator_Pro` implements an **Invariant 2-Plot / 3-Buffer Architecture**:

```text
  Plot 0: Consensus Plot (ALWAYS consumes Buffer 0 and Buffer 1)
          ├── Histogram Mode: DRAW_COLOR_HISTOGRAM (3-Color Threshold Shading)
          └── Line Mode:      DRAW_COLOR_LINE (Single-Color Uniform Mapping)
          ├── Buffer 0: BufferConsensus    (INDICATOR_DATA)
          └── Buffer 1: BufferColors       (INDICATOR_COLOR_INDEX)

  Plot 1: Signal Line Plot (ALWAYS consumes Buffer 2)
          └── Buffer 2: BufferSignalLine   (INDICATOR_DATA, DRAW_LINE)
```

### 4.1. Threshold-Based Neutral Zone Coloring ($[-20, +20]$)

In Histogram Mode, bars of height $0.0$ possess zero vertical pixels, rendering a zero-line color useless.

**The indicator applies a 3-state threshold engine to color the entire consolidation zone**:
$$\text{ColorIndex}_t = \begin{cases}
0 \quad (\text{Bullish Green}) & \text{if } \text{Consensus}_t > +\text{SignalThreshold} \quad (+20) \\
1 \quad (\text{Bearish Red}) & \text{if } \text{Consensus}_t < -\text{SignalThreshold} \quad (-20) \\
2 \quad (\text{Neutral Gray}) & \text{if } -\text{SignalThreshold} \le \text{Consensus}_t \le +\text{SignalThreshold}
\end{cases}$$

### 4.2. Level Configuration by Mode
* **Histogram Mode:** The $0.0$ baseline is omitted because the histogram bars naturally originate from zero. Only the 4 operational levels are rendered: $+60, +20, -20, -60$.
* **Line Mode:** The $0.0$ midline is dynamically added (5 total levels: $+60, +20, 0.0, -20, -60$) to provide a clear equilibrium reference.

### 4.3. Secondary Signal Line Integration
The Consensus series is filtered by `m_signal_engine` using any of the 14 moving average algorithms (`InpSignalMAType`, default 9-period EMA):
$$\text{SignalLine}_t = \mathcal{M}_{\text{sig}}(\text{Consensus}, \text{InpSignalPeriod})_t$$

---

## 5. Enterprise MTF Fast-Path Protocol

When configuring higher-timeframe consensus on lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

```text
  HTF Domain (e.g. H1)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

1. **Atomic Single-Query Rates Synchronization:** A single `CopyRates()` query acquires all OHLCV and volume bars for the HTF domain simultaneously in nanoseconds.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting both the Consensus score and the Signal Line onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 6. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard native operation, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Universal Price Source ===
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Global price source. Scalar price indicators (MA, RSI, MACD, BB) receive this price directly. Extreme-price indicators (Fast Stochastic, Donchian) automatically route to Standard High/Low vs. Synthetic Heikin Ashi High/Low based on this selection.

### === Consensus Core & Visual Mode ===
* **`InpPlotMode`** (*default: `PLOT_MODE_HISTOGRAM`*): Selects between `PLOT_MODE_HISTOGRAM` (multi-color bars) and `PLOT_MODE_LINE` (single-color line).
* **`InpColorConsensusLine`** (*default: `clrDodgerBlue`*): Line color for the consensus curve in Line Mode.
* **`InpStyleConsensusLine`** (*default: `STYLE_SOLID`*): Line style in Line Mode.
* **`InpWidthConsensusLine`** (*default: `2`*): Line width in Line Mode.
* **`InpColorHistBull`** (*default: `clrMediumSeaGreen`*): Histogram color when consensus exceeds $+20$ (Buy Zone).
* **`InpColorHistBear`** (*default: `clrCrimson`*): Histogram color when consensus drops below $-20$ (Sell Zone).
* **`InpColorHistNeutral`** (*default: `clrDarkGray`*): Histogram color when consensus trades inside $[-20, +20]$ (Neutral Zone).
* **`InpWidthHist`** (*default: `2`*): Bar thickness in Histogram Mode.
* **`InpSignalThreshold`** (*default: `20`*): Minimum net score required to leave the neutral zone and rate the market Buy or Sell.
* **`InpStrongThreshold`** (*default: `60`*): Net score required to enter the Strong Buy or Strong Sell supermajority band.
* **`InpConsensusSmoothing`** (*default: `3`*): Lookback length for the smoothing EMA applied to the raw consensus tally.
* **`InpNeutralZone`** (*default: `5.0`*): Half-width buffer around the 50 midline of bounded components ($50 \pm Z$).

### === Signal Line Settings & Visuals ===
* **`InpShowSignalLine`** (*default: `true`*): Toggles visibility of the Signal Moving Average line.
* **`InpSignalPeriod`** (*default: `9`*): Smoothing lookback period for the Signal Line.
* **`InpSignalMAType`** (*default: `EMA`*): Moving average algorithm used to smooth the Consensus series (Selectable across all 14 modular models).
* **`InpColorSignalLine`** (*default: `clrOrangeRed`*): Color of the Signal Line.
* **`InpStyleSignalLine`** (*default: `STYLE_DOT`*): Style of the Signal Line.
* **`InpWidthSignalLine`** (*default: `1`*): Width of the Signal Line.

### === Component Configuration Sections ===
Each component section encapsulates its voter toggle, tally weight, and mathematical lookback periods:
* **`1. Trend Components`:**
  - `InpMaCrossEnable` (*default: `true`*), `InpMaCrossWeight` (*1.0*), `InpMaCrossFast` (*20*), `InpMaCrossSlow` (*50*).
  - `InpPriceMaEnable` (*default: `true`*), `InpPriceMaWeight` (*1.0*), `InpPriceMaLength` (*200*).
* **`2. Momentum Components`:**
  - `InpRsiEnable` (*default: `true`*), `InpRsiWeight` (*1.0*), `InpRsiLength` (*14*).
  - `InpMacdEnable` (*default: `true`*), `InpMacdWeight` (*1.0*), `InpMacdFast` (*12*), `InpMacdSlow` (*26*), `InpMacdSignal` (*9*).
  - `InpStochEnable` (*default: `true`*), `InpStochWeight` (*1.0*), `InpStochLength` (*14*), `InpStochSmooth` (*3*).
* **`3. Channel & Volatility Components`:**
  - `InpBbEnable` (*default: `true`*), `InpBbWeight` (*1.0*), `InpBbLength` (*20*), `InpBbMult` (*2.0*).
  - `InpDonchianEnable` (*default: `true`*), `InpDonchianWeight` (*1.0*), `InpDonchianLength` (*20*).
* **`4. Volume Components`:**
  - `InpObvEnable` (*default: `true`*), `InpObvWeight` (*1.0*), `InpObvLength` (*20*).
  - `InpMfiEnable` (*default: `true`*), `InpMfiWeight` (*1.0*), `InpMfiLength` (*14*).

---

## 7. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   ENSEMBLE OSCILLATOR PLAYBOOKS                        │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Neutral Zone Breakout:      Consensus breaking out of [-20, +20]    │
│                                confirms collective multi-model flow.   │
│ 2. Signal Line Crossover:      Consensus crossing above Signal Line    │
│                                while outside Neutral Zone -> Trigger.  │
│ 3. Supermajority Climax:       Consensus pinning at +100 or -100       │
│                                confirms aggressive macro trend regime. │
│ 4. MTF Macro Alignment:        Only take M5 long breakouts when the    │
│                                H1/H4 Consensus is positive (> +20).    │
└────────────────────────────────────────────────────────────────────────┘
```

### 7.1. Playbook 1: Neutral Zone Breakout (Consensus Quorum)
* **Market State:** Market is consolidating; the histogram displays gray bars bounded between $-20$ and $+20$. The 9 components are in conflict.
* **The Quorum Trigger:**
  - **Bullish Quorum:** The histogram turns **Green** as Consensus crosses strictly **above $+20.0$**.
  - **Bearish Quorum:** The histogram turns **Red** as Consensus crosses strictly **below $-20.0$**.
* **Execution Rule:** Do not initiate directional swing positions while bars remain gray. Enter on the candle where the quorum turns green or red.

### 7.2. Playbook 2: Signal Line Momentum Crossover
* **Mechanism:** The 9-period Signal Line provides dynamic trend smoothing.
* **Bullish Crossover:** Consensus line crosses **above** the Signal Line while already above $+20.0$ $\rightarrow$ High-conviction long continuation entry.
* **Bearish Crossover:** Consensus line crosses **below** the Signal Line while already below $-20.0$ $\rightarrow$ High-conviction short continuation entry.

### 7.3. Playbook 3: Supermajority Institutional Climax ($\ge \pm 60.0$)
* **Mechanism:** Reaching the Strong Threshold ($+60$ or $-60$) requires that at least $80\%$ of active weighted components agree on direction.
* **Trade Management:** When Consensus enters the Strong Buy ($> +60$) or Strong Sell ($< -60$) band, the market is in a runaway trend impulse. Trail stop-losses aggressively along the Signal Line rather than trying to fade or mean-revert the move.

### 7.4. Playbook 4: Multi-Timeframe Consensus Alignment
* Attach an **H1-calculated Ensemble Oscillator Pro** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferConsensus}_{\text{H1 Step}} > +20.0 \implies \text{Long Orders Allowed Only}$$
  $$\text{If } \text{BufferConsensus}_{\text{H1 Step}} < -20.0 \implies \text{Short Orders Allowed Only}$$
* Eliminates counter-trend scalping against macro institutional consensus.

---

## 8. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Visual Mode Role | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferConsensus` | `INDICATOR_DATA` | Primary Data | Consensus Score ($-100.0 \dots +100.0$) |
| **1** | `BufferColors` | `INDICATOR_COLOR_INDEX` | Shading Index | 0 = Bull ($>+20$), 1 = Bear ($<-20$), 2 = Neutral ($[-20,+20]$) |
| **2** | `BufferSignalLine` | `INDICATOR_DATA` | Secondary Plot | Smoothed Signal Line ($-100.0 \dots +100.0$) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Ensemble Oscillator Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Ensemble Oscillator Pro
int handle = iCustom(_Symbol, _Period, "Ensemble_Oscillator_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     PRICE_CLOSE_STD,        // InpSourcePrice (Universal Price Source)
                     PLOT_MODE_HISTOGRAM,    // InpPlotMode
                     // ... remaining core, signal and voter settings use defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Ensemble_Oscillator_Pro handle.");
   return;
  }

//--- Read finalized closed bar values (Bar index 1)
double consensus_val[], signal_val[];
ArraySetAsSeries(consensus_val, true);
ArraySetAsSeries(signal_val,    true);

if(CopyBuffer(handle, 0, 1, 2, consensus_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, signal_val) == 2)
  {
   double cons_curr   = consensus_val[0];  // Closed bar (Bar 1)
   double cons_prev   = consensus_val[1];  // Prior closed bar (Bar 2)
   double signal_curr = signal_val[0];
   double signal_prev = signal_val[1];

   // Example Strategy: Bullish Consensus Quorum Breakout above +20
   bool is_quorum_long = (cons_prev <= 20.0 && cons_curr > 20.0);

   // Example Strategy: Bullish Signal Line Crossover in Buy Zone
   bool is_crossover_long = (cons_prev <= signal_prev && cons_curr > signal_curr && cons_curr > 20.0);

   if(is_quorum_long || is_crossover_long)
     {
      // Execute Buy Order (Supermajority Quantitative Consensus)
     }
  }
```
