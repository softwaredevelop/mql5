# Kaufman's Adaptive Moving Average (KAMA) Slope Pro (v1.10)

Quantitative First-Derivative Momentum & Velocity Subwindow Suite

---

## 1. Summary (Introduction)

**KAMA Slope Pro** is a high-precision momentum oscillator that computes the mathematical **first derivative (rate of change)** of Perry Kaufman's Adaptive Moving Average.

While the standard `KAMA_Pro` indicator serves as a dynamic support/resistance overlay on price candles, `KAMA_Slope_Pro` translates directional efficiency into an isolated, zero-anchored velocity oscillator in a separate chart subwindow. It provides early-warning trend acceleration and deceleration signals before price action breaks major market structure.

### Key Capabilities

* **First Derivative Velocity Engine:** Converts KAMA curvature into exact price-velocity points ($\Delta \text{KAMA}$).
* **Symmetrical 5-Zone Momentum Matrix:** Distinguishes between accelerating trends, decelerating pullbacks, and flat consolidation regimes using institutional thermal color-coding.
* **Integrated Signal MA Engine:** Supports 8 distinct moving average smoothing models (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA) directly over the slope histogram.
* **Unified Native & MTF Pipeline:** Seamlessly switches between ultra-low latency direct calculations and the 2026 Synchronized Multi-Timeframe Framework.
* **Natural Zero-Anchor Subwindow:** Employs a clean visual design where the color histogram naturally projects from the zero baseline without artificial gridline clutter.

---

## 2. Mathematical Foundations & Velocity Dynamics

```text

                        Δ KAMA = KAMA(t) - KAMA(t - 1)
       ▲ (Bullish Acceleration: MediumSeaGreen)
       │
 ──────┼──────────────────────────────────────────── 0.0 (Neutral Chop: Gray)
       │
       ▼ (Bearish Acceleration: Crimson)

```

### 2.1. First Derivative Formula

The velocity / slope at bar index $t$ is calculated as the discrete first difference of the underlying KAMA filter:
$$\text{Slope}_t = \text{KAMA}_t - \text{KAMA}_{t-1}$$

### 2.2. Symmetrical 5-Zone Momentum Matrix (Color States)

To identify shifts in directional momentum and market exhaustion, the slope derivative is classified into 5 distinct quantitative zones evaluated against a user-defined neutral deadband threshold ($\epsilon = \text{InpThreshold}$):

| Index | Color | Classification | Mathematical Condition | Market Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / Chop** | $\|\text{Slope}_t\| \le \epsilon$ | Consolidation; efficiency ratio collapsed; trend is flat. |
| **1.0** | `clrMediumSeaGreen` | **Strong Bullish Acceleration** | $\text{Slope}_t > \epsilon \quad \text{and} \quad \text{Slope}_t > \text{Slope}_{t-1}$ | Buyers in aggressive control; positive second derivative (speeding up). |
| **2.0** | `clrPaleGreen` | **Weak Bullish Deceleration** | $\text{Slope}_t > \epsilon \quad \text{and} \quad \text{Slope}_t \le \text{Slope}_{t-1}$ | Uptrend slowing down; potential pullback or exhaustion forming. |
| **3.0** | `clrCrimson` | **Strong Bearish Acceleration** | $\text{Slope}_t < -\epsilon \quad \text{and} \quad \text{Slope}_t < \text{Slope}_{t-1}$ | Sellers in aggressive control; negative second derivative (plunging). |
| **4.0** | `clrLightCoral` | **Weak Bearish Deceleration** | $\text{Slope}_t < -\epsilon \quad \text{and} \quad \text{Slope}_t \ge \text{Slope}_{t-1}$ | Downtrend losing downward thrust; short-covering or bounce imminent. |

---

### 2.3. Signal Moving Average Formulation

When enabled (`InpShowSignal = true`), a smoothing filter is applied over the discrete $\text{Slope}$ series:
$$\text{Signal}_t = \mathcal{MA}(\text{Slope}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalType})$$

