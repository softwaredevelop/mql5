# John Ehlers' Laguerre Acceleration Pro (v3.00)

Quantitative Time-Warped Second-Derivative Kinetic Acceleration & Force Subwindow Suite

---

## 1. Summary (Introduction)

**Laguerre Acceleration Pro** is an institutional-grade kinetic momentum oscillator that calculates the mathematical **second derivative ($\Delta^2 \text{Laguerre}$)** of John Ehlers' Time-Warped Laguerre Filter.

In market physics, price represents **Position**, the slope represents **Velocity**, and the change in slope represents **Acceleration (Force)**. While `Laguerre_Slope_Pro` monitors trend direction and velocity, `Laguerre_Acceleration_Pro` measures changes in the underlying force driving price action. It serves as the ultimate leading indicator, exposing trend inflection, momentum decay, and explosive impulse triggers long before structural breaks manifest on the main price chart.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   THE LAGUERRE KINETIC TRIAD SUITE                     │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Indicator        │   Physical Domain      │   Core Function        │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Laguerre_Filter_Pro  │ Position (0th Deriv)   │ Low-Lag Trend Baseline │
│ Laguerre_Slope_Pro   │ Velocity (1st Deriv)   │ Directional Speed      │
│ Laguerre_Accel_Pro   │ Force (2nd Deriv)      │ Impulse & Exhaustion   │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Discrete Second-Derivative Force Engine:** Directly computes the rate of momentum change ($\Delta^2 \text{Laguerre}$) with zero latency.
* **Swapped Thermal 5-Zone Color Matrix:** Classifies acceleration into five distinct thermodynamic states: Strong Impulses, Decelerating Fades, and Low-Energy Consolidation.
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter sensitivity with natural golden ratio proportions (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* **Integrated Signal Smoothing Engine:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) directly over the acceleration histogram.
* **Unified 2026 MTF Framework:** Higher-timeframe Laguerre Acceleration histograms (e.g., M15, H1, H4) map onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Expanded Precision Architecture (`_Digits + 4`):** Automatically scales sub-point floating resolution to eliminate quantization errors in discrete second differences.

---

## 2. Mathematical Foundations & Acceleration Dynamics

```text

               Δ² Laguerre = Laguerre(t) - 2·Laguerre(t - 1) + Laguerre(t - 2)
       ▲ (Bullish Force Expansion: DodgerBlue)
       │
 ──────┼──────────────────────────────────────────── 0.0 (Zero Net Force / Chop: Gray)
       │
       ▼ (Bearish Force Expansion: Crimson)

```

### 2.1. Discrete Second-Derivative Derivation

Given the discrete velocity (first derivative) $\text{Slope}_t = \text{Laguerre}_t - \text{Laguerre}_{t-1}$:
$$\text{Accel}_t = \text{Slope}_t - \text{Slope}_{t-1} = (\text{Laguerre}_t - \text{Laguerre}_{t-1}) - (\text{Laguerre}_{t-1} - \text{Laguerre}_{t-2})$$
$$\text{Accel}_t = \text{Laguerre}_t - 2 \cdot \text{Laguerre}_{t-1} + \text{Laguerre}_{t-2}$$

---

### 2.2. Swapped Thermal 5-Zone Momentum Matrix

The acceleration derivative is classified into 5 distinct thermal zones relative to a user-defined neutral deadband threshold ($\epsilon = \text{InpThreshold}$):

| State Index | Color | Classification | Mathematical Condition | Kinetic Market Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / Consolidation** | $\|\text{Accel}_t\| \le \epsilon$ | Zero net acceleration; market drifting or in consolidation. |
| **1.0** | `clrDodgerBlue` | **Strong Bullish Force** | $\text{Accel}_t > \epsilon \quad \text{and} \quad \text{Accel}_t > \text{Accel}_{t-1}$ | Upward force expanding; parabolic trend impulse active. |
| **2.0** | `clrLightSkyBlue` | **Fading Bullish Force** | $\text{Accel}_t > \epsilon \quad \text{and} \quad \text{Accel}_t \le \text{Accel}_{t-1}$ | Upward acceleration tapering off; buyer exhaustion warning. |
| **3.0** | `clrCrimson` | **Strong Bearish Force** | $\text{Accel}_t < -\epsilon \quad \text{and} \quad \text{Accel}_t < \text{Accel}_{t-1}$ | Downward force expanding; aggressive selling impulse active. |
| **4.0** | `clrCoral` | **Fading Bearish Force** | $\text{Accel}_t < -\epsilon \quad \text{and} \quad \text{Accel}_t \ge \text{Accel}_{t-1}$ | Downward acceleration tapering off; short-covering bounce potential. |

---

### 2.3. Signal Moving Average Smoothing

An optional moving average smoothing line filters high-frequency acceleration micro-noise:
$$\text{Signal}_t = \mathcal{MA}\left( \text{Accel}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalType} \right)$$

*When `InpSignalType = VWMA`, real or tick volume is incorporated:*
$$\text{Signal}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{M-1} \text{Accel}_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{M-1} V_{t-j}}$$

