# John Ehlers' Laguerre Slope Pro (v3.00)

Quantitative Time-Warped First-Derivative Momentum & Velocity Subwindow Suite

---

## 1. Summary (Introduction)

**Laguerre Slope Pro** is an institutional-grade kinetic momentum oscillator that calculates the mathematical **first derivative (rate of change / slope)** of John Ehlers' Time-Warped Laguerre Filter.

Because the underlying Laguerre Filter eliminates high-frequency market noise using an orthogonal all-pass transfer function with near-zero phase lag, its discrete first difference produces one of the most responsive, low-noise velocity histograms available in technical analysis.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     LAGUERRE SLOPE MOMENTUM ENGINE                     │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Output Plot      │   Color Mapping        │   Core Kinetic Role    │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Laguerre Slope Hist  │ 5-Zone Thermal Palette │ Instantaneous Velocity │
│ Signal MA Line       │ clrMaroon (Width:1)    │ Smoothed Trigger Line  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Discrete First-Derivative Velocity Engine:** Computes exact price-velocity points ($\Delta \text{Laguerre}$) with zero latency.
* **Symmetrical 5-Zone Momentum Matrix:** Distinguishes between accelerating trend impulses, decelerating pullbacks, and flat consolidation noise.
* **Integrated Signal Smoothing Engine:** Supports 8 moving average smoothing algorithms (including Volume-Weighted VWMA) directly over the slope histogram.
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter sensitivity with golden ratio proportions (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* **Unified 2026 MTF Framework:** Higher-timeframe Laguerre Slope histograms (e.g., M15, H1, H4) map onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Natural Zero-Anchor Subwindow:** Features a clean, uncluttered visual layout where histogram bars naturally project from the $0.0$ baseline.

---

## 2. Mathematical Foundations & Slope Dynamics

```text

                  Δ Laguerre = Laguerre(t) - Laguerre(t - 1)
       ▲ (Bullish Acceleration: MediumSeaGreen)
       │
 ──────┼──────────────────────────────────────────── 0.0 (Neutral Chop: Gray)
       │
       ▼ (Bearish Acceleration: Crimson)

```

### 2.1. The Discrete First Derivative (Velocity / Slope)

Given the Laguerre Filter baseline $\text{Laguerre}_t = \frac{L_0(t) + 2 L_1(t) + 2 L_2(t) + L_3(t)}{6}$:
$$\text{Slope}_t = \text{Laguerre}_t - \text{Laguerre}_{t-1}$$

---

### 2.2. Symmetrical 5-Zone Momentum Matrix

To classify momentum velocity and second-derivative acceleration, the slope is categorized into 5 quantitative zones evaluated against a user-defined neutral deadband threshold ($\epsilon = \text{InpThreshold}$):

| State Index | Color | Classification | Mathematical Condition | Market Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / Consolidation** | $\|\text{Slope}_t\| \le \epsilon$ | Low kinetic energy; consolidation chop. |
| **1.0** | `clrMediumSeaGreen` | **Strong Bullish Acceleration** | $\text{Slope}_t > \epsilon \quad \text{and} \quad \text{Slope}_t > \text{Slope}_{t-1}$ | Buyers in aggressive control; upward velocity speeding up. |
| **2.0** | `clrPaleGreen` | **Weak Bullish Deceleration** | $\text{Slope}_t > \epsilon \quad \text{and} \quad \text{Slope}_t \le \text{Slope}_{t-1}$ | Uptrend slowing down; potential pullback or exhaustion forming. |
| **3.0** | `clrCrimson` | **Strong Bearish Acceleration** | $\text{Slope}_t < -\epsilon \quad \text{and} \quad \text{Slope}_t < \text{Slope}_{t-1}$ | Sellers in aggressive control; downward velocity speeding up. |
| **4.0** | `clrLightCoral` | **Weak Bearish Deceleration** | $\text{Slope}_t < -\epsilon \quad \text{and} \quad \text{Slope}_t \ge \text{Slope}_{t-1}$ | Downtrend losing downward thrust; short-covering bounce potential. |

---

### 2.3. Signal Moving Average Smoothing

An optional moving average smoothing line filters high-frequency slope micro-noise:
$$\text{Signal}_t = \mathcal{MA}\left( \text{Slope}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalType} \right)$$

