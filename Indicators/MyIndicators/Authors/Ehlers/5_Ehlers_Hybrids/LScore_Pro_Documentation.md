# John Ehlers' Laguerre Z-Score (L-Score) Pro (v3.00)

Quantitative Time-Warped Statistical Dispersion & Laguerre Elasticity Oscillator Suite

---

## 1. Summary (Introduction)

**L-Score Pro** is an institutional-grade statistical momentum oscillator that measures price deviation from **John Ehlers' 4-element Laguerre Filter** normalized in standardized units of standard deviation ($\sigma$).

While traditional Z-Score indicators measure dispersion relative to rigid, lagging moving averages (such as SMA or EMA), **L-Score utilizes an orthogonal, time-warped Laguerre baseline**. Because the Laguerre filter tracks trend inflection with near-zero phase lag, L-Score accurately separates sustainable trend-following momentum from extreme, over-extended statistical climaxes without lag-induced distortion.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        L-SCORE DISPERSION MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  L-Score(t) = [ Price(t) - Laguerre(t) ] / StdDev(Price - Laguerre, N) │
│  Expressed in standardized Sigma Multiples (σ)                         │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Time-Warped Laguerre Baseline:** Evaluates dispersion against Ehlers' 4-register low-pass filter ($L_0 \dots L_3$).
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter sensitivity with natural golden ratios (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* **Swapped Thermal 5-Zone Color Palette:** Distinguishes between neutral equilibrium noise, healthy institutional flow, and unsustainable statistical exhaustion climax.
* **Integrated Signal Smoothing Engine:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) directly over the L-Score histogram.
* **Unified 2026 MTF Architecture:** Enables higher-timeframe L-Score histograms (e.g., M15 or H1 L-Score) to map seamlessly onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Computes dispersion from filtered Heikin Ashi candles via `CLaguerreEngine_HA` composition.

---

## 2. Mathematical Foundations & Laguerre Dispersion

```text

                           +2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (Laguerre Equilibrium Mean)
          ───────────────────────────────────────────────────────────── Gray (Noise / Equilibrium)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. The Laguerre Equilibrium Mean ($\mu_{\text{Laguerre}, t}$)

Given dampening coefficient $\gamma = \text{InpGamma}$ and four recursive state registers:
$$L_0(t) = (1 - \gamma) P_t + \gamma L_0(t-1)$$
$$L_1(t) = -\gamma L_0(t) + L_0(t-1) + \gamma L_1(t-1)$$
$$L_2(t) = -\gamma L_1(t) + L_1(t-1) + \gamma L_2(t-1)$$
$$L_3(t) = -\gamma L_2(t) + L_2(t-1) + \gamma L_3(t-1)$$

$$\mu_{\text{Laguerre}, t} = \frac{L_0(t) + 2 \cdot L_1(t) + 2 \cdot L_2(t) + L_3(t)}{6}$$

---

### 2.2. Rolling Standard Deviation Around Laguerre Baseline ($\sigma_t$)

Given lookback period $P = \text{InpPeriod}$:
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( P_{t-k} - \mu_{\text{Laguerre}, t} \right)^2}$$

### 2.3. Standardized L-Score Metric

$$L\text{Score}_t = \begin{cases} \frac{P_t - \mu_{\text{Laguerre}, t}}{\sigma_t}, & \text{if } \sigma_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.4. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Institutional Market Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Equilibrium** | $\|L\text{Score}\| \le 1.5\sigma$ | Normal distribution around Laguerre; trend in balance. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < L\text{Score} \le +2.0\sigma$ | Healthy upward momentum expansion. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $L\text{Score} > +2.0\sigma$ | Parabolic blow-off top; tighten stops / scale out. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le L\text{Score} < -1.5\sigma$ | Healthy downward momentum expansion. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $L\text{Score} < -2.0\sigma$ | Panic capitulation floor; cover shorts / prepare bounce. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  Laguerre_Engine.mqh                   │
│    (Core DSP Math: Computes L0..L3 States & Filter)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds Laguerre Filter Baseline
                           ▼
┌────────────────────────────────────────────────────────┐
│                  LScore_Calculator.mqh                 │
│   (Core Math Engine - Overloaded & Bounds-Protected)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs L-Score Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                     LScore_Pro.mq5                     │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferL (DATA)       │   • DataSync_Tools.mqh      │
│   • BufferColors (INDEX) │   • MovingAverage_Engine    │
│   • BufferSignal (DATA)  │   • Dynamic Sigma Levels    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Engine Hierarchy:** Separates DSP time-warp polynomial physics (`Laguerre_Engine.mqh`) from statistical Z-score dispersion modeling (`LScore_Calculator.mqh`).
2. **Leak-Free Pointer Protection:** Factory methods verify pointer validity (`CheckPointer`) and safely free memory before re-allocation on parameter updates.
3. **2026 MTF Framework with Staircase Solution:** Higher-timeframe L-Score histograms map into synchronized steps on lower-timeframe execution charts with zero step-warping.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Laguerre Baseline Settings

* `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Supports all 7 Standard and 7 Heikin Ashi modes).

### Volatility Lookback Settings

* `InpPeriod` (*default: `20`*): Lookback period ($P$) for computing standard deviation variance around the Laguerre baseline.

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels (Sigma Units)

* `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary (`LightSkyBlue`).
* `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary (`Coral`).
* `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
* `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
* `InpLevelExtremeHigh` (*default: `2.5`*): Extreme statistical exhaustion level.
* `InpLevelExtremeLow` (*default: `-2.5`*): Extreme statistical capitulation level.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                    L-SCORE INSTITUTIONAL PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Parabolic Climax Fade: Fade rejections when L-Score > +2.0σ and     │
│                           crosses below the Signal MA line.            │
│ 2. Momentum Flow Trend:   Enter in direction of trend when L-Score     │
│                           holds between +1.5σ and +2.0σ.               │
│ 3. Mean Reversion Target: Profit targets are anchored to the 0.0σ      │
│                           baseline (Laguerre Filter Equilibrium).      │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Parabolic Climax Mean Reversion ($\pm 2.0\sigma \dots \pm 2.5\sigma$)

* **Context:** A fast, aggressive impulse thrusts price away from the Laguerre mean, driving L-Score above $+2.0\sigma$ (`DeepSkyBlue`) or $+2.5\sigma$.
* **Short Trigger:** When the L-Score histogram bar prints lower than the previous bar and crosses **below** the Signal MA line $\rightarrow$ Enter Short targeting the Laguerre centerline ($0.0\sigma$).
* **Long Trigger:** When L-Score drops below $-2.0\sigma$ (`OrangeRed`) and crosses **above** the Signal MA line $\rightarrow$ Enter Long targeting the Laguerre centerline ($0.0\sigma$).

### 5.2. Multi-Timeframe Momentum Confirmation

* Attach an **M15-calculated L-Score ($\gamma=0.618$)** onto an **M5 execution chart**.
* When M15 L-Score holds above $+1.5\sigma$ (`LightSkyBlue`), higher-timeframe momentum is expanding $\rightarrow$ Focus exclusively on lower-timeframe long continuation pullbacks on M5.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferL` | `INDICATOR_DATA` | Standardized L-Score Values in Sigma Multiples ($\sigma$) |
| **1** | `BufferColors` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignal` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