---

### 2.4. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

| Fibonacci Gamma | Damping Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Application |
| :---: | :---: | :--- | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** Instantaneous acceleration spikes and micro-turning points. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 10\text{ EMA}$ | **Optimal Execution Baseline.** Early momentum shifts with minimal noise. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 50\text{ EMA}$ | **The Golden Ratio Anchor.** Smooth force transitions without whipsaws. |
| **`0.764`** | Strong | High | Macro Cycle Filtering | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies macro momentum exhaustion on H4/D1 charts. |
| **`0.882`** | Ultra-Strong | Very High | Secular Cycle Smoothing | $\approx 200\text{ EMA}$ | **Absolute Noise Elimination.** Identifies macro secular cycle turning points. |

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
│            Laguerre_Acceleration_Calculator.mqh        │
│    (2nd Derivative Difference & 5-Zone Force Engine)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Accel & Color Index in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│              Laguerre_Acceleration_Pro.mq5             │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferAccel (DATA)   │   • DataSync_Tools.mqh      │
│   • BufferAccelColor(IDX)│   • MovingAverage_Engine    │
│   • BufferSignalMA (DATA)│   • Expanded Precision      │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Hierarchy:** Separates raw Laguerre polynomial tracking (`Laguerre_Engine.mqh`) from second-derivative acceleration physics (`Laguerre_Acceleration_Calculator.mqh`) and moving average smoothing (`MovingAverage_Engine.mqh`).
2. **Leak-Free Pointer Protection:** Factory methods safely verify pointer validity (`CheckPointer`) before re-allocation on parameter updates.
3. **Sub-Point Floating Resolution:** Acceleration signals reside in sub-pip micro-decimal territory. The indicator explicitly sets `INDICATOR_DIGITS = _Digits + 4` to prevent visual truncation on modern low-spread assets.
4. **2026 MTF Framework with Staircase Solution:** Maps higher-timeframe acceleration histograms onto lower-timeframe execution charts with zero step-warping via `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Laguerre Settings

* `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).
* `InpThreshold` (*default: `0.00001`*): The deadband threshold ($\epsilon$) below which acceleration is classified as neutral consolidation (`clrGray`).

### Signal MA Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrMaroon`*): Color applied to the signal line plot.

---

## 5. Quantitative Trading Playbooks

```text

               BULLISH FORCE EXPANSION                BEARISH FORCE EXPANSION
          DodgerBlue (Strong Force)                Crimson (Strong Force)
                     ▲                                        │
                     │                                        ▼
          LightSkyBlue (Fading Force)               Coral (Fading Force)
                     │                                        ▲
                     ▼                                        │
             Gray (Zero Force)                        Gray (Zero Force)

```

### 5.1. Leading Exhaustion & Early Take-Profit

* **Bullish Peak Warning:** When price is making new highs and `Laguerre_Slope_Pro` is positive, but `Laguerre_Acceleration_Pro` transitions from **`clrDodgerBlue`** to **`clrLightSkyBlue`**, upward force is actively decaying. This is an institutional signal to tighten stop-losses or lock in partial profits.
* **Bearish Floor Warning:** When price plunges but Acceleration transitions from **`clrCrimson`** to **`clrCoral`**, downward selling pressure is decelerating, preceding a short-squeeze bounce.

### 5.2. Signal Line Crossovers as Impulse Triggers

* **Bullish Impulse Trigger:** Acceleration histogram crosses above the Signal MA line from below zero $\rightarrow$ High-conviction aggressive long entry.
* **Bearish Impulse Trigger:** Acceleration histogram crosses below the Signal MA line from above zero $\rightarrow$ High-conviction aggressive short entry.

### 5.3. The Complete Laguerre Kinetic Triad Confluence Framework

For systematic trading, combine all three indicators on a single chart:

```text

┌───────────┬──────────────────────────┬──────────────────────────┬──────────────────────────┐
│ Market    │ Main Chart: Laguerre     │ Subwindow 1: Slope       │ Subwindow 2: Acceleration│
├───────────┼──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ Strong Long│ Price > Rising Laguerre  │ Green (MediumSeaGreen)   │ Blue (DodgerBlue)        │
│ Early Exit│ Price > Rising Laguerre  │ Green (PaleGreen)        │ Fading (LightSkyBlue)    │
│ Strong Short│ Price < Falling Laguerre│ Red (Crimson)            │ Crimson (Crimson)        │
│ Early Cover│ Price < Falling Laguerre │ Red (LightCoral)         │ Fading (Coral)           │
│ No Trade  │ Flat Laguerre Line       │ Gray (clrGray)           │ Gray (clrGray)           │
└───────────┴──────────────────────────┴──────────────────────────┴──────────────────────────┘

```

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferAccel` | `INDICATOR_DATA` | Discrete Laguerre Acceleration 2nd Derivative Values ($\Delta^2 \text{Laguerre}$) |
| **1** | `BufferAccelColor` | `INDICATOR_COLOR_INDEX` | Symmetrical 5-Zone Thermal Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignalMA` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
