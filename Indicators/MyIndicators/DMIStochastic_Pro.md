# Barbara Star's DMI Stochastic Oscillator Pro (v3.00)

Quantitative Trend-Momentum Hybrid & Directional Stochastic Oscillator Suite

---

## 1. Summary (Introduction)

**DMI Stochastic Pro** is an institutional-grade trend-momentum hybrid oscillator developed by technical analyst Barbara Star. It synthesizes **J. Welles Wilder Jr.'s Directional Movement System (+DI / -DI)** with **George Lane's Stochastic Oscillator formula**.

Standard price-based Stochastics suffer from severe premature exhaustion in strong trends: because raw price continuously makes new highs, standard Stochastics gets pinned in "overbought" territory for extended periods. **Barbara Star resolved this by applying Stochastic normalization directly to the DMI Oscillator ($+DI - -DI$) rather than raw price**:

* **Directional Balance ($50.0$ Level):** When %K is above $50.0$, buyers dominate the directional market structure (+DI > -DI). When %K is below $50.0$, sellers dominate (-DI > +DI).
* **True Momentum Exhaustion ($\ge 80.0 / \le 20.0$):** Identifies when the relative dominance of buyers or sellers has reached a statistical local extreme and is beginning to decelerate.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   DMI STOCHASTIC HYBRID ARCHITECTURE                   │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ %K Main Line         │ clrDodgerBlue (Width:2)│ Directional Momentum   │
│ %D Signal Line       │ clrCoral (Width:1)     │ Smoothed Trigger Line  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **0–100 Bounded Hybrid Scale:** Maps unbounded directional momentum into standardized institutional overbought/oversold bands.
* **Flexible Dual-Engine Smoothing:** Independent Moving Average smoothing methods for both %K Slowing and %D Signal lines (supports SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA).
* **Unified 2026 MTF Framework:** Higher-timeframe DMI Stochastic curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Computes smoothed directional vectors from synthetic Heikin Ashi candles via `CDMIStochasticCalculator_HA`.
* **Dynamic 5-Level Grid:** Fully customizable horizontal thresholds ($10, 20, 50, 80, 90$).

---

## 2. Mathematical Foundations & Hybrid Synthesis

```text

                 Wilder's DMI (+DI and -DI) over Period P_DMI
                                      │
                                      ▼
             DMI Oscillator = (+DI) - (-DI)  (Ranges: -100 to +100)
                                      │
                                      ▼
            Stochastic Normalization over Fast %K Period (0 to 100)
               Fast %K = [ (DMI Osc - Lowest) / Range ] × 100
                                      │
                                      ▼
                 Slow %K = MA(Fast %K, Period = SlowK, Method = K_MA)
                                      │
                                      ▼
                 %D Signal = MA(Slow %K, Period = Smooth, Method = D_MA)

```

### 2.1. The DMI Difference Oscillator

$$\text{DMI Oscillator}_t = \begin{cases} (+DI_t) - (-DI_t), & \text{if } \text{InpOscType} = \text{OSC\_PDI\_MINUS\_NDI} \\ (-DI_t) - (+DI_t), & \text{if } \text{InpOscType} = \text{OSC\_NDI\_MINUS\_PDI} \end{cases}$$

---

### 2.2. Fast %K Stochastic Normalization

Across the lookback window $P_{\text{FastK}} = \text{InpFastKPeriod}$:
$$\text{Highest}_t = \max_{j=0 \dots P_{\text{FastK}}-1} \left( \text{DMI Oscillator}_{t-j} \right)$$
$$\text{Lowest}_t = \min_{j=0 \dots P_{\text{FastK}}-1} \left( \text{DMI Oscillator}_{t-j} \right)$$
$$\text{Range}_t = \text{Highest}_t - \text{Lowest}_t$$

$$\text{Fast \%K}_t = \begin{cases} \left( \frac{\text{DMI Oscillator}_t - \text{Lowest}_t}{\text{Range}_t} \right) \times 100, & \text{if } \text{Range}_t > 10^{-9} \\ 50.0, & \text{if } \text{Range}_t = 0 \end{cases}$$

---

### 2.3. Slow %K (Main Line) & %D (Signal Line) Smoothing

The raw Fast %K is smoothed using the user-defined moving average algorithm ($\mathcal{MA}$):
$$\text{\%K}_t = \mathcal{MA}\left( \text{Fast \%K}, \text{Period} = \text{InpSlowKPeriod}, \text{Type} = \text{InpStochMethod} \right)$$

