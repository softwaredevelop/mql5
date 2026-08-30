# Kinematic Velocity Vector & Speed Envelope Pro (v4.00)

Quantitative Newtonian Kinematics & Volatility-Normalized Velocity Suite

---

## 1. Summary (Introduction)

**Velocity Pro** is an institutional-grade kinematic oscillator that models financial market dynamics using classical physics principles. Rather than simply plotting unnormalized price differences, **Velocity Pro decomposes market motion into a Directional Velocity Vector ($\vec{V}$) and an Omnidirectional Speed Scalar ($S$)**, normalized against volatility via the **Average True Range (ATR)**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        KINEMATIC VELOCITY MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  Velocity Vector (V): Directional Net Displacement per Bar in ATR units │
│  Speed Scalar (S):    Total Cumulative Path Length per Bar in ATR units │
│  Kinematic Envelope:  Symmetrical Boundaries (±S) defining 100% Motion │
│                       Efficiency                                       │
└────────────────────────────────────────────────────────────────────────┘

```

### Core Kinematic Principles

* **The Directional Velocity Vector ($\vec{V}$):** Rendered as a 5-Zone Swapped Thermal Histogram, it measures the directional slope of price displacement.
* **The Omnidirectional Speed Envelope ($\pm S$):** Symmetrical upper ($+S$) and lower ($-S$) boundary lines measuring the total mechanical work performed by market participants.
* **Kinematic Efficiency ($\vec{V} = \pm S$):** When the Velocity histogram reaches or touches the outer Speed Envelope line, price is moving in a **100% straight line with zero counter-trend pullbacks**. This flags maximum institutional momentum expansion or parabolic climax exhaustion.

---

## 2. Mathematical Foundations & Kinematic Dynamics

```text

                  Upper Speed Envelope: +S (Maximum Path Length)
       ═══════════════════════════════════════════════════════════════ clrDarkOrange
                  Climax Threshold (+1.0 ATR/bar)
       ─────────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                  Flow Threshold (+0.3 ATR/bar)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                  0.0 Baseline (Zero Velocity / Equilibrium)
       ─────────────────────────────────────────────────────────────── Gray (Noise)
                  Flow Threshold (-0.3 ATR/bar)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                  Climax Threshold (-1.0 ATR/bar)
       ─────────────────────────────────────────────────────────────── OrangeRed (Bear Climax)
                  Lower Speed Envelope: -S (Maximum Path Length)
       ═══════════════════════════════════════════════════════════════ clrDarkOrange

```

### 2.1. Volatility Normalization Base (Wilder's ATR)

$$\text{ATR}_t = \text{Wilder's RMA}(TR_t, P_{\text{ATR}})$$
*where $P_{\text{ATR}} = \text{InpATRPeriod}$ (default: $14$).*

---

### 2.2. The Directional Velocity Vector ($\vec{V}_t$)

Velocity measures the net displacement of price over lookback window $P_{\text{vel}} = \text{InpVelPeriod}$ expressed in units of ATR per bar:
$$\Delta P_t = P_t - P_{t - P_{\text{vel}}}$$
$$\vec{V}_t = \frac{\Delta P_t}{P_{\text{vel}} \cdot \text{ATR}_t}$$

---

### 2.3. The Omnidirectional Speed Scalar ($S_t$)

Speed measures the total gross distance (Path Length) traveled by price regardless of direction, normalized in ATR units:
$$\text{Path Length}_t = \sum_{k=0}^{P_{\text{vel}}-1} |P_{t-k} - P_{t-k-1}|$$
$$S_t = \frac{\frac{1}{P_{\text{vel}}} \text{Path Length}_t}{\text{ATR}_t}$$

### 2.4. Symmetrical Speed Envelope Boundaries

$$\text{Speed (+)}_t = +S_t, \quad\quad \text{Speed (-)}_t = -S_t$$

---

### 2.5. Swapped Thermal 5-Zone Palette Classification

| State Index | Color | Classification | Kinematic Trigger | Market Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / No Edge** | $\|\vec{V}_t\| < 0.30$ | Low kinetic energy; consolidation chop. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+0.30 \le \vec{V}_t < +1.00$ | Healthy upward velocity; trend expansion active. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $\vec{V}_t \ge +1.00$ | High-speed upward impulse; near maximum efficiency. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-1.00 < \vec{V}_t \le -0.30$ | Healthy downward velocity; trend expansion active. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $\vec{V}_t \le -1.00$ | High-speed downward impulse; near maximum efficiency. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               Velocity_Calculator.mqh                  │
│    (Core Math: Computes ATR, Velocity & Speed Envelopes│
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Velocity, Color, Speed (+/-)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   Velocity_Pro.mq5                     │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (5)       │   Centralized Framework     │
│   • Velocity (HISTOGRAM) │   • DataSync_Tools.mqh      │
│   • Color Index (COLOR)  │   • MovingAverage_Engine    │
│   • Speed Envelopes (2)  │   • 4 Kinematic Levels      │
│   • Signal MA Line (1)   │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular Kinematic Engine:** `CVelocityCalculator` encapsulates `CATRCalculator` and `CHeikinAshi_Calculator` via composition, guaranteeing zero memory fragmentation.
2. **2026 MTF Framework with Staircase Solution:** Higher-timeframe kinematic vectors map into synchronized, flat steps on lower-timeframe execution charts via `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.
3. **Signal MA Smoothing Engine:** Integrates `MovingAverage_Engine.mqh` to apply all 8 moving average algorithms (including Volume-Weighted VWMA) over the raw Velocity vector.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Velocity Kinematics Settings

