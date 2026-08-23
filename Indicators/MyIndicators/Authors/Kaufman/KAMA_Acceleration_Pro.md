# Kaufman's Adaptive Moving Average (KAMA) Acceleration Pro (v1.00)

Quantitative Second-Derivative Kinetic Acceleration & Force Subwindow Suite

---

## 1. Summary (Introduction)

**KAMA Acceleration Pro** is an institutional-grade kinetic momentum oscillator that calculates the mathematical **second derivative ($\Delta^2 \text{KAMA}$)** of Perry Kaufman's Adaptive Moving Average.

In market physics, price represents **Position**, the slope represents **Velocity**, and the change in slope represents **Acceleration (Force)**. While `KAMA_Slope_Pro` monitors trend direction and velocity, `KAMA_Acceleration_Pro` detects changes in the underlying force driving the market. It serves as the ultimate early-warning indicator, exposing trend exhaustion, deceleration, and explosive impulse triggers long before moving average crossovers or structural breaks manifest on the main price chart.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   THE KAMA KINETIC TRI-FACTOR SUITE                    │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Indicator        │   Physical Domain      │   Core Function        │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ KAMA_Pro             │ Position (0th Deriv)   │ Trend & Dynamic S/R    │
│ KAMA_Slope_Pro       │ Velocity (1st Deriv)   │ Momentum & Speed       │
│ KAMA_Acceleration_Pro│ Force (2nd Deriv)      │ Impulse & Exhaustion   │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Discrete Second-Derivative Engine:** Directly computes the rate of momentum change ($\Delta^2 \text{KAMA}$) with $O(1)$ efficiency.
* **Swapped Thermal 5-Zone Color Matrix:** Classifies acceleration into five institutional thermodynamic states: Strong Bull/Bear Impulses, Decelerating Fades, and Low-Energy Consolidation.
* **Integrated Signal Smoothing Engine:** Features 8 moving average algorithms (including True Volume and Tick-Volume VWMA) for precise signal line crossover identification.
* **Unified MTF Architecture with DataSync Daemon:** Seamlessly integrates with `DataSync_Tools.mqh` for non-repainting, flat-step multi-timeframe synchronization.
* **Expanded Precision Architecture (`_Digits + 4`):** Automatically scales sub-point floating resolution to eliminate quantization errors in discrete second differences.

---

## 2. Mathematical Foundations & Kinetic Dynamics

```text

                  Δ² KAMA = KAMA(t) - 2·KAMA(t - 1) + KAMA(t - 2)
       ▲ (Bullish Acceleration Expansion: DodgerBlue)
       │
 ──────┼──────────────────────────────────────────── 0.0 (Zero Force / Chop: Gray)
       │
       ▼ (Bearish Acceleration Expansion: Crimson)

```

### 2.1. Discrete Second-Derivative Derivation

Velocity (Slope) is defined as the discrete first difference:
$$\text{Slope}_t = \text{KAMA}_t - \text{KAMA}_{t-1}$$

Acceleration is the discrete rate of change of Velocity:
$$\text{Accel}_t = \text{Slope}_t - \text{Slope}_{t-1} = (\text{KAMA}_t - \text{KAMA}_{t-1}) - (\text{KAMA}_{t-1} - \text{KAMA}_{t-2})$$
$$\text{Accel}_t = \text{KAMA}_t - 2 \cdot \text{KAMA}_{t-1} + \text{KAMA}_{t-2}$$

---

### 2.2. Swapped Thermal 5-Zone Momentum Matrix

The acceleration derivative is classified into 5 distinct thermal zones relative to a user-defined neutral deadband threshold ($\epsilon = \text{InpThreshold}$):

| Index | Color | Classification | Mathematical Condition | Kinetic Market Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / Inertia** | $\|\text{Accel}_t\| \le \epsilon$ | Zero net acceleration; market is drifting with constant velocity or flat. |
| **1.0** | `clrDodgerBlue` | **Strong Bullish Force** | $\text{Accel}_t > \epsilon \quad \text{and} \quad \text{Accel}_t > \text{Accel}_{t-1}$ | Upward force expanding; parabolic trend impulse active. |
| **2.0** | `clrLightSkyBlue` | **Fading Bullish Force** | $\text{Accel}_t > \epsilon \quad \text{and} \quad \text{Accel}_t \le \text{Accel}_{t-1}$ | Upward acceleration tapering off; buyer exhaustion warning. |
| **3.0** | `clrCrimson` | **Strong Bearish Force** | $\text{Accel}_t < -\epsilon \quad \text{and} \quad \text{Accel}_t < \text{Accel}_{t-1}$ | Downward force expanding; aggressive institutional selling impulse. |
| **4.0** | `clrCoral` | **Fading Bearish Force** | $\text{Accel}_t < -\epsilon \quad \text{and} \quad \text{Accel}_t \ge \text{Accel}_{t-1}$ | Downward acceleration tapering off; short-covering bounce potential. |

