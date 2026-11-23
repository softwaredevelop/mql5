# Roofing Filter Pro (v2.00)

## Institutional Multi-Timeframe Zero-Mean Bandpass Pre-Conditioning Filter Suite (2-Pole HighPass + 2-Pole SuperSmoother)

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Market Data Structure Theory

**Roofing Filter Pro (v2.00)** is the premier spectral pre-conditioning and cycle-isolation filter of the Professional MQL5 Suite. Directly implementing John Ehlers’ seminal research (*"Predictive Indicators for Effective Trading Strategies"*, 2013), the filter resolves the two fundamental physical distortions inherent in all financial market data:

1. **Aliasing Noise (High-Frequency Distortion):** Market data contains sampling noise in cycles shorter than 10 bars, peaking at the 2-bar Nyquist frequency. Traditional moving averages (SMA, EMA) are inefficient filters—a 10-bar EMA only attenuates the Nyquist frequency by $13 \text{ dB}$ while introducing massive phase lag.
2. **Spectral Dilation (Low-Frequency Distortion):** Due to the fractal nature of financial markets, wave amplitude grows roughly in proportion to cycle period—increasing at a rate of approximately **$6 \text{ dB per octave}$** as periods double.
   * Conventional oscillators (like Stochastic or RSI) contain only a single differencing term, acting mathematically as a 1-pole HighPass filter ($6 \text{ dB/octave}$ attenuation).
   * Because Spectral Dilation increases at $+6 \text{ dB/octave}$ and a 1-pole filter attenuates at $-6 \text{ dB/octave}$, **the two effects cancel out**, causing classical oscillators to retain long-period trend drift and fail to oscillate around a true zero mean!

**Roofing Filter Pro solves both distortions simultaneously by cascading a 2-Pole HighPass Filter ($12 \text{ dB/octave}$ attenuation) directly into a 2-Pole SuperSmoother Filter**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   ROOFING FILTER ARCHITECTURAL OVERVIEW                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 2-Pole HighPass Filter      • 12 dB/octave low-frequency attenuation│
│                                • Overcomes 6 dB/octave Spectral Dilation│
│                                • Produces a strictly ZERO-MEAN output  │
├────────────────────────────────────────────────────────────────────────┤
│ 2. 2-Pole SuperSmoother Filter • Critically damped Butterworth response│
│                                • Virtually eliminates Nyquist aliasing │
│                                • Preserves clean trading swing cycles  │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Precomputed DSP Matrix      • All trigonometric (cos, sin, exp) and │
│                                  squared constants computed in Init()  │
│                                • Hardware-pipelined O(1) FMA math      │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Persistent State Memory     • Zero stack allocations on live ticks  │
│                                • Synthetic Heikin Ashi price routing   │
│                                • 2048-element memory capacity reserves │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Cascaded Bandpass DSP Pipeline

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
                                           ▼
                   Stage 1: 2-Pole HighPass Filter (Cutoff: 48 Bars)
                   Attenuates periods > 48 bars at 12 dB/octave
                     Removes Spectral Dilation -> Zero Mean!
                                           │
                                           ▼
                 Stage 2: 2-Pole SuperSmoother Filter (Cutoff: 10 Bars)
                    Attenuates cycles < 10 bars (Aliasing Noise)
                                           │
                                           ▼
                   Roofing Bandpass Output (10 to 48 Bar Cycles)
                    Clean, Stationary, Zero-Mean Cyclic Wave