*When `InpSignalType = VWMA`, real or tick volume is incorporated:*
$$\text{Signal}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{M-1} \text{Slope}_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{M-1} V_{t-j}}$$

---

### 2.4. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

| Fibonacci Gamma | Smoothing Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Application |
| :---: | :---: | :---: | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** High-frequency turning points and micro-cycle reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 10\text{ EMA}$ | **Optimal Execution Baseline.** Fast cycle turns with minimal noise. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 50\text{ EMA}$ | **The Golden Ratio Anchor.** Smooth cycle transitions without whipsaws. |
| **`0.764`** | Strong | High | Macro Cycle Filtering | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies macro turning points on H4/D1 charts. |
| **`0.882`** | Ultra-Strong | Very High | Secular Cycle Smoothing | $\approx 200\text{ EMA}$ | **Absolute Noise Elimination.** Identifies macro secular bull/bear cycle bottoms. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                   Laguerre_Engine.mqh                  │
│    (Core DSP Math: Computes L0..L3 Orthogonal States)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds Laguerre Filter Baseline
                           ▼
┌────────────────────────────────────────────────────────┐
│              Laguerre_Slope_Calculator.mqh             │
│    (Slope Difference & 5-Zone Momentum Matrix Engine)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Slope & Color Index in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                Laguerre_Slope_Pro.mq5                  │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferSlope (DATA)   │   • DataSync_Tools.mqh      │
│   • BufferSlopeColor(IDX)│   • MovingAverage_Engine    │
│   • BufferSignalMA (DATA)│   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Engine Hierarchy:** Isolates raw polynomial state tracking (`Laguerre_Engine.mqh`) from first-derivative velocity calculation (`Laguerre_Slope_Calculator.mqh`) and moving average smoothing (`MovingAverage_Engine.mqh`).
2. **Leak-Free Pointer Protection:** Factory methods safely verify pointer validity (`CheckPointer`) before re-allocation on parameter updates.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Laguerre Settings

* `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).
* `InpThreshold` (*default: `0.00005`*): The deadband threshold ($\epsilon$) below which slope velocity is classified as neutral consolidation (`clrGray`).

### Signal MA Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrMaroon`*): Color applied to the signal line plot.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE SLOPE TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Acceleration Expansion: Enter in direction of strong momentum when  │
│                            bars turn MediumSeaGreen / Crimson.         │
│ 2. Early Warning Fade:     When bars change to PaleGreen / LightCoral, │
│                            momentum is decaying; tighten stop-loss.    │
│ 3. Signal Line Crossover:  Slope crosses Signal MA in direction of     │
│                            higher-timeframe macro trend baseline.      │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Velocity Acceleration vs. Deceleration

* **Trend Confirmation (Aggressive Entry):** A histogram bar transitioning from `clrGray` or `clrPaleGreen` to **`clrMediumSeaGreen`** confirms that bullish momentum is accelerating with high efficiency.
* **Early Take-Profit (Deceleration Warning):** When the histogram remains positive but changes from `clrMediumSeaGreen` to **`clrPaleGreen`**, the trend is losing momentum. This often precedes candle structure pullbacks or consolidations.
* **Bearish Continuation:** A transition into **`clrCrimson`** signals expanding downward selling velocity.

### 5.2. Signal MA Line Crossovers

* **Bullish Crossover:** The Laguerre Slope histogram crosses **above** the Signal MA line from below $\rightarrow$ Early buy trigger.
* **Bearish Crossover:** The Laguerre Slope histogram crosses **below** the Signal MA line from above $\rightarrow$ Early sell / exit trigger.

### 5.3. Multi-Timeframe Macro Bias Alignment

* Attach an **H1-calculated Laguerre Slope ($\gamma=0.618$)** onto an **M5 execution chart**.
* **Rule:** Only take intraday long pullbacks on M5 when **H1 Laguerre Slope is positive and Green (`MediumSeaGreen`)**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferSlope` | `INDICATOR_DATA` | Discrete Laguerre Slope 1st Derivative Values ($\Delta \text{Laguerre}$) |
| **1** | `BufferSlopeColor` | `INDICATOR_COLOR_INDEX` | Symmetrical 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignalMA` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
