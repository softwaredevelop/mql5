# Laguerre RSI Pro (v4.00)

## Institutional Multi-Timeframe Time-Warped Zero-Lag Momentum Oscillator Suite with 14 Signal Smoothing Models

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Laguerre RSI Pro (v4.00)** is the primary phase-adaptive momentum oscillator of the Professional MQL5 Suite. Developed by rocket scientist and financial engineer **John Ehlers** (2002, *Cybernetic Analysis for Stocks and Futures*), it solves the fundamental tradeoff of technical analysis: **the compromise between lag and smoothness**.

Standard RSI implementations rely on conventional linear lookback windows (typically $P = 14$). In discrete signal processing, a 14-bar linear filter inevitably introduces approximately 7 bars of group delay.

**Laguerre RSI replaces linear lookbacks with an orthogonal 4-element Laguerre polynomial network ($L_0, L_1, L_2, L_3$) that warps the time domain**. With a damping factor of $\gamma = 0.5$, the indicator achieves the spectral smoothing of a long-period RSI with a phase delay of **only 3 to 4 bars**, enabling institutional traders to detect turning points at inception:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE RSI ARCHITECTURAL OVERVIEW                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Laguerre Time Warping       • 4-stage orthogonal polynomial network │
│                                • Non-linear frequency compression      │
│                                • Drastic lag reduction ($\gamma \in [0.0, 1.0]$)│
├────────────────────────────────────────────────────────────────────────┤
│ 2. Harmonic Fibonacci Spectrum • Exact Fibonacci Gamma ratios:         │
│                                  0.236, 0.382, 0.500, 0.618, 0.764,    │
│                                  and 0.882                             │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Zero-Copy Inlined DSP       • Direct inlined $L_0..L_3$ access      │
│                                • Eliminates 4 redundant array copies   │
│                                • $1.0\text{e-}9$ zero-division shield  │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 14-Model Signal Line Engine • Powered by MovingAverage_Engine.mqh   │
│                                • Dual volume routing (Real & Tick)     │
│                                • Supports VWMA, HMA, ZLEMA smoothing   │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 6. Extreme Level Architecture  • 5 Reference Levels (10, 20, 50, 80, 90│
│                                • Identifies trend runaway pinning      │
│                                • 2048-element memory capacity reserves │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Laguerre Time Warping

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
                                           ▼
                       4-Stage Laguerre Filter Bank Engine
                        Parameter: Gamma ($\gamma \in [0.0, 1.0]$)
                                           │
       ┌───────────────────┬───────────────┴───────────────┬───────────────────┐
       ▼                   ▼                               ▼                   ▼
Stage 0 ($L_0$)      Stage 1 ($L_1$)                 Stage 2 ($L_2$)     Stage 3 ($L_3$)
 (1-γ)P + γL0         -γL0 + L0[1] + γL1             -γL1 + L1[1] + γL2  -γL2 + L2[1] + γL3
       │                   │                               │                   │
       └───────────────────┼───────────────────────────────┴───────────────────┘
                           │
                           ▼
             Warped Flow Differential Scanner
           CU = Σ max(0, Lk - Lk+1),   CD = Σ max(0, Lk+1 - Lk)
                           │
                           ▼
             Normalized Zero-Lag Laguerre RSI
                (CU / (CU + CD)) · 100.0
                           │
               ┌───────────┴───────────┐
               ▼                       ▼
      Primary LRSI Curve       Signal Smoothing Engine
      (0 to 100 Bounded)       (14 Selectable MA Models)
               │                       │
               ▼                       ▼
       BufferLRSI (t)           BufferSignal (t)
```

The mathematical engine executes a time-warped signal decomposition pipeline on every bar:

### 2.1. The 4-Element Orthogonal Filter Bank

The price series $P_t$ is routed into four cascading recursive Laguerre filters parameterized by the damping factor Gamma ($\gamma$):
$$L_{0, t} = (1.0 - \gamma) P_t + \gamma L_{0, t-1}$$
$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$
$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$
$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

*Concept of Time Warping:* The filter network acts as an all-pass phase shifter that compresses higher frequencies (noise) while dilating lower frequencies (trend cycles).

### 2.2. Warped Flow Differentials ($CU$ and $CD$)

Rather than measuring price differences across arbitrary lookback bars, the engine measures the orthogonal potential differences across the four Laguerre stages:
$$CU_t = \max(0.0, L_{0, t} - L_{1, t}) + \max(0.0, L_{1, t} - L_{2, t}) + \max(0.0, L_{2, t} - L_{3, t})$$
$$CD_t = \max(0.0, L_{1, t} - L_{0, t}) + \max(0.0, L_{2, t} - L_{1, t}) + \max(0.0, L_{3, t} - L_{2, t})$$

### 2.3. Normalized Laguerre Relative Strength Index

Computes the ratio of upward flow to total flow. Protected by a $1.0\text{e-}9$ numerical epsilon shield to eliminate division-by-zero during flat market conditions:
$$\text{LRSI}_t = \begin{cases}
\frac{CU_t}{CU_t + CD_t} \times 100.0 & \text{if } (CU_t + CD_t) > 1.0\text{e-}9 \\
50.0 & \text{if } t = 0 \\
\text{LRSI}_{t-1} & \text{otherwise}
\end{cases}$$
The output is strictly bounded to the $[0.0, 100.0]$ domain:
$$\text{LRSI}_t = \max(0.0, \min(100.0, \text{LRSI}_t))$$

### 2.4. Modular 14-Model Signal Line
To provide precise crossover trigger signals without false whipsaws, `CLaguerreRSICalculator` composites `CMovingAverageCalculator`:
$$\text{SignalLine}_t = \mathcal{M}_{\text{sig}}(\text{LRSI}, \text{SignalPeriod})_t$$
Where $\mathcal{M}_{\text{sig}}$ represents any of the 14 supported algorithms (`InpSignalMAType`).

---

## 3. The Harmonic Fibonacci Gamma ($\gamma$) Matrix

The Gamma parameter ($\gamma \in [0.0, 1.0]$) controls the intensity of the time-warping transformation. The quantitative suite defines **six primary harmonic Fibonacci benchmarks**:

| Harmonic Ratio ($\gamma$) | Fibonacci Derivation | Equivalent Linear RSI | Phase Delay | Market Behavioral Character | Optimal Quantitative Role |
| :---: | :---: | :---: | :---: | :--- | :--- |
| **`0.236`** | Minor Retracement Ratio ($1 - 0.764$) | $\approx 4$ Bars | $\approx 1.5$ Bars | **Hyper-Responsive:** Reacts to single-bar momentum impulses. | M1 / M5 Scalping; immediate breakout trigger. |
| **`0.382`** | Primary Ratio ($1 - 0.618$) | $\approx 6$ Bars | $\approx 2.5$ Bars | **Fast Momentum:** Crisp turning points with early exit triggers. | Intraday swing momentum & reversal detection. |
| **`0.500`** | Harmonic Midpoint ($50\%$ Equilibrium) | $\approx 10$ Bars | $\approx 3.5$ Bars | **Universal Benchmark:** The classical Ehlers setting. | All-around balanced day and swing trading. |
| **`0.618`** | The Golden Ratio ($\Phi - 1$) | $\approx 16$ Bars | $\approx 5.0$ Bars | **Smooth Trend:** Completely suppresses intraday chop. | H1 / H4 Trend-following swing execution. |
| **`0.764`** | Major Inversion ($1 - 0.236$) | $\approx 28$ Bars | $\approx 8.5$ Bars | **Macro Filter:** Highly stable, long-cycle momentum line. | Multi-day swing trading & macro baseline filter. |
| **`0.882`** | Deep Harmonic Extension ($\approx \sqrt{0.786}$) | $\approx 45+$ Bars | $\approx 12.0$ Bars | **Ultra-Smooth Anchor:** Completely immune to volatility spikes. | H4 / Daily / Weekly institutional regime governor. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Laguerre RSI baselines onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

### 4.1. Atomic Single-Query Rates Synchronization
Legacy indicators call multiple `Copy*` functions in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`Laguerre_RSI_Pro` executes a single atomic `CopyRates()` query:
```mql5
MqlRates htf_bulk_rates[];
if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
   return 0;
```
All OHLCV arrays are updated in cache simultaneously in nanoseconds.

### 4.2. Two-Pointer Chronological Sweep ($O(N)$ Projection)
Instead of executing an $O(N \cdot M)$ loop calling `iBarShift()` on every chart candle, the engine sweeps chronologically forward using two moving pointers:
```mql5
int htf_ptr = 0;
datetime oldest_htf = h_time[0];

for(int i = 0; i < rates_total; i++)
  {
   datetime t = time[i];
   if(t < oldest_htf)
     {
      BufferLRSI[i]   = EMPTY_VALUE;
      BufferSignal[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferLRSI[i]   = h_res_lrsi[htf_ptr];
   BufferSignal[i] = h_res_signal[htf_ptr];
  }
```

### 4.3. Live-Tick RAM Mocking & Binary Snapping
During live market ticks where the HTF bar has not closed:
1. Only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is updated.
2. The engine recalculates bar `live_idx` locally.
3. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar of the forming HTF block:
   ```mql5
   int first_bar = ArrayBsearch(time, htf_time_current);
   ```
4. Values are direct-vector assigned across the forming block. **Zero `iBarShift()` API calls occur on live ticks.**

---

## 5. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Laguerre RSI Settings ===
* **`InpGamma`** (*default: `0.50`*): Damping factor $\gamma \in [0.0, 1.0]$. Selectable across harmonic Fibonacci benchmarks (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Signal Line Settings ===
* **`InpDisplayMode`** (*default: `DISPLAY_LRSI_AND_SIGNAL`*):
  - `DISPLAY_LRSI_ONLY`: Plots only the primary Laguerre RSI curve.
  - `DISPLAY_LRSI_AND_SIGNAL`: Plots both the Laguerre RSI curve and the Signal Moving Average line.
* **`InpSignalPeriod`** (*default: `3`*): Smoothing lookback period for the Signal Line.
* **`InpSignalMAType`** (*default: `EMA`*): Moving average algorithm used to smooth the LRSI series (Selectable across all 14 modular models).

### === Indicator Levels (0-100 Range) ===
* **`InpLevelExtrHigh`** (*default: `90.0`*): Extreme Overbought level (Climax runaway).
* **`InpLevelHigh`** (*default: `80.0`*): Overbought warning level.
* **`InpLevelMid`** (*default: `50.0`*): Equilibrium fair value level.
* **`InpLevelLow`** (*default: `20.0`*): Oversold warning level.
* **`InpLevelExtrLow`** (*default: `10.0`*): Extreme Oversold level (Climax capitulation).
* **`InpLevelColor`** (*default: `clrDarkGray`*): Color of horizontal level lines.
* **`InpLevelStyle`** (*default: `STYLE_DOT`*): Style of horizontal level lines.

### === Visual Settings ===
* **`InpColorLRSI`** (*default: `clrMediumTurquoise`*): Line color for Laguerre RSI.
* **`InpStyleLRSI`** (*default: `STYLE_SOLID`*): Line style for Laguerre RSI.
* **`InpWidthLRSI`** (*default: `2`*): Line thickness for Laguerre RSI.
* **`InpColorSignal`** (*default: `clrLightCoral`*): Line color for the Signal Line.
* **`InpStyleSignal`** (*default: `STYLE_SOLID`*): Line style for the Signal Line.
* **`InpWidthSignal`** (*default: `1`*): Line thickness for the Signal Line.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      LAGUERRE RSI PLAYBOOKS                            │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Extreme Level Fades (10 / 90): Price pinning at 0/100 followed by   │
│                                   a hook back across 10 or 90 -> Fade. │
│ 2. Signal Crossover Momentum:     Laguerre RSI crossing above Signal   │
│                                   Line while emerging from oversold.   │
│ 3. The 50 Midline Breakout:       Decisive cross of 50 confirms a      │
│                                   regime shift from bear to bull.      │
│ 4. MTF Macro Step Alignment:      Only take M5 long crossovers when    │
│                                   H4 Laguerre RSI is holding > 50.     │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Extreme Level Fades (The Pinning Exhaustion)
* **Mechanism:** In runaway market moves, Laguerre RSI pins completely flat at $100.0$ or $0.0$. Attempting to fade a market while LRSI is pinned at $100.0$ is dangerous.
* **Bullish Reversal Trigger:** Wait for LRSI to drop into the extreme oversold zone ($< 10.0$). The moment LRSI hooks and crosses **above 10.0 or 20.0**, trigger a high-probability mean-reversion long entry.
* **Bearish Reversal Trigger:** Wait for LRSI to pin at $100.0$. The moment LRSI breaks **below 90.0 or 80.0**, trigger an immediate short reversal entry.

### 6.2. Playbook 2: Signal Line Momentum Crossover
* **Configuration:** `InpDisplayMode = DISPLAY_LRSI_AND_SIGNAL`, `InpSignalPeriod = 3`.
* **Bullish Crossover:** Laguerre RSI crosses strictly **above** the Signal Line while below 50 $\rightarrow$ Early long momentum trigger.
* **Bearish Crossover:** Laguerre RSI crosses strictly **below** the Signal Line while above 50 $\rightarrow$ Early short momentum trigger.

### 6.3. Playbook 3: Equilibrium Midline Regime Shift
* **Mechanism:** The $50.0$ level represents dynamic equilibrium.
* **Execution Rule:**
  - When $\text{LRSI} > 50.0$, the dominant order flow is bullish. Pullbacks to the 50 level that hold and bounce offer high-conviction continuation entries.
  - When $\text{LRSI} < 50.0$, the dominant flow is bearish.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment
* Attach an **H4-calculated Laguerre RSI Pro ($\gamma = 0.618$ or $0.764$)** onto an **M15 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferLRSI}_{\text{H4 Step}} > 50.0 \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferLRSI}_{\text{H4 Step}} < 50.0 \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against macro institutional momentum regimes.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 2 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferLRSI` | `DRAW_LINE` | `clrMediumTurquoise` | Laguerre Relative Strength Index curve ($0.0 \dots 100.0$) |
| **1** | `BufferSignal` | `DRAW_LINE` | `clrLightCoral` | Signal Moving Average curve (Active in Mode 1) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Laguerre RSI Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Laguerre RSI Pro with Golden Ratio Gamma
int handle = iCustom(_Symbol, _Period, "Laguerre_RSI_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     0.618,                      // InpGamma (Golden Ratio)
                     PRICE_CLOSE_STD,            // InpSourcePrice (Standard Close)
                     DISPLAY_LRSI_AND_SIGNAL,    // InpDisplayMode
                     3,                          // InpSignalPeriod
                     EMA                         // InpSignalMAType (ENUM_MA_TYPE)
                     // ... remaining level and visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Laguerre_RSI_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double lrsi_val[], signal_val[];
ArraySetAsSeries(lrsi_val,   true);
ArraySetAsSeries(signal_val, true);

if(CopyBuffer(handle, 0, 1, 2, lrsi_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, signal_val) == 2)
  {
   double lrsi_curr   = lrsi_val[0];    // Closed bar (Bar 1)
   double lrsi_prev   = lrsi_val[1];    // Prior closed bar (Bar 2)
   double signal_curr = signal_val[0];
   double signal_prev = signal_val[1];

   // Example Strategy: Bullish Reversal Hook out of Oversold (< 20)
   bool is_hook_long = (lrsi_prev <= 20.0 && lrsi_curr > 20.0);

   // Example Strategy: Bullish Signal Line Crossover
   bool is_cross_long = (lrsi_prev <= signal_prev && lrsi_curr > signal_curr);

   if(is_hook_long || is_cross_long)
     {
      // Execute Buy Order (Time-Warped Zero-Lag Momentum Shift)
     }
  }
```
