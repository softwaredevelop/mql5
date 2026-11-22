# Ehlers Smoother Pro (v4.00)

## Institutional Multi-Timeframe SuperSmoother & UltimateSmoother 2-Pole Low-Pass DSP Filter Suite

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Ehlers Smoother Pro (v4.00)** is the primary low-pass digital signal processing (DSP) trend filter of the Professional MQL5 Suite. Engineered from John Ehlers’ advanced cycle research (2013, *Cycle Analytics for Traders*), the suite synthesizes two distinct mathematical filters: the critically damped 2-pole **SuperSmoother** and the zero-lag lead-injected **UltimateSmoother**.

Conventional moving averages (SMA, EMA, LWMA) suffer from terrible frequency response: they provide sluggish phase lag while failing to reject high-frequency market ripples.

**Ehlers Smoother Pro applies true 2-pole Butterworth digital filter transfer functions that achieve a steep $-12 \text{ dB/octave}$ noise attenuation cutoff, completely suppressing market chop while retaining ultra-low or zero phase delay**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                  EHLERS SMOOTHER ARCHITECTURAL OVERVIEW                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. SuperSmoother Filter Engine • Critically damped 2-pole IIR filter   │
│                                • Optimal $-12\text{ dB/octave}$ spectral rolloff│
│                                • Eliminates high-frequency market noise│
├────────────────────────────────────────────────────────────────────────┤
│ 2. UltimateSmoother Engine     • Zero-lag lead-term feedforward injection│
│                                • Cancels 100% of 2-pole recursive lag  │
│                                • Immediate reaction to market turns    │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Precomputed DSP Matrix      • Trigonometric ($e^{-\omega}, \cos\omega$) constants   │
│                                  computed strictly once in Init()      │
│                                • Hardware-pipelined FMA live calculation│
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Engine   • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Dual Operational Sources    • Price smoothing vs. Momentum filtering│
│                                • Synthetic Heikin Ashi price routing   │
│                                • 2048-element memory capacity reserves │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Analytical DSP Derivations

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
                                           ▼
                            Source Mode Selector (Price / Momentum)
                                           │
                                           ▼
                        Precomputed Analytical DSP Matrix (Init)
                       Cutoff: ω = √2·π / Period  -> a1, b1, c1, c2, c3
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Model A: SuperSmoother Filter                               Model B: UltimateSmoother Filter
  2-Pole Critical Damping                                     Zero-Lag Lead Injected
(c1_half · (P[t] + P[t-1]) + c2·F[t-1] + c3·F[t-2])          (u0·P[t] + u1·P[t-1] + u2·P[t-2] + c2·F[t-1] + c3·F[t-2])
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │
                                           ▼
                             Smooth Trendline Buffer (t)
