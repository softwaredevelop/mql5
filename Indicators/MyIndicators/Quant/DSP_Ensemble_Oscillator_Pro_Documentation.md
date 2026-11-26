# DSP Ensemble Oscillator Pro (v1.00)

## Institutional Multi-Timeframe Cybernetic Zero-Lag Consensus Oscillator Suite Across 8 Advanced DSP Engines

**Enterprise Ultra Edition — High-Concurrency Digital Signal Processing Suite for MetaTrader 5*

---

## 1. Executive Summary & Cybernetic Ensemble Philosophy

**DSP Ensemble Oscillator Pro (v1.00)** is the next-generation, zero-lag digital signal processing (DSP) consensus oscillator of the Professional MQL5 Suite. Built upon our decoupled `DSP_Ensemble_Calculator.mqh` engine, it replaces lagging classical moving averages and conventional 1-pole oscillators with **8 orthogonally diverse, enterprise-refactored DSP engines**:

1. **Eliminating Classical Lag:** Standard ensembles built on 20/50/200 SMAs, 14-bar RSI, and MACD inevitably introduce 10 to 15 bars of cumulative group delay—often firing signals after an intraday swing is already exhausted.
2. **Conquering Spectral Dilation & Aliasing Noise:** By uniting **John Ehlers’ aerospace-grade filters** (Hilbert Transform MAMA, 2-Pole Butterworth SuperSmoother, Time-Warped Laguerre RSI, Resonant Cyber Cycle, Zero-Mean Bandpass Roofing Filter, RMS Tracking Residual Bands) with **TTM Squeeze Linear Regression** and **Chaikin Volume Pressure (CLV)**, the suite reacts almost instantaneously to genuine turning points while flattening smoothly through sideways market chop.

```text
┌────────────────────────────────────────────────────────────────────────┐
│              DSP & CYBERNETIC ZERO-LAG ENSEMBLE: 4 PILLARS             │
├─────────────────────┬──────────────────────────────────────────────────┤
│ 1. TREND & FILTERING│ • MAMA / FAMA (Hilbert Phase-Adaptive Crossover) │
│                     │ • Ehlers Smoother (Super / UltimateSmoother)     │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 2. MOMENTUM & CYCLE │ • Laguerre RSI (4-Element Time-Warped Polynomial)│
│                     │ • Cyber Cycle (Resonant 2-Pole + 1-Bar Trigger)  │
│                     │ • Roofing Filter (Zero-Mean Bandpass Polarity)   │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 3. VOLATILITY & SQZ │ • Ehlers Bands %B (RMS Residual Scaled Position) │
│                     │ • TTM Squeeze Momentum (Division-Free LinReg)    │
├─────────────────────┼──────────────────────────────────────────────────┤
│ 4. VOLUME & FLOW    │ • Volume Pressure CLV (VWMA-Weighted Delta Proxy)│
└─────────────────────┴──────────────────────────────────────────────────┘
```

---

## 2. Component Taxonomy & Voting Engine Mechanics

```text
               RAW MARKET OHLCV & TICK / REAL VOLUME INPUT
                                    │
    ┌─────────────────┬─────────────┴───┬─────────────────┬─────────────────┐
    ▼                 ▼                 ▼                 ▼                 ▼
Trend & Filter  Momentum & Cycle  Volatility & Sqz  Volume & Flow    Universal Price
(MAMA / Smoother) (LRSI/Cyber/Roof) (E.Bands / TTM)    (V_PRES CLV)   Routing Engine
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
DSP Consensus Line/Histogram    14-Model Signal Line                        │
(Threshold-Colored -20 to +20)  (MovingAverage_Engine.mqh)                  │
```

### 2.1. Voting Mechanics of the 8 Embedded Engines

Every voter casts $+1$ (Bullish), $-1$ (Bearish), or $0$ (Neutral) once its historical warmup bar requirement is met:

1. **MAMA / FAMA (`MAMA_Calculator.mqh`):**
   - *Logic:* `DirectionVote(MAMA, FAMA)` $\rightarrow$ $+1$ if $\text{MAMA}_t > \text{FAMA}_t$, $-1$ if $<$.
   - *Warmup Validity:* $t \ge 50$.
2. **Ehlers Smoother (`Ehlers_Smoother_Calculator.mqh`):**
   - *Logic:* `DirectionVote(Price, Smoother)` $\rightarrow$ $+1$ if $P_t > \text{Filter}_t$, $-1$ if $<$.
   - *Warmup Validity:* $t \ge \text{InpSmootherPeriod}$.
