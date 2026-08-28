# Ehlers Smoother Pro (v3.00)

Quantitative Digital Signal Processing (DSP) Smoothing & Low-Lag Filter Suite

---

## 1. Summary (Introduction)

**Ehlers Smoother Pro** is an institutional-grade trend and smoothing filter that implements two of John Ehlers' most advanced Digital Signal Processing (DSP) algorithms: the **SuperSmoother** and the **UltimateSmoother**.

Traditional moving averages (such as SMA, EMA, or SMMA) suffer from an unavoidable mathematical trade-off: increasing smoothing to eliminate market noise introduces severe phase lag, while shortening periods to reduce lag creates false breakout whipsaws. John Ehlers resolved this dilemma by applying electronic filter theory to financial time series, modeling price action through critically damped **Infinite Impulse Response (IIR)** low-pass transfer functions.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                      EHLERS SMOOTHER FILTER SUITE                      │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Filter Model     │   Filter Architecture  │   Optimal Use-Case     │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ SuperSmoother        │ 2-Pole Butterworth     │ Maximum Noise Filter   │
│                      │ Critical Damping       │ (Optimal EMA Alternate)│
├──────────────────────┼────────────────────────┼────────────────────────┤
│ UltimateSmoother     │ High-Pass Subtraction  │ Near-Zero Phase Lag    │
│                      │ Modified Transfer Func │ (Dynamic S/R & Pullback)│
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **2-in-1 Adaptive Engine:** Instantly switch between maximum noise attenuation (`SUPERSMOOTHER`) and ultra-responsive low-lag tracking (`ULTIMATESMOOTHER`).
* **Analytical Coefficient Tuning:** Filter parameters scale continuously from the user-defined `Period` ($P$) without heuristic curve-fitting.
* **Unified 2026 MTF Framework:** Higher-timeframe Ehlers curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CHeikinAshi_Calculator` composition.
* **Incremental $O(1)$ Execution:** Stateful recursive registers update in zero latency on live market ticks without historical recalculation bloat.

---

## 2. Mathematical Foundations & DSP Filter Theory

```text

                  RAW PRICE (Market Noise & Aliasing)
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │         2-Pole Butterworth Transfer Function           │
      │    Cutoff Frequency: ω_c = (√2 · π) / Period           │
      └───────────────────────────┬────────────────────────────┘
                                  │
                  Filtered Low-Frequency Trendline

```

### 2.1. Analytical DSP Filter Coefficients

For a selected cutoff period $P = \text{InpPeriod}$, the damping factors are calculated analytically:
$$a_1 = \exp\left( -\frac{\sqrt{2} \cdot \pi}{P} \right)$$
$$b_1 = 2 \cdot a_1 \cdot \cos\left( \frac{\sqrt{2} \cdot \pi}{P} \right)$$
$$c_2 = b_1, \quad\quad c_3 = -a_1^2$$

---

### 2.2. Filter Difference Equations

#### 1. The SuperSmoother Filter

The SuperSmoother is a second-order Butterworth low-pass filter engineered to suppress high-frequency market noise while strictly preventing transient overshoot:
$$c_1 = 1 - c_2 - c_3$$
$$\text{Filt}_t = c_1 \cdot \left( \frac{P_t + P_{t-1}}{2} \right) + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

#### 2. The UltimateSmoother Filter

The UltimateSmoother is derived by mathematically subtracting the high-pass filter response from the raw price series, achieving near-zero phase lag in the dominant trend component:
$$c_1 = \frac{1 + c_2 - c_3}{4}$$
$$\text{Filt}_t = (1 - c_1) P_t + (2c_1 - c_2) P_{t-1} - (c_1 + c_3) P_{t-2} + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│              Ehlers_Smoother_Calculator.mqh            │
│   (Core DSP Math Engine - Encapsulated Heikin Ashi)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Computes Filter Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 Ehlers_Smoother_Pro.mq5                │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • Zero-Overhead Bypass │   • Non-Repainting Step Map │
└──────────────────────────┴─────────────────────────────┘

```

1. **Composition over Inheritance:** `CEhlersSmootherCalculator` encapsulates `CHeikinAshi_Calculator` directly via composition, ensuring type-safe handling for all 14 standard and Heikin Ashi price modes through a single, unified interface.
2. **2026 MTF Framework with Staircase Solution:**
   * **Asynchronous Data Guard:** Background 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe history readiness without chart freezing.
   * **Forming LTF Block Flat-Force Anchor:** The mapping start index snaps to `first_bar_of_forming_htf`, updating all lower-timeframe sub-bars of the live higher-timeframe candle simultaneously.
   * **State-Safe Live Bar Mocking:** Live forming HTF ticks are computed on index `g_htf_count - 1` without overwriting historical recursion registers.
3. **Definition-True Warmup Protection:** Recursion registers are seeded cleanly with raw prices on bars 0..2 during initialization, preventing floating-point overflow spikes.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Smoother Settings

* `InpSmootherType` (*default: `SUPERSMOOTHER`*): Filter model selection (`SUPERSMOOTHER` or `ULTIMATESMOOTHER`).
* `InpPeriod` (*default: `20`*): The critical cutoff period ($P$). Higher values produce smoother, slower curves; lower values increase responsiveness.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Visual Settings

* `InpColorFilter` (*default: `clrBlueViolet`*): Color of the filter plot line.
* `InpStyleFilter` (*default: `STYLE_SOLID`*): Line style (Solid, Dash, Dot).
* `InpWidthFilter` (*default: `2`*): Line thickness.

---

## 5. Quantitative Trading Strategies & Filter Selection

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   FILTER SELECTION & USAGE MATRIX                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. SuperSmoother (Clarity): Use as a superior EMA replacement for      │
│                             macro trend filtering and bias definition. │
│ 2. UltimateSmoother (Speed): Use as an ultra-fast dynamic support and   │
│                             resistance line for high-precision entries.│
│ 3. MTF Macro Alignment:     Attach an H1/H4 SuperSmoother on an M5     │
│                             execution chart to trade institutional flow│
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. SuperSmoother: The Macro Noise-Free Trend Baseline

* **Best Applied For:** Swing trading, macro trend filtering, and replacement for traditional 20/50/200 EMAs.
* **Interpretation:**
  * **Bullish Regime:** Price trading consistently above a rising SuperSmoother line.
  * **Bearish Regime:** Price trading consistently below a falling SuperSmoother line.
  * **Flat Regime:** When the curve flattens horizontally, the market is in consolidation; pause trend-following breakout strategies.

### 5.2. UltimateSmoother: Ultra-Responsive Dynamic S/R

* **Best Applied For:** Intraday scalping, fast pullbacks, and tight trailing stop-loss management.
* **Interpretation:**
  * Due to its near-zero phase lag transfer function, pullbacks into the UltimateSmoother line during established trends represent high-conviction continuation entry zones with minimal drawdown.

### 5.3. Multi-Timeframe Confluence Execution

* Load an **H1-calculated SuperSmoother** onto an **M5 execution chart**.
* The flat, synchronized steps provide an unpainted macro institutional baseline:
  * Only execute M5 long pullbacks when price is above the H1 SuperSmoother step.
  * Only execute M5 short pullbacks when price is below the H1 SuperSmoother step.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferFilter` | `INDICATOR_DATA` | Smoothed Filter Plot Line (SuperSmoother / UltimateSmoother) |

*The buffer strictly maintains non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