The final signal line is produced by smoothing the %K series:
$$\text{\%D}_t = \mathcal{MA}\left( \text{\%K}, \text{Period} = \text{InpSmoothPeriod}, \text{Type} = \text{InpSignalMethod} \right)$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                     DMI_Engine.mqh                     │
│        (Core Math: Computes +DI and -DI Series)        │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds +DI & -DI Series
                           ▼
┌────────────────────────────────────────────────────────┐
│               DMIStochastic_Calculator.mqh             │
│    (DMI Difference & Fast %K Stochastic Normalizer)    │
├──────────────────────────┬─────────────────────────────┤
│   MovingAverage_Engine   │   Dual MA Smoothing Engine  │
│   • Slow %K Calculator   │   • %D Signal Calculator    │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs %K and %D in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 DMIStochastic_Pro.mq5                  │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **4-Tier Modular Hierarchy:** Isolates raw Directional Movement (`DMI_Engine.mqh`) from moving average smoothing (`MovingAverage_Engine.mqh`), orchestrated through `DMIStochastic_Calculator.mqh`.
2. **Leak-Free Pointer Protection:** Factory methods (`CreateEngine`) safely delete previous engine instances before allocating new ones.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### DMI & Stochastic Settings

* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).
* `InpOscType` (*default: `OSC_PDI_MINUS_NDI`*): Formula polarity (`OSC_PDI_MINUS_NDI` for Bullish-dominant scaling, `OSC_NDI_MINUS_PDI` for Bearish-dominant scaling).
* `InpDMIPeriod` (*default: `10`*): Wilder's smoothing lookback period for DMI calculations.
* `InpFastKPeriod` (*default: `10`*): Lookback period for Stochastic normalization.
* `InpSlowKPeriod` (*default: `3`*): Smoothing period for the %K main line.
* `InpStochMethod` (*default: `SMA`*): Smoothing method for %K (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSmoothPeriod` (*default: `3`*): Smoothing period for the %D signal line.
* `InpSignalMethod` (*default: `SMA`*): Smoothing method for %D.

### Indicator Levels (0–100 Range)

* `InpLevelExtrHigh` (*default: `90.0`*): Extreme Overbought Climax boundary.
* `InpLevelHigh` (*default: `80.0`*): Overbought Warning threshold.
* `InpLevelMid` (*default: `50.0`*): Directional Equilibrium threshold (+DI = -DI).
* `InpLevelLow` (*default: `20.0`*): Oversold Warning threshold.
* `InpLevelExtrLow` (*default: `10.0`*): Extreme Oversold Climax boundary.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorK` (*default: `clrDodgerBlue`*): %K line color (Width: 2, Solid).
* `InpColorD` (*default: `clrCoral`*): %D signal line color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   DMI STOCHASTIC TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 50-Line Equilibrium Cross: %K crossing > 50 confirms Bullish Flow.  │
│                               %K crossing < 50 confirms Bearish Flow.  │
│ 2. Signal Crossover Trigger:  %K crosses %D while in 20-80 zone in     │
│                               direction of dominant trend.             │
│ 3. Deep Climax Reversal:      %K exiting > 90 / < 10 extreme boundaries│
│                               signals exhaustion mean-reversion.       │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The 50-Level Directional Regime Filter

* **Bullish Dominance:** When `%K > 50.0`, buyers hold directional control (+DI > -DI). Only take long setups.
* **Bearish Dominance:** When `%K < 50.0`, sellers hold directional control (-DI > +DI). Only take short setups.

### 5.2. Trend-Following Signal Line Crossovers (%K / %D)

* **Bullish Continuation Trigger:** Price is in an established uptrend (Price > KAMA or 20 EMA), %K pulls back toward the 50.0 line, and crosses **above %D** $\rightarrow$ Enter Long.
* **Bearish Continuation Trigger:** Price is in a downtrend, %K rallies toward 50.0, and crosses **below %D** $\rightarrow$ Enter Short.

### 5.3. Multi-Timeframe Confluence Execution

* Attach an **H1-calculated DMI Stochastic** onto an **M5 execution chart**.
* **Rule:** Only take M5 long breakout/pullback entries when **H1 %K is above 50.0 and rising**. This eliminates counter-trend traps against higher-timeframe institutional momentum.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferK` | `INDICATOR_DATA` | DMI Stochastic %K (Main Directional Line) |
| **1** | `BufferD` | `INDICATOR_DATA` | DMI Stochastic %D (Signal Trigger Line) |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
