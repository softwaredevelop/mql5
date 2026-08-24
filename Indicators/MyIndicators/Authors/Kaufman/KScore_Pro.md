# Kaufman's Adaptive Z-Score (K-Score) Pro (v1.00)

Statistical Adaptive Dispersion & Kinetic Elasticity Oscillator

---

## 1. Summary (Introduction)

**K-Score Pro** is an advanced statistical momentum oscillator that measures price deviation from **Perry Kaufman's Adaptive Moving Average (KAMA)** normalized in units of standard deviation ($\sigma$).

While traditional Z-Score indicators compute dispersion relative to rigid, lagging baselines (such as SMA or EMA), **K-Score replaces the static mean with a non-linear, regime-switching baseline**. This fundamentally transforms how statistical overbought and oversold states are interpreted:

* **In Healthy Trends:** The KAMA baseline dynamically accelerates alongside price action. Consequently, K-Score remains within sustainable equilibrium bounds ($+0.5\sigma \dots +1.5\sigma$) rather than getting trapped in perpetual, false "overbought" readings.
* **During Parabolic Blow-Offs:** If price accelerates faster than KAMA's maximum internal adaptation speed, the statistical "rubber band" stretches to extremes ($> +2.0\sigma \dots +2.5\sigma$), signaling a genuine kinetic climax.
* **In Low-Efficiency Consolidations:** The KAMA baseline flattens completely into a horizontal line. Sudden price spikes outside the range produce instant $+2.0\sigma$ warnings, accurately identifying false breakouts and liquidity sweeps.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        K-SCORE DISPERSION MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  K-Score = [ Price(t) - KAMA(t) ] / StandardDeviation(Price - KAMA, N) │
│  Expressed in standardized Sigma Multiples (σ)                         │
└────────────────────────────────────────────────────────────────────────┘

```

---

## 2. Mathematical Foundations & Kinetic Dynamics

```text

                           +2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (KAMA Equilibrium Mean)
          ───────────────────────────────────────────────────────────── Gray (Noise / Equilibrium)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. Mathematical Formulation

#### 1. Adaptive Equilibrium Baseline ($\mu_t$)

$$\mu_t = \text{KAMA}_t(\text{ER}, \text{Fast}, \text{Slow}, \text{Price})$$

#### 2. Dispersion Variance Around KAMA

Given a standard deviation lookback window $P_\sigma = \text{InpStDevPeriod}$:
$$\sigma_t = \sqrt{\frac{1}{P_\sigma} \sum_{k=0}^{P_\sigma - 1} \left( P_{t-k} - \mu_t \right)^2}$$

#### 3. Standardized K-Score Metric

$$K\text{Score}_t = \begin{cases} \frac{P_t - \mu_t}{\sigma_t}, & \text{if } \sigma_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.2. The Regime Duality Matrix (Why K-Score is Unique)

| Market Environment | KAMA Baseline Behavior | K-Score Interpretation | Strategic Value |
| :--- | :--- | :--- | :--- |
| **Established Trend** | Accelerates with price ($\text{SC} \approx \alpha_{\text{fast}}$) | Stays moderate ($+0.5\sigma \dots +1.5\sigma$) | **Trend Retention:** Prevents premature exits during strong trend runs. |
| **Parabolic Blow-off** | Price outruns fastest KAMA speed | Spikes to $> +2.0\sigma \dots +2.5\sigma$ | **Climax Warning:** Identifies unsustainable exhaustion spikes. |
| **Sideways Range** | Flattens into horizontal axis ($\text{SC} \approx \alpha_{\text{slow}}$) | Acts as a pure Gaussian range envelope | **Liquidity Trap Alert:** Identifies range-edge fades and fakeouts. |

---

