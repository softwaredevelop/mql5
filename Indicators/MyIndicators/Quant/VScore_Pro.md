# Volume-Weighted Z-Score (V-Score) Pro (v3.00)

Quantitative Volume-Weighted Dispersion & Institutional Fair-Value Oscillator

---

## 1. Summary (Introduction)

**V-Score Pro** is an institutional-grade statistical momentum oscillator that measures price deviation from the **Volume-Weighted Average Price (VWAP)** normalized in standardized units of standard deviation ($\sigma$).

While standard Z-Score indicators measure distance from unweighted, lagging moving averages (such as SMA or EMA), **V-Score evaluates price against the market's true volume-weighted institutional fair value**. This allows systematic traders to quantify exactly how extreme a price move is relative to where actual transaction volume was committed.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        V-SCORE DISPERSION MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  V-Score(t) = [ Close(t) - VWAP(t) ] / StandardDeviation(Price - VWAP) │
│  Expressed in standardized Sigma Multiples (σ)                         │
└────────────────────────────────────────────────────────────────────────┘

```

### The Three Z-Score Indicator Paradigms

* **Z-Score Pro:** Measures Gaussian dispersion from a static Moving Average (Price/Time axis).
* **K-Score Pro:** Measures kinetic elasticity from Kaufman's Adaptive Moving Average (Efficiency/Regime axis).
* **V-Score Pro:** Measures statistical overextension from the Volume-Weighted Average Price (Volume/Liquidity axis).

### Key Capabilities

* **True Volume-Weighted Mean:** Evaluates price distance from Session, Weekly, Monthly, or Custom Session VWAPs.
* **Swapped Thermal 5-Zone Color Palette:** Distinguishes between neutral consolidation noise, healthy institutional flow, and unsustainable statistical exhaustion climax.
* **Integrated Signal Smoothing Engine:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) directly over the V-Score histogram.
* **Unified 2026 MTF Architecture:** Enables higher-timeframe V-Score histograms (e.g., M15 or H1 V-Score) to map seamlessly onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps via `DataSync_Tools.mqh`.

---

## 2. Mathematical Foundations & Volume-Weighted Dispersion

```text

                           +2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (VWAP Institutional Fair Value)
          ───────────────────────────────────────────────────────────── Gray (Noise / Fair Value)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. Volume-Weighted Mean ($\mu_{\text{VWAP}, t}$)

$$\mu_{\text{VWAP}, t} = \frac{\sum_{k=\text{anchor}}^{t} \text{TP}_k \cdot V_k}{\sum_{k=\text{anchor}}^{t} V_k}$$
*where $\text{TP}_k = \frac{H_k + L_k + C_k}{3}$ (Typical Price) and $V_k$ is the applied volume.*

### 2.2. Rolling Standard Deviation Around VWAP ($\sigma_t$)

Given a volatility lookback period $P = \text{InpPeriod}$:
$$\text{Diff}_k = C_k - \mu_{\text{VWAP}, k}$$
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( \text{Diff}_{t-k} \right)^2}$$

### 2.3. Normalized V-Score Formulation

$$V\text{Score}_t = \begin{cases} \frac{C_t - \mu_{\text{VWAP}, t}}{\sigma_t}, & \text{if } \sigma_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.4. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Institutional Market Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Neutral** | $\|V\text{Score}\| \le 1.5\sigma$ | Price oscillating within fair-value equilibrium. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < V\text{Score} \le +2.0\sigma$ | Institutional buying pressure actively expanding. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $V\text{Score} > +2.0\sigma$ | Statistical overbought climax; liquidity exhaustion warning. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le V\text{Score} < -1.5\sigma$ | Institutional selling pressure actively expanding. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $V\text{Score} < -2.0\sigma$ | Panic capitulation floor; short-covering bounce potential. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  VScore_Calculator.mqh                 │
│   (Core Math Engine - Overloaded & Bounds-Protected)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs V-Score Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                     VScore_Pro.mq5                     │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • ExtVScoreBuffer      │   • DataSync_Tools.mqh      │
│   • ExtColorsBuffer      │   • MovingAverage_Engine    │
│   • ExtSignalBuffer      │   • Dynamic Sigma Levels    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Overloaded Engine Architecture:** `CVScoreCalculator` supports legacy initialization signatures alongside enhanced Custom Session, Timezone Shift, and Heikin Ashi configurations.
2. **Bounds-Safe Auto-Resizing:** Prevents runtime array-out-of-range errors during real-time tick recalculations and MTF array copying.
3. **2026 MTF Framework (`DataSync_Tools.mqh`):** Higher-timeframe V-Score histograms map into synchronized steps on lower-timeframe execution charts with zero step-warping.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it runs in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### V-Score Settings

* `InpPeriod` (*default: `20`*): Lookback period ($P$) for computing standard deviation variance around VWAP.
* `InpVWAPReset` (*default: `PERIOD_SESSION`*): VWAP anchor mode (`PERIOD_SESSION`, `PERIOD_WEEK`, `PERIOD_MONTH`, `PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align resets with broker server time.
* `InpCustomSessionStart` (*default: `"09:30"`*): Session start time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.
* `InpCustomSessionEnd` (*default: `"16:00"`*): Session end time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.

### Calculation Settings

* `InpVolumeType` (*default: `VOLUME_TICK`*): Volume data source (`VOLUME_TICK` or `VOLUME_REAL`).
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price series source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels (Sigma Units)

* `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary.
* `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary.
* `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
* `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
* `InpLevelExtremeHigh` (*default: `2.5`*): Extreme statistical overextension level.
* `InpLevelExtremeLow` (*default: `-2.5`*): Extreme statistical capitulation level.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                    V-SCORE INSTITUTIONAL PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Institutional Climax Fade: Fade rejections when V-Score > +2.0σ     │
│                               and crosses below the Signal MA line.    │
│ 2. Volume Flow Continuation:  Enter in direction of trend when V-Score │
│                               holds between +1.5σ and +2.0σ.           │
│ 3. Mean Reversion to VWAP:    Targets are strictly anchored to the     │
│                               0.0σ baseline (VWAP Equilibrium).        │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Institutional Climax Mean Reversion ($\pm 2.0\sigma \dots \pm 2.5\sigma$)

* **Context:** A rapid price expansion pushes V-Score beyond $+2.0\sigma$ (`DeepSkyBlue`) or $+2.5\sigma$. This signifies that price is trading at a statistically unsustainable premium relative to committed volume.
* **Trigger:** When the V-Score histogram bar prints lower than the previous bar and crosses **below** the Signal MA line $\rightarrow$ Enter Short targeting the VWAP centerline ($0.0\sigma$).
* **Bullish Reversal:** When V-Score drops below $-2.0\sigma$ (`OrangeRed`) and crosses **above** the Signal MA line $\rightarrow$ Enter Long targeting VWAP ($0.0\sigma$).

### 5.2. Multi-Timeframe Volume Expansion Alignment

* Attach an **M15-calculated V-Score** onto an **M5 execution chart**.
* When M15 V-Score holds above $+1.5\sigma$ (`LightSkyBlue`), higher-timeframe institutional volume is actively supporting the markup phase $\rightarrow$ Focus exclusively on intraday long pullback entries on M5.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `ExtVScoreBuffer` | `INDICATOR_DATA` | Standardized V-Score Values in Sigma Multiples ($\sigma$) |
| **1** | `ExtColorsBuffer` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `ExtSignalBuffer` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