```

The mathematical engine executes a 2-stage cascaded infinite impulse response (IIR) transfer function parameterized by the HighPass cutoff $P_{hp}$ (`InpHighPassPeriod`, default 48) and the SuperSmoother cutoff $P_{ss}$ (`InpSuperSmootherPeriod`, default 10):

### 2.1. Stage 1: 2-Pole HighPass Filter (Spectral Dilation Removal)

To ensure nanosecond execution, all transcendental constants are hoisted and precomputed strictly once during `Init()`:

$$\theta_{hp} = \frac{0.707 \times 2 \pi}{P_{hp}} = \frac{1.414 \pi}{P_{hp}}$$
$$\alpha_1 = \frac{\cos(\theta_{hp}) + \sin(\theta_{hp}) - 1.0}{\cos(\theta_{hp})}$$
$$k_0 = \left(1.0 - \frac{\alpha_1}{2.0}\right)^2, \quad\quad k_1 = 2.0 (1.0 - \alpha_1), \quad\quad k_2 = (1.0 - \alpha_1)^2$$

The real-time difference equation passes cycles shorter than $P_{hp}$ bars while eliminating long-term trend drift:
$$\text{HP}_t = k_0 (P_t - 2.0 P_{t-1} + P_{t-2}) + k_1 \text{HP}_{t-1} - k_2 \text{HP}_{t-2}$$

### 2.2. Stage 2: 2-Pole SuperSmoother Filter (Aliasing Noise Removal)

Precomputed analytical coefficients for the critically damped low-pass stage:

$$\theta_{ss} = \frac{\sqrt{2} \pi}{P_{ss}}$$
$$a_1 = e^{-\theta_{ss}}, \quad\quad b_1 = 2.0 a_1 \cos(\theta_{ss})$$
$$c_2 = b_1, \quad\quad c_3 = -a_1^2, \quad\quad c_1 = 1.0 - c_2 - c_3, \quad\quad c_{1, \text{half}} = 0.5 \times c_1$$

The SuperSmoother processes the HighPass output $\text{HP}_t$ to yield the final bandpass Roofing Filter:
$$\text{Roofing}_t = c_{1, \text{half}} (\text{HP}_t + \text{HP}_{t-1}) + c_2 \text{Roofing}_{t-1} + c_3 \text{Roofing}_{t-2}$$

*Bandpass Isolation:* The resulting wave strictly passes cyclic components having periods between **$10$ bars and $48$ bars**, exhibiting a smooth profile centered cleanly around a **zero mean ($0.0$)**.

---

## 3. Predictive vs. Confirmation Trading (Ehlers' Core Strategy)

In his paper, John Ehlers demonstrates why conventional rule-based confirmation fails for short-term swing trading:

* A typical monthly market cycle consists of approximately $10$ bars up and $10$ bars down.
* Waiting for an oscillator to hit bottom, turn up, and cross a confirmation level introduces $\approx 8$ bars of cumulative lag—meaning the 10-bar up-move is virtually over at entry, and the trade exits after 8 bars of adverse movement against the trader.

**By removing both Aliasing Noise and Spectral Dilation, the Roofing Filter allows traders to conquer lag by anticipating cyclic turning points**:

* Because the wave is stationary and zero-mean, turns occur symmetrically. Entering **ahead** of the confirmation turn when the wave reaches cycle exhaustion bounds captures the entire ensuing 10-bar swing!

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Roofing Filters onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

`Roofing_Filter_Pro` executes a single atomic `CopyRates()` query to update all OHLC caches simultaneously in nanoseconds.

### 4.2. Two-Pointer Chronological Sweep ($O(N)$ Projection)

Sweeps chronologically forward using two moving pointers without calling `iBarShift()`:

```mql5
int htf_ptr = 0;
datetime oldest_htf = h_time[0];