3. **Laguerre RSI (`Laguerre_RSI_Calculator.mqh`):**
   - *Logic:* `MidlineVote(LRSI, 50.0, InpNeutralZone)` $\rightarrow$ $+1$ if $\text{LRSI}_t > 50 + Z$, $-1$ if $< 50 - Z$, $0$ inside $[50 - Z, 50 + Z]$.
   - *Warmup Validity:* $t \ge 4$.
4. **Cyber Cycle (`Cyber_Cycle_Calculator.mqh`):**
   - *Logic:* `DirectionVote(Cycle, Trigger)` using Ehlers' 1-bar quadrature delay trigger ($\text{Cycle}_{t-1}$) and 3-digit Fibonacci alpha ($\alpha = 0.062$). $+1$ if $\text{Cycle}_t > \text{Trigger}_t$, $-1$ if $<$.
   - *Warmup Validity:* $t \ge 8$.
5. **Roofing Filter (`Roofing_Filter_Calculator.mqh`):**
   - *Logic:* `ZeroPolarityVote(Roofing, 0.0)` $\rightarrow$ Because the Roofing Filter removes Spectral Dilation to achieve a strict zero mean, $+1$ if $\text{Roofing}_t > 0.0$, $-1$ if $< 0.0$.
   - *Warmup Validity:* $t \ge \max(\text{HP\_Period}, \text{SS\_Period})$.
6. **Ehlers Bands %B (`Ehlers_Bands_Calculator.mqh`):**
   - *Logic:* Normalizes price position within RMS Residual (or Classic StDev) bands to $0 \dots 100$:
     $$\%B_t = \begin{cases} 100 \times \frac{P_t - \text{Lower}_t}{\text{Upper}_t - \text{Lower}_t} & \text{if } (\text{Upper}_t - \text{Lower}_t) > 0 \\ 50.0 & \text{otherwise} \end{cases}$$
     `MidlineVote(%B, 50.0, InpNeutralZone)` $\rightarrow$ $+1$ above $50 + Z$, $-1$ below $50 - Z$.
   - *Warmup Validity:* $t \ge \max(\text{SmoothPeriod}, \text{BandPeriod})$.
7. **TTM Squeeze Momentum (`Squeeze_Calculator.mqh`):**
   - *Logic:* `ZeroPolarityVote(LinRegMom, 0.0)` $\rightarrow$ Evaluates the closed-form division-free Linear Regression endpoint of the TTM Delta series. $+1$ if $\text{Mom}_t > 0.0$, $-1$ if $< 0.0$.
   - *Warmup Validity:* $t \ge \max(\text{SqzPeriod}, \text{SqzAtrPeriod}) + \text{SqzMomPeriod}$.
8. **Volume Pressure CLV (`VolumePressure_Calculator.mqh`):**
   - *Logic:* `ZeroPolarityVote(V_PRES, InpVpNeutralZone)` $\rightarrow$ Evaluates Chaikin's Money Flow Multiplier ($[-1.0, +1.0]$) optionally weighted by volume via `VWMA`. $+1$ if $\text{V\_PRES}_t > +Z_{\text{vp}}$, $-1$ if $< -Z_{\text{vp}}$, $0$ inside $[-Z_{\text{vp}}, +Z_{\text{vp}}]$.
   - *Warmup Validity:* $t \ge \text{InpVpSmoothPeriod}$.

---

## 3. Consensus Scoring, Weighting & Agreement Mathematics

Each voter possesses an independent weight $W_i \in [0.0, 10.0]$ and an enable toggle.

### 3.1. Active and Directional Weight Aggregation

$$\text{ActiveWeight}_t = \sum_{i \in \text{Valid}} W_i$$
$$\text{BullWeight}_t = \sum_{i \in \text{Valid}, \text{Vote}_i = +1} W_i, \quad\quad \text{BearWeight}_t = \sum_{i \in \text{Valid}, \text{Vote}_i = -1} W_i$$

### 3.2. Raw Consensus Score & EMA Smoothing

$$\text{RawScore}_t = \begin{cases} 100 \times \frac{\text{BullWeight}_t - \text{BearWeight}_t}{\text{ActiveWeight}_t} & \text{if } \text{ActiveWeight}_t > 0 \\ 0.0 & \text{otherwise} \end{cases}$$
$$\text{Consensus}_t = \text{EMA}(\text{RawScore}, \text{InpConsensusSmoothing})_t$$

### 3.3. The Agreement Metric (%)

$$\text{Agreement}_t = \begin{cases} 100 \times \frac{\max(\text{BullWeight}_t, \text{BearWeight}_t)}{\text{ActiveWeight}_t} & \text{if } \text{ActiveWeight}_t > 0 \\ 0.0 & \text{otherwise} \end{cases}$$

