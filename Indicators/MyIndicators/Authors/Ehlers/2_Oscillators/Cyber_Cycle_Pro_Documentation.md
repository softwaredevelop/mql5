# Cyber Cycle Pro (v4.10)

## Institutional Multi-Timeframe Resonant 2-Pole Cycle Oscillator Suite with Harmonic Fibonacci Alpha Tuning & 14 Signal Smoothing Models

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Cyber Cycle Pro (v4.10)** is the primary rhythmic cycle extraction oscillator of the Professional MQL5 Suite. Developed by rocket scientist and financial engineer **John Ehlers** (2004, *Cybernetic Analysis for Stocks and Futures*), it solves the fundamental flaw of classical momentum oscillators: **spectral pollution from the low-frequency DC trend component**.

Standard oscillators (RSI, Stochastic, CCI) combine trend momentum and cycle oscillations into a single unseparated wave. During sustained trend runs, these oscillators saturate into extreme overbought or oversold zones, generating devastating false reversal signals.

**Cyber Cycle acts as an analog second-order resonant bandpass/highpass filter that strips out the DC trend component, isolating the pure, stationary rhythm of the market cycle**. By pairing the extracted cycle curve with a phase-shifted trigger line, institutional traders can identify market turning points exactly at cycle crests and troughs:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   CYBER CYCLE ARCHITECTURAL OVERVIEW                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 4-Bar FIR Pre-Smoother      • Symmetric triangular FIR filter       │
│                                • Eliminates high-frequency white noise │
│                                • Pipelined reciprocal multiplication   │
├────────────────────────────────────────────────────────────────────────┤
│ 2. 2-Pole Resonant IIR Filter  • Second-order difference equation      │
│                                • Strips low-frequency DC trend drift   │
│                                • Precomputed analytical DSP matrix     │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Harmonic Fibonacci Spectrum • 3-digit decimal-shifted Fibo alphas:  │
│                                  0.024, 0.038, 0.050, 0.062, 0.076,    │
│                                  and 0.088                             │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Dual Signal Trigger Engine  • Mode A: Classical 1-Bar Delayed Cycle│
│                                • Mode B: 14-Model Moving Average Engine│
│                                • Clean CalculateOnArray delegation     │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 6. Sub-Pip Scaling Precision   • High-resolution floating point digits │
│                                • Configured to _Digits + 2             │
│                                • 2048-element memory capacity reserves │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Resonant Filter Derivations

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
                                           ▼
                      4-Bar Symmetrical FIR Pre-Smoothing
                     (P[t] + 2·P[t-1] + 2·P[t-2] + P[t-3]) / 6
                                           │
                                           ▼
                       Precomputed Analytical DSP Matrix
                       c_smooth = (1 - 0.5α)²,  c1 = 2(1 - α),  c2 = (1 - α)²
                                           │
                                           ▼
                       2-Pole Resonant Difference Equation
                     c_smooth·Δ²Smooth + c1·Cycle[t-1] - c2·Cycle[t-2]
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
      Mode A: 1-Bar Delay Trigger                             Mode B: 14-Model MA Signal
            Cycle[t-1]                                         (EMA, HMA, VWMA, SMA...)
               │                                                       │
               └───────────────────────────┬───────────────────────────┘
                                           │
                                           ▼
                             Dual-Curve Oscillator Output