* `InpVelPeriod` (*default: `3`*): Lookback period ($P_{\text{vel}}$) for computing the velocity displacement vector.
* `InpATRPeriod` (*default: `14`*): Wilder's lookback period ($P_{\text{ATR}}$) for volatility normalization.
* `InpThresholdLow` (*default: `0.3`*): Flow Zone threshold ($\pm 0.30$ ATR/bar).
* `InpThresholdHigh` (*default: `1.0`*): Climax Zone threshold ($\pm 1.00$ ATR/bar).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price source for velocity calculation.
* `InpATRSource` (*default: `ATR_SOURCE_STANDARD`*): Volatility source for ATR calculation.

### Speed Envelope Settings

* `InpShowSpeed` (*default: `true`*): Toggle visibility of the symmetrical Speed Envelopes ($\pm S$).
* `InpColorSpeed` (*default: `clrDarkOrange`*): Color of the Speed Envelope lines.
* `InpStyleSpeed` (*default: `STYLE_SOLID`*): Line style of Speed Envelopes.
* `InpWidthSpeed` (*default: `1`*): Line thickness of Speed Envelopes.

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the smoothed Signal MA line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels

* `InpLevelClimaxPos` (*default: `1.0`*): Bullish Climax level line.
* `InpLevelFlowPos` (*default: `0.3`*): Bullish Flow level line.
* `InpLevelFlowNeg` (*default: `-0.3`*): Bearish Flow level line.
* `InpLevelClimaxNeg` (*default: `-1.0`*): Bearish Climax level line.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   KINEMATIC VELOCITY PLAYBOOKS                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 100% Efficiency Climax: Velocity hits Speed Envelope (V = ±S).       │
│                            Take profit or prepare mean-reversion.      │
│ 2. Flow Momentum Entry:    Velocity breaks > +0.3 (LightSkyBlue) with  │
│                            Signal MA cross = Long Continuation.        │
│ 3. Kinematic Squeeze:      Speed Envelope contracts to narrow corridor,│
│                            preceding an explosive velocity expansion.  │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The 100% Kinematic Efficiency Climax ($\vec{V} = \pm S$)

* **Context:** Price is surging aggressively.
* **Condition:** The Velocity histogram bar touches or pushes directly against the **`Speed (+)`** envelope line ($+S$).
* **Kinematic Interpretation:** Every tick of movement is purely directional with zero structural friction. This represents peak impulse power.
* **Action:** Tighten trailing stop-losses. When Velocity drops back inside the Speed Envelope and crosses below the Signal MA line, close or scale out long positions.

### 5.2. Flow Zone Trend Continuation ($\pm 0.30 \dots \pm 1.00$)

* **Bullish Trigger:** Velocity crosses above `+0.30 (LightSkyBlue)` AND crosses above the Signal MA line $\rightarrow$ High-probability long trend entry.
* **Bearish Trigger:** Velocity crosses below `-0.30 (Coral)` AND crosses below the Signal MA line $\rightarrow$ High-probability short trend entry.

### 5.3. Multi-Timeframe Macro Kinematic Filter

* Attach an **H1-calculated Velocity Pro** onto an **M5 execution chart**.
* Only take M5 long breakout trades when **H1 Velocity is positive and above +0.30**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufVel` | `INDICATOR_DATA` | Normalized Directional Velocity Vector ($\vec{V}$) |
| **1** | `BufCol` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufSpeedPos` | `INDICATOR_DATA` | Symmetrical Top Speed Envelope ($+S$) |
| **3** | `BufSpeedNeg` | `INDICATOR_DATA` | Symmetrical Bottom Speed Envelope ($-S$) |
| **4** | `BufSignal` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors via `iCustom()`.*