---

### 2.3. Signal Moving Average Smoothing

An optional moving average smoothing line filters high-frequency acceleration micro-noise:
$$\text{Signal}_t = \mathcal{MA}(\text{Accel}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalType})$$

*When `InpSignalType = VWMA`, real or tick volume is incorporated:*
$$\text{Signal}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{M-1} \text{Accel}_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{M-1} V_{t-j}}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│             KAMA_Acceleration_Calculator.mqh           │
│   (Core Math Engine - Encapsulated CKamaCalculator)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Accel & Thermal Color Index
                           ▼
┌────────────────────────────────────────────────────────┐
│                KAMA_Acceleration_Pro.mq5               │
│   (Unified Wrapper: Native Timeframe & MTF Engine)     │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Tools         │
│   • BufferAccel (DATA)   │   • DataSync_Tools.mqh      │
│   • BufferColor (INDEX)  │   • MovingAverage_Engine    │
│   • BufferSignal (DATA)  │   • Expanded Precision      │
└──────────────────────────┴─────────────────────────────┘

```

1. **Embedded Engine Composition:** `CKamaAccelerationCalculator` encapsulates `CKamaCalculator` directly on the stack/heap without external memory leaks.
2. **Sub-Point Floating Resolution:** Acceleration signals reside in sub-pip micro-decimal territory. The indicator explicitly sets `INDICATOR_DIGITS = _Digits + 4` to prevent visual truncation on modern low-spread crypto, FX, and equity instruments.
3. **2026 MTF Framework (`DataSync_Tools.mqh`):**
   * Asynchronous 1-second timer guard (`OnTimerUpdate`).
   * Closed-bar caching prevents historical re-computation.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) guarantees non-repainting flat steps in real-time.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Timeframe for calculation. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): The lookback window ($N$) used to calculate price direction and volatility.
* `InpFastEmaPeriod` (*default: `2`*): The fastest smoothing period ($F$) during high directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): The slowest smoothing period ($S$) during low efficiency.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Standard OHLC or Synthetic Heikin Ashi).
* `InpThreshold` (*default: `0.000010`*): The deadband threshold ($\epsilon$) below which acceleration is classified as neutral consolidation (`clrGray`).

### Signal MA Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): The lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): The mathematical smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrMaroon`*): Color applied to the signal line plot.

---

## 5. Quantitative Trading Strategies & Signal Mechanics

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

* **Bullish Peak Warning:** When the price is making new highs and the KAMA Slope is positive, but the Acceleration histogram transitions from **`clrDodgerBlue`** to **`clrLightSkyBlue`**, the upward force is actively decaying. This is an institutional signal to tighten stop-losses or lock in partial profits.
* **Bearish Floor Warning:** When price plunges but Acceleration transitions from **`clrCrimson`** to **`clrCoral`**, selling pressure is decelerating, preceding a short-squeeze bounce.

### 5.2. Signal Line Crossovers as Impulse Triggers

* **Bullish Impulse Trigger:** Acceleration histogram crosses above the Signal MA line from below zero $\rightarrow$ High-conviction aggressive long entry.
* **Bearish Impulse Trigger:** Acceleration histogram crosses below the Signal MA line from above zero $\rightarrow$ High-conviction aggressive short entry.

### 5.3. The Tri-Factor KAMA Confluence Framework

For systematic institutional trading, combine all three indicators on a single chart:

```text

┌───────────┬──────────────────────────┬──────────────────────────┬──────────────────────────┐
│ Market    │ Main Chart: KAMA_Pro     │ Subwindow 1: KAMA_Slope  │ Subwindow 2: KAMA_Accel  │
├───────────┼──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ Strong Long│ Price > Rising KAMA      │ Green (MediumSeaGreen)   │ Blue (DodgerBlue)        │
│ Early Exit│ Price > Rising KAMA      │ Green (PaleGreen)        │ Fading (LightSkyBlue)    │
│ Strong Short│ Price < Falling KAMA    │ Red (Crimson)            │ Crimson (Crimson)        │
│ Early Cover│ Price < Falling KAMA     │ Red (LightCoral)         │ Fading (Coral)           │
│ No Trade  │ Flat KAMA Line           │ Gray (clrGray)           │ Gray (clrGray)           │
└───────────┴──────────────────────────┴──────────────────────────┴──────────────────────────┘

```

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferAccel` | `INDICATOR_DATA` | Discrete Acceleration 2nd Derivative Values ($\Delta^2 \text{KAMA}$) |
| **1** | `BufferAccelColor` | `INDICATOR_COLOR_INDEX` | Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignalMA` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring seamless integration with MetaTrader 5 Expert Advisors via `iCustom()`.*