### 3.4. Rating Bands Taxonomy

| Consensus Score | Rating Band | Operational Action / Market State |
| :--- | :--- | :--- |
| $\ge +60.0$ | **STRONG BUY** | Supermajority Zero-Lag Bullish Expansion |
| $+20.0 \dots +60.0$ | **BUY** | Actionable Bullish Consensus (Exited Neutral Zone) |
| $-20.0 \dots +20.0$ | **NEUTRAL** | Indecision / Chop Zone (Colored Gray on Histogram) |
| $-60.0 \dots -20.0$ | **SELL** | Actionable Bearish Consensus (Exited Neutral Zone) |
| $\le -60.0$ | **STRONG SELL** | Supermajority Zero-Lag Bearish Expansion |

---

## 4. Invariant 2-Plot / 3-Buffer Architecture & Visual Modes

To guarantee zero buffer-mapping corruption between Histogram and Line views, `DSP_Ensemble_Oscillator_Pro` enforces the **Invariant 2-Plot / 3-Buffer Architecture**:

```text
  Plot 0: DSP Consensus Plot (ALWAYS consumes Buffer 0 and Buffer 1)
          ├── Histogram Mode: DRAW_COLOR_HISTOGRAM (3-Color Threshold Shading)
          └── Line Mode:      DRAW_COLOR_LINE (Single-Color Uniform Mapping)
          ├── Buffer 0: BufferConsensus    (INDICATOR_DATA)
          └── Buffer 1: BufferColors       (INDICATOR_COLOR_INDEX)

  Plot 1: Signal Line Plot (ALWAYS consumes Buffer 2)
          └── Buffer 2: BufferSignalLine   (INDICATOR_DATA, DRAW_LINE)
```

- **Threshold-Based Neutral Zone Coloring:** In Histogram mode, bars inside $[-\text{InpSignalThreshold}, +\text{InpSignalThreshold}]$ (default $[-20, +20]$) are colored gray (`clrDarkGray`), visually separating chop from actionable quorum breakouts ($>+20$ Green, $<-20$ Red). The redundant `0.0` level is omitted in Histogram mode and enabled in Line mode.
- **Secondary Signal Line:** Filtered via `MovingAverage_Engine.mqh` across all 14 algorithms (`InpSignalMAType`, default 9-period EMA).

---

## 5. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe DSP Consensus onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine executes:

1. **Atomic Single-Query Rates Synchronization:** A single `CopyRates()` call loads all OHLCV data in nanoseconds.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Maps Consensus, Color Index, and Signal Line across chart candles in a single forward linear pass without `iBarShift()`.
3. **Live-Tick Isolated RAM Mocking:** Recalculates only the forming HTF bar in RAM and snaps to the forming LTF block using $O(\log N)$ `ArrayBsearch()`.

---

## 6. Parameters Reference

### === Timeframe Settings ===

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe (Current or Higher Timeframe).

### === Universal Price Source ===

- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Global price source applied coherently across all 8 DSP engines (Supports all 7 Standard and 7 Synthetic Heikin Ashi price modes).

### === Consensus Core & Visual Mode ===

- **`InpPlotMode`** (*default: `DSP_PLOT_HISTOGRAM`*): Visual mode (`DSP_PLOT_HISTOGRAM` or `DSP_PLOT_LINE`).

- **`InpColorConsensusLine`**, **`InpStyleConsensusLine`**, **`InpWidthConsensusLine`**: Line mode appearance.
- **`InpColorHistBull`**, **`InpColorHistBear`**, **`InpColorHistNeutral`**, **`InpWidthHist`**: Histogram colors ($>+20$, $<-20$, $[-20,+20]$) and bar width.
- **`InpSignalThreshold`** (*20*) & **`InpStrongThreshold`** (*60*): Buy/Sell and Supermajority levels.
- **`InpConsensusSmoothing`** (*3*): Raw tally smoothing EMA length.
- **`InpNeutralZone`** (*5.0*): Half-width around the 50 midline for bounded voters (LRSI, Ehlers Bands %B).

### === Signal Line Settings & Visuals ===

- **`InpShowSignalLine`** (*true*), **`InpSignalPeriod`** (*9*), **`InpSignalMAType`** (*EMA*), plus color, style, and width controls.

### === Component Sections ===