### 2.3. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Contextual Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Equilibrium** | $\|\text{K-Score}\| \le 1.5\sigma$ | Normal distribution around KAMA; trend in balance. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < \text{K-Score} \le +2.0\sigma$ | Healthy upward impulse expansion. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $\text{K-Score} > +2.0\sigma$ | Parabolic blow-off top; tighten stops / scale out. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le \text{K-Score} < -1.5\sigma$ | Healthy downward impulse expansion. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $\text{K-Score} < -2.0\sigma$ | Panic capitulation floor; cover shorts / prepare bounce. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  KScore_Calculator.mqh                 │
│   (Core Math Engine - Encapsulated CKamaCalculator)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Computes K-Score Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                     KScore_Pro.mq5                     │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferKScore (DATA)  │   • DataSync_Tools.mqh      │
│   • BufferColors (INDEX) │   • MovingAverage_Engine    │
│   • BufferSignal (DATA)  │   • Dynamic Sigma Levels    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Embedded Engine Composition:** `CKScoreCalculator` encapsulates `CKamaCalculator` and `CHeikinAshi_Calculator` directly via composition, eliminating external memory leaks and pointer overhead.
2. **2026 MTF Framework with DataSync Daemon:**
   * Multi-timeframe synchronization is handled asynchronously via `DataSync_Tools.mqh` through a 1-second `OnTimerUpdate` daemon.
   * **Forming LTF Block Flat-Force (Staircase Solution):** The mapping anchor dynamically resets to `first_bar_of_forming_htf`, ensuring all sub-bars of the active higher-timeframe candle update in real-time without visual distortion.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): The lookback window ($N$) used for the KAMA Efficiency Ratio.
* `InpFastEmaPeriod` (*default: `2`*): Fastest smoothing period ($F$) during high directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): Slowest smoothing period ($S$) during consolidation.
* `InpStDevPeriod` (*default: `20`*): Lookback period ($P_\sigma$) for computing standard deviation variance around KAMA.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Standard OHLC or Synthetic Heikin Ashi).

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line.

### Indicator Levels (Sigma Units)

* `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary.
* `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary.
* `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
* `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
* `InpLevelExtremeHigh` (*default: `2.5`*): Extreme statistical over-extension level.
* `InpLevelExtremeLow` (*default: `-2.5`*): Extreme statistical panic level.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Quantitative Trading Strategies (Contextual Role)

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HOW TO USE K-SCORE IN A LIVE SYSTEM                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Trend Filter:     Use KAMA_Pro on Main Chart for Direction.         │
│ 2. Momentum Trigger: Use KAMA_Slope_Pro for Entry Acceleration.        │
│ 3. Elasticity Guard: Use K-Score_Pro to Prevent Buying Top / Selling   │
│                      Bottom (Filter out trades when > +2.0σ / < -2.0σ).│
│ 4. Climax Exit:      Take profit when K-Score hits +2.5σ and crosses   │
│                      back below Signal Line.                           │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The Parabolic Climax Filter (Trade Invalidation)

* **Rule:** Do **NOT** initiate new trend-following long positions if `K-Score > +2.0σ` (DeepSkyBlue), even if `KAMA_Slope_Pro` is strong green. The price is over-extended relative to its adaptive baseline and is prone to a sharp mean-reverting snapback.
* **Rule:** Do **NOT** initiate new short breakout positions if `K-Score < -2.0σ` (OrangeRed).

### 5.2. Mean-Reversion Exhaustion Exit

* **Long Exit Trigger:** Price is in an uptrend, K-Score exceeds $+2.0\sigma$ or $+2.5\sigma$, and then crosses **below** the Signal MA line $\rightarrow$ Institutional signal to close long positions or lock in partial profits.
* **Short Exit Trigger:** Price is in a downtrend, K-Score drops below $-2.0\sigma$ or $-2.5\sigma$, and then crosses **above** the Signal MA line $\rightarrow$ Institutional signal to cover short positions.

### 5.3. Range Liquidity Sweep Trap (The Fakeout Reversal)

* **Context:** `KAMA_Pro` is flat (Gray Slope).
* **Setup:** A news spike thrusts price outside the range, driving K-Score to $+2.2\sigma$.
* **Execution:** If the next candle fails to sustain momentum and closes back inside the range while K-Score drops below $+1.5\sigma$, fade the move back toward the KAMA centerline ($0.0\sigma$).

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferKScore` | `INDICATOR_DATA` | Standardized K-Score Values in Sigma Multiples ($\sigma$) |
| **1** | `BufferColors` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignal` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