```

The mathematical engine executes an analytical digital filter transfer function parameterized by the lookback cutoff period $P$ (`InpPeriod`):

### 2.1. Analytical Filter Coefficients (Precomputed in `Init`)

To ensure nanosecond live-tick execution, all exponential and trigonometric functions are hoisted out of the calculation loops and evaluated strictly once during initialization:

1. **Angular Cutoff Frequency ($\omega$):**
   $$\omega = \frac{\sqrt{2} \pi}{P} = \frac{1.41421356 \times \pi}{P}$$
2. **Damping Decay Factor ($a_1$) & Frequency Base ($b_1$):**
   $$a_1 = e^{-\omega} = \exp(-\omega)$$
   $$b_1 = 2.0 a_1 \cos(\omega)$$
3. **Recursive Feedback Coefficients ($c_2, c_3$):**
   $$c_2 = b_1$$
   $$c_3 = -a_1^2 = -(a_1 \times a_1)$$

---

### 2.2. Model A: The 2-Pole SuperSmoother Filter

The SuperSmoother is a 2-pole critically damped Infinite Impulse Response (IIR) filter. It completely eliminates cycle noise with periods shorter than $P$:
$$c_1 = 1.0 - c_2 - c_3$$
$$c_{1, \text{half}} = 0.5 \times c_1$$

The real-time difference equation executes via hardware-friendly Fused Multiply-Add (FMA) arithmetic:
$$\text{SuperSmoother}_t = c_{1, \text{half}} (P_t + P_{t-1}) + c_2 \text{Filter}_{t-1} + c_3 \text{Filter}_{t-2}$$

*Characteristics:* Provides the smoothest possible curve without overshoot. Ideal as a baseline moving average replacement.

---

### 2.3. Model B: The Zero-Lag UltimateSmoother Filter

John Ehlers engineered the UltimateSmoother to eliminate the remaining phase lag of the 2-pole filter by adding feedforward lead terms from the input price series:
$$c_1 = \frac{1.0 + c_2 - c_3}{4.0} = (1.0 + c_2 - c_3) \times 0.25$$
$$u_0 = 1.0 - c_1$$
$$u_1 = 2.0 c_1 - c_2$$
$$u_2 = -(c_1 + c_3)$$

The difference equation incorporates a 3-tap input feedforward FIR structure combined with 2-pole recursive feedback:
$$\text{UltimateSmoother}_t = u_0 P_t + u_1 P_{t-1} + u_2 P_{t-2} + c_2 \text{Filter}_{t-1} + c_3 \text{Filter}_{t-2}$$

*Characteristics:* Completely removes the delay of the 2-pole smoother. The curve hugs turning points with true zero lag while still rejecting high-frequency market ripples.

---

### 2.4. DSP Filter Performance Matrix

| Metric / Property | Classical SMA (20) | Classical EMA (20) | Ehlers SuperSmoother (20) | Ehlers UltimateSmoother (20) |
| :--- | :---: | :---: | :---: | :---: |
| **Filter Order** | 1-Pole (FIR) | 1-Pole (IIR) | **2-Pole Critical (IIR)** | **2-Pole Lead-Injected** |
| **Phase Lag** | $9.5$ Bars | $9.5$ Bars | **$\approx 3.0$ Bars** | **$\approx 0.0$ Bars (Zero-Lag)** |
| **Stopband Attenuation** | Poor ($-6\text{ dB}$) | Poor ($-6\text{ dB}$) | **Exceptional ($-12\text{ dB/oct}$)** | **Exceptional ($-12\text{ dB/oct}$)** |
| **Overshoot Tendency** | None | Low | **Zero (Critically Damped)** | Minor (Lead Impulse) |
| **Noise Immunity** | Moderate | Poor | **Ultra-High** | **High** |

---

## 3. Dual Input Source & Synthetic Heikin Ashi

The calculator supports two distinct operational input modes:

1. **`SOURCE_PRICE` (Default):**
   Smooths the asset's price directly. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`InpSourcePrice`).
   $$\text{PRICE\_TYPICAL} = (\text{High} + \text{Low} + \text{Close}) \times 0.3333333333333333$$
2. **`SOURCE_MOMENTUM`:**
   Smooths the candle's internal directional velocity vector:
   $$\Delta_{\text{candle}, t} = \text{Close}_t - \text{Open}_t$$
   Filtering momentum through the SuperSmoother transforms choppy price changes into a clean, zero-lag directional flow oscillator.

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Ehlers Smoothers onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

```text
  HTF Domain (e.g. H4)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M15)
  [m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

### 4.1. Atomic Single-Query Rates Synchronization

Legacy indicators call multiple `Copy*` functions in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`Ehlers_Smoother_Pro` executes a single atomic `CopyRates()` query:

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
      BufferFilter[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferFilter[i] = h_res_filter[htf_ptr];
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

* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe of calculation. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Smoother Settings ===

* **`InpSmootherType`** (*default: `SUPERSMOOTHER`*):
  * `SUPERSMOOTHER`: 2-Pole critical-damped IIR filter (maximum smoothness, $-12\text{ dB}$ cutoff).
  * `ULTIMATESMOOTHER`: Zero-lag lead-injected filter (instantaneous reaction to price turns).

* **`InpPeriod`** (*default: `20`*): The cutoff smoothing lookback period ($P \ge 2$).
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings ===

* **`InpColorFilter`** (*default: `clrBlueViolet`*): Line color for the smoother curve.

* **`InpStyleFilter`** (*default: `STYLE_SOLID`*): Line style for the smoother curve.
* **`InpWidthFilter`** (*default: `2`*): Line thickness in pixels.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     EHLERS SMOOTHER PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. UltimateSmoother Trend Follow: Fast directional trend turns with    │
│                                   zero lagging penalty.                │
│ 2. SuperSmoother Noise Shield:    Eliminates whipsaws in consolidating │
│                                   and noisy microstructure markets.    │
│ 3. Dual-Smoother Crossover:       Fast UltimateSmoother (10) crossing  │
│                                   Slow SuperSmoother (30) -> Trigger.  │
│ 4. MTF Macro Step Alignment:      Only take M5 long pullbacks when     │
│                                   price is above the H4 SuperSmoother. │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: UltimateSmoother Fast Directional Turn

* **Configuration:** `InpSmootherType = ULTIMATESMOOTHER`, `InpPeriod = 15`.

* **Mechanism:** Because the UltimateSmoother injects feedforward lead terms, the line pivots simultaneously with price turning candles.
* **Execution:** Enter on the first candle where price closes on the opposite side of the UltimateSmoother curve. Trail stops tightly 1 ATR behind the curve.

### 6.2. Playbook 2: SuperSmoother Noise-Immune Baseline

* **Configuration:** `InpSmootherType = SUPERSMOOTHER`, `InpPeriod = 20` or `30`.

* **Mechanism:** Acts as an institutional replacement for standard 20/50 EMAs. Unlike EMAs that ripple on small pullbacks, the $-12\text{ dB/octave}$ cutoff prevents the line from bending until a genuine cycle reversal occurs.
* **Execution:** Ride trends as long as candles remain on the trending side of the SuperSmoother line.

### 6.3. Playbook 3: Dual-Smoother Crossover System

Attach two instances of the indicator to the same chart:

1. **Fast Leg:** `UltimateSmoother` ($P = 10$).
2. **Slow Baseline:** `SuperSmoother` ($P = 30$).

* **Bullish Crossover:** Fast UltimateSmoother crosses **above** Slow SuperSmoother $\rightarrow$ Clean trend initiation with zero false cross whipsaws.

* **Bearish Crossover:** Fast UltimateSmoother crosses **below** Slow SuperSmoother $\rightarrow$ Clean trend exit or short initiation.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

* Attach an **H4-calculated SuperSmoother Pro ($P=30$)** onto an **M15 execution chart**.

* **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferFilter}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferFilter}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against higher-timeframe institutional trend filters.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through a single native `INDICATOR_DATA` buffer, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferFilter` | `DRAW_LINE` | `clrBlueViolet` | Ehlers Smoother filter curve (Super or Ultimate) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Ehlers Smoother Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Ehlers Smoother Pro
int handle = iCustom(_Symbol, _Period, "Ehlers_Smoother_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     SUPERSMOOTHER,          // InpSmootherType (ENUM_SMOOTHER_TYPE)
                     20,                     // InpPeriod (Cutoff period)
                     PRICE_CLOSE_STD         // InpSourcePrice (Standard Close)
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Ehlers_Smoother_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double smoother_val[];
ArraySetAsSeries(smoother_val, true);

if(CopyBuffer(handle, 0, 1, 2, smoother_val) == 2)
  {
   double curr_smoother = smoother_val[0]; // Closed bar (Bar 1)
   double prev_smoother = smoother_val[1]; // Prior closed bar (Bar 2)
   double curr_close    = iClose(_Symbol, _Period, 1);
   double prev_close    = iClose(_Symbol, _Period, 2);

   // Example Strategy: Bullish Filter Price Cross
   bool is_cross_up = (prev_close <= prev_smoother && curr_close > curr_smoother);

   if(is_cross_up)
     {
      // Execute Buy Order (Low-Pass Filter Trend Initiation)
     }
  }
```