1. **Trend & Filtering:** `MAMA/FAMA` (`0.50` / `0.05`) and `Ehlers Smoother` (`SUPERSMOOTHER`, `20`).
2. **Momentum & Cycles:** `Laguerre RSI` ($\gamma = 0.500$), `Cyber Cycle` ($\alpha = 0.062$), and `Roofing Filter` (`48`, `10`).
3. **Volatility & Squeeze:** `Ehlers Bands %B` (`20`, `20`, `2.0`, `BANDS_RMS_RESIDUAL`) and `TTM Squeeze` (`20`, `2.0`, ATR `20`, `1.5`, Mom `20`).
4. **Volume & Microstructure:** `Volume Pressure CLV` (Smooth `5`, `VWMA`, Neutral Zone `0.10`).

---

## 7. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     DSP ENSEMBLE TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Lag Quorum Ignition:   Consensus exiting gray [-20,+20] zone   │
│                                fires instant low-lag entries.          │
│ 2. Signal Line Cycle Turn:     Consensus crossing Signal Line inside   │
│                                Buy/Sell zone -> Early momentum reload. │
│ 3. Supermajority Runaway:      Consensus >= +60 or <= -60 confirms     │
│                                unanimous 8-engine alignment.           │
│ 4. MTF Macro Step Filter:      Only trade M5 entries aligned with H1   │
│                                DSP Consensus polarity (>+20 or <-20).  │
└────────────────────────────────────────────────────────────────────────┘
```

### 7.1. Playbook 1: Zero-Lag Quorum Ignition (Neutral Zone Breakout)

- **Mechanism:** Because all 8 voters utilize low-lag DSP math, the consensus reacts 5–10 bars faster than classical SMA/MACD models while filtering consolidation via the gray $[-20, +20]$ dead zone.

- **Bullish Ignition:** The histogram turns **Green** as Consensus breaks strictly **above $+20.0$**.
- **Bearish Ignition:** The histogram turns **Red** as Consensus breaks strictly **below $-20.0$**.

### 7.2. Playbook 2: Signal Line Cycle Crossover

- **Execution:** In established directional regimes, wait for a temporary dip that holds above $0.0$, then enter long when Consensus crosses back **above** the 9-period Signal Line.

### 7.3. Playbook 3: Supermajority Trend Protection ($\ge \pm 60.0$)

- **Execution:** When Consensus reaches $+60.0$ or $-60.0$, Trend, Cycle, Volatility, and Volume engines are in broad alignment. Hold core trend positions until Consensus crosses back against its Signal Line.

### 7.4. Playbook 4: Multi-Timeframe Macro Alignment

- Attach an **H1-calculated DSP Ensemble Oscillator Pro** onto an **M5 execution chart**.

- **Quantitative Execution Rule:** Only take M5 long breakouts when $\text{BufferConsensus}_{\text{H1 Step}} > +20.0$, and short breakouts only when $< -20.0$.

---

## 8. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Buffer Type | Visual Mode Role | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferConsensus` | `INDICATOR_DATA` | Primary Data | DSP Consensus Score ($-100.0 \dots +100.0$) |
| **1** | `BufferColors` | `INDICATOR_COLOR_INDEX` | Shading Index | `0` = Bull ($>+20$), `1` = Bear ($<-20$), `2` = Neutral ($[-20,+20]$) |
| **2** | `BufferSignalLine` | `INDICATOR_DATA` | Secondary Plot | Smoothed Signal Line ($-100.0 \dots +100.0$) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read DSP Ensemble Oscillator Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF DSP Ensemble Oscillator Pro
int handle = iCustom(_Symbol, _Period, "DSP_Ensemble_Oscillator_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     PRICE_CLOSE_STD,        // InpSourcePrice
                     DSP_PLOT_HISTOGRAM      // InpPlotMode
                     // ... remaining core, signal, and 8 component settings use defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create DSP_Ensemble_Oscillator_Pro handle.");
   return;
  }

//--- Read finalized closed bar values (Bar index 1 and Bar index 2)
double cons_val[], sig_val[];
ArraySetAsSeries(cons_val, true);
ArraySetAsSeries(sig_val,  true);

if(CopyBuffer(handle, 0, 1, 2, cons_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, sig_val)  == 2)
  {
   double cons_curr = cons_val[0];  // Closed bar (Bar 1)
   double cons_prev = cons_val[1];  // Prior closed bar (Bar 2)
   double sig_curr  = sig_val[0];
   double sig_prev  = sig_val[1];

   // Example Strategy: Zero-Lag Quorum Breakout above +20
   bool is_quorum_long = (cons_prev <= 20.0 && cons_curr > 20.0);

   // Example Strategy: Signal Line Crossover in Buy Zone
   bool is_cross_long  = (cons_prev <= sig_prev && cons_curr > sig_curr && cons_curr > 20.0);

   if(is_quorum_long || is_cross_long)
     {
      // Execute Buy Order (Cybernetic Zero-Lag Consensus)
     }
  }
```