for(int i = 0; i < rates_total; i++)
  {
   datetime t = time[i];
   if(t < oldest_htf)
     {
      BufferRoofing[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferRoofing[i] = h_res_roofing[htf_ptr];
  }
```

### 4.3. Live-Tick RAM Mocking & Binary Snapping

During live market ticks, only the forming HTF candle in RAM is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) locates the start of the forming block and updates values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Roofing Filter Settings ===

* **`InpHighPassPeriod`** (*default: `48`*): Cutoff period for the 2-pole HighPass filter. Removes all cycle trends longer than this length (eliminating Spectral Dilation).

* **`InpSuperSmootherPeriod`** (*default: `10`*): Cutoff period for the 2-pole SuperSmoother filter. Eliminates all high-frequency Aliasing Noise shorter than this length.
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings ===

* **`InpColorFilter`** (*default: `clrCrimson`*): Line color for the Roofing Filter curve.

* **`InpStyleFilter`** (*default: `STYLE_SOLID`*): Line style for the Roofing Filter curve.
* **`InpWidthFilter`** (*default: `2`*): Line thickness in pixels.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       ROOFING FILTER PLAYBOOKS                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Mean Equilibrium Cross:  Roofing crossing above 0.0 confirms   │
│                                  the cyclic upswing phase initiation.  │
│ 2. Anticipatory Swing Entry:     Enter ahead of turn when Roofing      │
│                                  reaches symmetric peak/trough bounds. │
│ 3. Secondary Pre-Conditioning:   Feed Roofing output into Stochastic   │
│                                  or RSI to eliminate trend saturation. │
│ 4. MTF Macro Cycle Alignment:    Only take M5 long entries when H1     │
│                                  Roofing is positive and expanding.    │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Zero-Line Cycle Momentum Cross

* **Mechanism:** Because the Roofing Filter removes spectral dilation, $0.0$ is the exact stationary center of the market wave.

* **Bullish Regime:** $\text{Roofing}_t > 0.0$ and rising $\rightarrow$ Bullish cyclic expansion phase.
* **Bearish Regime:** $\text{Roofing}_t < 0.0$ and falling $\rightarrow$ Bearish cyclic contraction phase.

### 6.2. Playbook 2: Anticipatory Cycle Reversal Entry

* **Mechanism:** Following Ehlers' predictive strategy (Figure 7 of his paper):

* **Long Anticipation:** When the Roofing Filter plunges sharply below historical negative extremes and decelerates before turning up, prepare to scale into long positions *before* the delayed confirmation trigger fires.
* **Short Anticipation:** When the filter spikes sharply into historical positive extremes and begins rounding over, prepare to short *before* the confirmation cross.

### 6.3. Playbook 3: Data Pre-Conditioning for Downstream Systems

* **Mechanism:** Use the `CRoofingFilterCalculator` class as a pure-math pre-processor inside Expert Advisors or custom Ensemble indicators.

* **Advantage:** Passing `BufferRoofing` instead of raw `Close` prices into Stochastics, RSI, or neural networks removes non-stationary price drift and guarantees bounded, zero-mean training features.

### 6.4. Playbook 4: Multi-Timeframe Macro Cycle Alignment

* Attach an **H1-calculated Roofing Filter Pro (48, 10)** onto an **M5 execution chart**.

* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferRoofing}_{\text{H1 Step}} > 0.0 \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferRoofing}_{\text{H1 Step}} < 0.0 \implies \text{Short Trades Permitted Only}$$
* Prevents intraday scalpers from entering positions against the dominant higher-timeframe bandpass cycle wave.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through a single native `INDICATOR_DATA` buffer, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferRoofing` | `DRAW_LINE` | `clrCrimson` | Zero-Mean Bandpass Roofing Filter curve |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Roofing Filter Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Roofing Filter Pro
int handle = iCustom(_Symbol, _Period, "Roofing_Filter_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     48,                     // InpHighPassPeriod (Removes Spectral Dilation)
                     10,                     // InpSuperSmootherPeriod (Removes Aliasing Noise)
                     PRICE_CLOSE_STD         // InpSourcePrice (Standard Close)
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Roofing_Filter_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double roofing_val[];
ArraySetAsSeries(roofing_val, true);

if(CopyBuffer(handle, 0, 1, 2, roofing_val) == 2)
  {
   double roof_curr = roofing_val[0];     // Closed bar (Bar 1)
   double roof_prev = roofing_val[1];     // Prior closed bar (Bar 2)

   // Example Strategy: Bullish Zero-Mean Cross
   bool is_bull_cross = (roof_prev <= 0.0 && roof_curr > 0.0);

   // Example Strategy: Bearish Zero-Mean Cross
   bool is_bear_cross = (roof_prev >= 0.0 && roof_curr < 0.0);

   if(is_bull_cross)
     {
      // Execute Buy Order (Zero-Mean Cycle Expansion)
     }
   else if(is_bear_cross)
     {
      // Execute Sell Order (Zero-Mean Cycle Contraction)
     }
  }
```