```

The mathematical engine executes a 3-stage digital filter transfer function parameterized by the smoothing factor Alpha ($\alpha \in [0.01, 0.20]$):

### 2.1. Stage 1: 4-Bar Symmetrical FIR Pre-Smoothing

Raw price $P_t$ is filtered using a symmetrical finite impulse response kernel to strip out single-bar tick noise:
$$\text{Smooth}_t = (P_t + 2.0 P_{t-1} + 2.0 P_{t-2} + P_{t-3}) \times 0.1666666666666667$$

### 2.2. Stage 2: Precomputed Analytical Filter Coefficients

To guarantee nanosecond execution, all polynomial coefficient powers are precomputed strictly once during initialization:
$$c_{\text{smooth}} = (1.0 - 0.5 \alpha)^2$$
$$c_1 = 2.0 (1.0 - \alpha)$$
$$c_2 = (1.0 - \alpha)^2$$

### 2.3. Stage 3: Second-Order Resonant Difference Equation

The detrended second difference of the smoothed price ($\Delta^2 \text{Smooth}_t = \text{Smooth}_t - 2\text{Smooth}_{t-1} + \text{Smooth}_{t-2}$) is injected into the 2-pole recursive feedback loop:
$$\text{Cycle}_t = c_{\text{smooth}} (\text{Smooth}_t - 2.0 \text{Smooth}_{t-1} + \text{Smooth}_{t-2}) + c_1 \text{Cycle}_{t-1} - c_2 \text{Cycle}_{t-2}$$

*Deterministic Seeding:* For bars $t = 0 \dots 5$, the cycle registers are seeded to zero, ensuring exact state convergence by bar 6.

### 2.4. Stage 4: Trigger / Signal Line Generation

The indicator supports two operational trigger modes:

- **Mode A: Classical 1-Bar Delay (`SIGNAL_DELAY_1BAR`):**
  $$\text{Trigger}_t = \text{Cycle}_{t-1}$$
  *Phase Shift Advantage:* Because the extracted cycle approximates a continuous sine wave, delaying the series by 1 bar creates an ideal quadrature phase shift. Crossovers between $\text{Cycle}_t$ and $\text{Trigger}_t$ occur **precisely at the inflection peaks and valleys of the cycle wave**.
- **Mode B: Modular Moving Average (`SIGNAL_MA`):**
  $$\text{Trigger}_t = \mathcal{M}_{\text{sig}}(\text{Cycle}, \text{SignalPeriod})_t$$
  Where $\mathcal{M}_{\text{sig}}$ represents any of the 14 supported algorithms (`InpSignalMethod`), executed directly via `CalculateOnArray()`.

---

## 3. The Harmonic Fibonacci Alpha ($\alpha$) Matrix

In John Ehlers' 2-pole resonant filter, the smoothing factor $\alpha$ is mathematically related to the cycle period length $P$ by:
$$P \approx \frac{2}{\alpha} - 1$$

By dividing the natural Fibonacci and harmonic ratios by 10 (shifting one decimal place), **the Alpha parameter maps directly to the classical Fibonacci cycle periods ($21, 34, 55, 89$)**:

| Decimal-Shifted Fibo Alpha ($\alpha$) | Fibonacci Mathematical Derivation | Resulting Cycle Length ($P$) | Canonical Fibonacci Period | Market Behavioral Character | Optimal Quantitative Role |
| :---: | :---: | :---: | :---: | :--- | :--- |
| **`0.024`** | $0.236 \times 0.1$ | **$\approx 82$ Bars** | $\approx \mathbf{89}$ | **Macro Regime Cycle:** Filters all intraday swings; tracks dominant multi-week trend rhythms. | H4 / Daily macro cycle filter. |
| **`0.038`** | $0.382 \times 0.1$ | **$\approx 51$ Bars** | $\approx \mathbf{55}$ | **Slow Swing Cycle:** Captures major multi-day market turning points. | H1 / H4 Swing cycle trading. |
| **`0.050`** | $0.500 \times 0.1$ | **$\approx 39$ Bars** | Harmonic Intermediate | **Harmonic Intermediate:** Noise-immune medium cycle extractor. | H1 Trend continuation cycles. |
| **`0.062`** | $0.618 \times 0.1$ (Golden Ratio) | **$\approx 31$ Bars** | $\approx \mathbf{34}$ | **The Golden Ratio Alpha:** Ehlers' classic 0.07 setting corresponds directly to this 34-bar harmonic wave! | Universal benchmark setting (M15 / H1). |
| **`0.076`** | $0.764 \times 0.1$ | **$\approx 25$ Bars** | $\approx \mathbf{21}$ | **Fast-Intermediate Cycle:** Balanced response for active intraday momentum swings. | M5 / M15 Intraday trading. |
| **`0.088`** | $0.882 \times 0.1$ | **$\approx 21$ Bars** | $\approx \mathbf{21}$ | **Fast Micro-Cycle:** Rapid reaction to short-term cyclical turning points. | M1 / M5 Scalping. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Cyber Cycles onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

`Cyber_Cycle_Pro` executes a single atomic `CopyRates()` query:

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
      BufferCycle[i]  = EMPTY_VALUE;
      BufferSignal[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferCycle[i]  = h_res_cycle[htf_ptr];
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

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Cyber Cycle Settings ===

- **`InpAlpha`** (*default: `0.062`*): Filter smoothing factor $\alpha$ with 3-digit precision. Selectable across harmonic Fibonacci benchmarks (`0.024`, `0.038`, `0.050`, `0.062`, `0.076`, `0.088`).

- **`InpSourcePrice`** (*default: `PRICE_MEDIAN_STD`*): Input price source. Defaults to Ehlers' recommended Median Price (`(H+L)/2`), with full support for all 7 standard and 7 synthetic Heikin Ashi price modes.

### === Signal Line Settings ===

- **`InpSignalType`** (*default: `SIGNAL_DELAY_1BAR`*):
  - `SIGNAL_DELAY_1BAR`: Classical Ehlers phase trigger ($\text{Cycle}_{t-1}$).
  - `SIGNAL_MA`: Custom moving average smoothing applied to the cycle curve.

- **`InpSignalPeriod`** (*default: `3`*): Smoothing lookback window (active only when `InpSignalType = SIGNAL_MA`).
- **`InpSignalMethod`** (*default: `SMA`*): Moving average algorithm used to smooth the Signal Line (Selectable across all 14 modular models, including VWMA and HMA).

### === Visual Settings ===

- **`InpColorCycle`** (*default: `clrDodgerBlue`*): Line color for the Cyber Cycle curve.

- **`InpStyleCycle`** (*default: `STYLE_SOLID`*): Line style for the Cyber Cycle curve.
- **`InpWidthCycle`** (*default: `2`*): Line thickness for the Cyber Cycle curve.
- **`InpColorSignal`** (*default: `clrOrangeRed`*): Line color for the Signal / Trigger line.
- **`InpStyleSignal`** (*default: `STYLE_SOLID`*): Line style for the Signal / Trigger line.
- **`InpWidthSignal`** (*default: `1`*): Line thickness for the Signal / Trigger line.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        CYBER CYCLE PLAYBOOKS                           │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Classical Trigger Crossover: Cycle crossing above Trigger at a      │
│                                 cycle trough triggers an early long.   │
│ 2. Zero-Line Polar Inflection:  Cycle crossing zero confirms directional│
│                                 momentum regime expansion.             │
│ 3. Cycle Amplitude Exhaustion:  Extreme cycle peaks followed by curve  │
│                                 rounding signal imminent exhaustion.   │
│ 4. MTF Macro Step Alignment:    Only take M5 long crossovers when the  │
│                                 H4 Cyber Cycle is rising above zero.   │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Classical Cycle Trigger Crossover

- **Configuration:** `InpSignalType = SIGNAL_DELAY_1BAR`, `InpAlpha = 0.062`.

- **Mechanism:** When the market cycles, $\text{Cycle}$ leads while $\text{Trigger}$ trails.
- **Bullish Crossover:** $\text{Cycle}$ crosses strictly **above** $\text{Trigger}$ while below the zero line $\rightarrow$ High-conviction long entry at the cycle trough.
- **Bearish Crossover:** $\text{Cycle}$ crosses strictly **below** $\text{Trigger}$ while above the zero line $\rightarrow$ High-conviction short entry at the cycle crest.

### 6.2. Playbook 2: Zero-Line Polar Momentum Inflection

- **Mechanism:** The zero level ($0.0$) represents the dynamic equilibrium center of the detrended price wave.

- **Execution Rule:**
  - When $\text{Cycle} > 0.0$, the market is in the bullish expansion phase of the cycle.
  - When $\text{Cycle} < 0.0$, the market is in the bearish contraction phase of the cycle.
  - Crossovers of zero confirm strong directional follow-through.

### 6.3. Playbook 3: Cycle-Trend Decoupling (Trend Runaway Mode)

- **Market State:** Parabolic trend breakout.

- **Observation:** In runaway trends, the Cyber Cycle will cross above and below the trigger line rapidly without price retracing significantly, while its amplitude expands.
- **Filter:** When combined with `MAMA_Pro` or `SuperSmoother_Pro`, trade cycle crossovers **strictly in the direction of the macro smoother**.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

- Attach an **H4-calculated Cyber Cycle Pro ($\alpha = 0.062$)** onto an **M15 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{BufferCycle}_{\text{H4 Step}} > 0.0 \land \text{BufferCycle}_{\text{H4 Step}} > \text{BufferSignal}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferCycle}_{\text{H4 Step}} < 0.0 \land \text{BufferCycle}_{\text{H4 Step}} < \text{BufferSignal}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
- Eliminates counter-trend scalping against higher-timeframe institutional market cycles.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 2 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferCycle` | `DRAW_LINE` | `clrDodgerBlue` | Primary Resonant Cyber Cycle curve |
| **1** | `BufferSignal` | `DRAW_LINE` | `clrOrangeRed` | Signal / Trigger curve (1-Bar Delay or MA) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Cyber Cycle Pro values with Golden Ratio Alpha ($0.062$) from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Cyber Cycle Pro with Golden Ratio Alpha
int handle = iCustom(_Symbol, _Period, "Cyber_Cycle_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     0.062,                  // InpAlpha (Golden Ratio Fibo Alpha)
                     PRICE_MEDIAN_STD,       // InpSourcePrice (Median Price)
                     SIGNAL_DELAY_1BAR,      // InpSignalType (1-Bar Delay)
                     3,                      // InpSignalPeriod
                     SMA                     // InpSignalMethod
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Cyber_Cycle_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double cycle_val[], signal_val[];
ArraySetAsSeries(cycle_val,  true);
ArraySetAsSeries(signal_val, true);

if(CopyBuffer(handle, 0, 1, 2, cycle_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, signal_val) == 2)
  {
   double cycle_curr  = cycle_val[0];     // Closed bar (Bar 1)
   double cycle_prev  = cycle_val[1];     // Prior closed bar (Bar 2)
   double signal_curr = signal_val[0];
   double signal_prev = signal_val[1];

   // Example Strategy: Bullish Cycle Trough Crossover below Zero
   bool is_trough_cross = (cycle_prev <= signal_prev && cycle_curr > signal_curr && cycle_curr < 0.0);

   if(is_trough_cross)
     {
      // Execute Buy Order (Resonant Cycle Trough Turn)
     }
  }
```