*When `InpSignalType = VWMA`, the calculation utilizes true trade volume or tick volume:*
$$\text{Signal}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{M-1} \text{Slope}_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{M-1} V_{t-j}}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               KAMA_Slope_Calculator.mqh                │
│    (Core Math Engine - Encapsulated CKamaCalculator)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Slope & 5-Zone Color Index
                           ▼
┌────────────────────────────────────────────────────────┐
│                   KAMA_Slope_Pro.mq5                   │
│   (Unified Wrapper: Native Timeframe & MTF Engine)     │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Signal MA Engine          │
│   • BufferSlope (DATA)   │   • MovingAverage_Engine    │
│   • BufferColor (INDEX)  │   • 8 MA Smoothing Models   │
│   • BufferSignal (DATA)  │   • Full VWMA Support       │
└──────────────────────────┴─────────────────────────────┘

```

1. **Compositional Engine Architecture:** `CKamaSlopeCalculator` internally embeds `CKamaCalculator` and `CHeikinAshi_Calculator` via composition. No external heap allocations occur inside `OnCalculate`.
2. **2026 MTF Framework with DataSync Daemon:**
   * Multi-timeframe synchronization is governed by `DataSync_Tools.mqh` via a 1-second `OnTimer` background daemon.
   * **Forming LTF Block Flat-Force (Staircase Solution):** The mapping anchor dynamically snaps back to `first_bar_of_forming_htf`, forcing all lower timeframe sub-bars belonging to the active higher-timeframe candle to update in real-time without step warping.
3. **Array Chronology & Pointer Integrity:** Strictly enforces non-series chronological ordering (`ArraySetAsSeries(..., false)`) across all internal caches and indicator plots.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Timeframe for calculation. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): The lookback window ($N$) used to calculate price direction and volatility.
* `InpFastEmaPeriod` (*default: `2`*): The fastest smoothing period ($F$) during high directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): The slowest smoothing period ($S$) during low efficiency.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Standard OHLC or Synthetic Heikin Ashi).
* `InpThreshold` (*default: `0.00005`*): The deadband threshold ($\epsilon$) below which slope movement is classified as neutral consolidation (`clrGray`).

### Signal MA Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): The lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): The mathematical smoothing type (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrMaroon`*): Color applied to the signal line plot.

---

## 5. Usage & Trading Interpretation

```text

         BULLISH MOMENTUM EXPANSION              BEARISH MOMENTUM EXPANSION
    MediumSeaGreen (Accelerating)             Crimson (Accelerating)
               ▲                                         │
               │                                         ▼
     PaleGreen (Decelerating)                 LightCoral (Decelerating)
               │                                         ▲
               ▼                                         │
      Gray (Neutral Range)                      Gray (Neutral Range)

```

### 5.1. Velocity Acceleration vs. Deceleration

* **Trend Confirmation (Aggressive Entry):** A histogram bar transitioning from `clrGray` or `clrPaleGreen` to `clrMediumSeaGreen` confirms that bullish momentum is accelerating with high efficiency.
* **Early Take-Profit (Deceleration Warning):** When the histogram remains positive but changes from `clrMediumSeaGreen` to `clrPaleGreen`, the trend is losing momentum. This often precedes candle structure pullbacks or consolidations.
* **Bearish Continuation:** A transition into `clrCrimson` signals expanding downward selling velocity.

### 5.2. Signal MA Line Crossovers

* **Bullish Crossover:** The Slope histogram crosses above the Signal MA line from below $\rightarrow$ Early buy trigger.
* **Bearish Crossover:** The Slope histogram crosses below the Signal MA line from above $\rightarrow$ Early sell / exit trigger.

### 5.3. Multi-Timeframe Macro Bias Alignment

By setting `InpTimeframe = PERIOD_H1` on an `M5` or `M15` trading chart, traders can visually verify the higher-timeframe momentum state:

* Only take long intraday pullback entries when the H1 KAMA Slope is **Green (`MediumSeaGreen`)**.
* Only take short intraday pullback entries when the H1 KAMA Slope is **Red (`Crimson`)**.
* Avoid aggressive breakout trades when the H1 KAMA Slope is **Gray (`clrGray`)**.
