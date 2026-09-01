# William Blau's True Strength Index (TSI) Combo Pro (v3.10)

Quantitative Double-Smoothed Momentum, Signal Line & Oscillator Tri-Plot Suite

---

## 1. Summary (Introduction)

**TSI Combo Pro** is an institutional-grade momentum oscillator developed by technical analyst William Blau. It solves the high-frequency noise problem of standard momentum indicators by applying a **two-stage recursive double-smoothing algorithm** to both directional price momentum and absolute price momentum.

Unlike single-smoothed oscillators (such as traditional RSI or Rate of Change), **TSI eliminates false noise whipsaws while preserving responsive trend inflection turning points**. The "Combo" edition unifies three essential momentum perspectives into a single subwindow:

1. **Main TSI Line:** The normalized, double-smoothed momentum curve oscillating around the $0.0$ baseline within theoretical bounds of $-100.0$ to $+100.0$.
2. **Signal Trigger Line:** A smoothed moving average of the TSI line used for precise entry and exit timing.
3. **Oscillator Histogram:** A MACD-style difference histogram ($\text{TSI} - \text{Signal}$) displaying instantaneous momentum acceleration and deceleration.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        TSI COMBO TRI-PLOT SUITE                        │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Output Plot      │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Oscillator Histogram │ clrSilver (Width:1)    │ Momentum Acceleration  │
│ Main TSI Line        │ clrDodgerBlue (Width:2)│ Double-Smoothed Trend  │
│ Signal Trigger Line  │ clrOrangeRed (Width:1) │ Smoothed Crossover Line│
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Double-Smoothed Momentum Engine:** Eradicates high-frequency market noise through two sequential moving average filters.
* **Full Volume-Weighted (VWMA) Support:** Integrates real trade volume and tick volume across Slow, Fast, and Signal smoothing stages.
* **Unified 2026 MTF Framework:** Higher-timeframe TSI curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CTSICalculator_HA` composition.
* **Dynamic 6-Level Grid:** Fully customizable horizontal thresholds ($\pm 25.0, \pm 37.5, \pm 50.0$).

---

## 2. Mathematical Foundations & Double-Smoothing Mechanics

```text

                 RAW PRICE CHANGE: Momentum = Price(t) - Price(t - 1)
                 ABSOLUTE CHANGE:  |Momentum| = |Price(t) - Price(t - 1)|
                                      │
                                      ▼
             Stage 1: Slow MA Smoothing over Period P_Slow (e.g. 25 EMA)
                 EMA1_M   = MA( Momentum,   Period = Slow )
                 EMA1_Abs = MA( |Momentum|, Period = Slow )
                                      │
                                      ▼
             Stage 2: Fast MA Smoothing over Period P_Fast (e.g. 13 EMA)
                 EMA2_M   = MA( EMA1_M,   Period = Fast )
                 EMA2_Abs = MA( EMA1_Abs, Period = Fast )
                                      │
                                      ▼
                     TSI = [ EMA2_M / EMA2_Abs ] × 100
                                      │
                                      ▼
             Signal Line     = MA( TSI, Period = P_Signal )
             Oscillator Hist = TSI - Signal Line

```

### 2.1. Raw Momentum & Absolute Momentum

$$\Delta P_t = P_t - P_{t-1}$$
$$|\Delta P_t| = |P_t - P_{t-1}|$$

---

### 2.2. Stage 1: First Smoothing (Slow MA)

The 1-period momentum is smoothed over lookback period $P_{\text{Slow}} = \text{InpSlowPeriod}$:
$$\text{EMA1}_M(t) = \mathcal{MA}\left( \Delta P, \text{Period} = P_{\text{Slow}}, \text{Type} = \text{InpSlowMAType} \right)$$
$$\text{EMA1}_{|\Delta P|}(t) = \mathcal{MA}\left( |\Delta P|, \text{Period} = P_{\text{Slow}}, \text{Type} = \text{InpSlowMAType} \right)$$

---

### 2.3. Stage 2: Second Smoothing (Fast MA)

The first smoothed result is smoothed a second time over period $P_{\text{Fast}} = \text{InpFastPeriod}$:
$$\text{EMA2}_M(t) = \mathcal{MA}\left( \text{EMA1}_M, \text{Period} = P_{\text{Fast}}, \text{Type} = \text{InpFastMAType} \right)$$
$$\text{EMA2}_{|\Delta P|}(t) = \mathcal{MA}\left( \text{EMA1}_{|\Delta P|}, \text{Period} = P_{\text{Fast}}, \text{Type} = \text{InpFastMAType} \right)$$

---

### 2.4. The True Strength Index (TSI) Equation

$$\text{TSI}_t = \begin{cases} \left( \frac{\text{EMA2}_M(t)}{\text{EMA2}_{|\Delta P|}(t)} \right) \times 100, & \text{if } \text{EMA2}_{|\Delta P|}(t) > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.5. Signal Line & Oscillator Difference

$$\text{Signal}_t = \mathcal{MA}\left( \text{TSI}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalMAType} \right)$$
$$\text{Oscillator}_t = \text{TSI}_t - \text{Signal}_t$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                   TSI_Calculator.mqh                   │
│   (Core Math: Double-Smoothed Momentum & Volume Engine)│
├──────────────────────────┬─────────────────────────────┤
│   MovingAverage_Engine   │   Composition Engine        │
│   • 4 Momentum MAs       │   • CHeikinAshi_Calculator  │
│   • 1 Signal Line MA     │   • Full VWMA Routing       │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs TSI, Signal & Osc in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   TSI_Combo_Pro.mq5                    │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 3 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Integrated 5-Engine Composition:** `CTSICalculator` orchestrates four internal `CMovingAverageCalculator` engines for momentum double-smoothing plus a fifth engine for signal line generation.
2. **Full VWMA Volume Routing:** When `VWMA` is selected for Slow, Fast, or Signal smoothing, volume arrays (`h_vol[]` in MTF and `g_double_volume[]` in Native) are dynamically routed through all smoothing pipelines.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### TSI Core Settings

* `InpSlowPeriod` (*default: `25`*): Lookback period ($P_{\text{Slow}}$) for the first smoothing stage.
* `InpSlowMAType` (*default: `EMA`*): Smoothing algorithm for Stage 1 (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpFastPeriod` (*default: `13`*): Lookback period ($P_{\text{Fast}}$) for the second smoothing stage.
* `InpFastMAType` (*default: `EMA`*): Smoothing algorithm for Stage 2.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Signal Line Settings

* `InpSignalPeriod` (*default: `13`*): Smoothing period for the Signal line.
* `InpSignalMAType` (*default: `EMA`*): Smoothing method for Signal line.

### Indicator Levels

* `InpLevelWallHigh` (*default: `50.0`*): Extreme overbought climax level.
* `InpLevelExtrHigh` (*default: `37.5`*): Strong trend overbought level.
* `InpLevelOverbought` (*default: `25.0`*): Overbought warning threshold.
* `InpLevelOversold` (*default: `-25.0`*): Oversold warning threshold.
* `InpLevelExtrLow` (*default: `-37.5`*): Strong trend oversold level.
* `InpLevelWallLow` (*default: `-50.0`*): Extreme oversold climax level.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorTSI` (*default: `clrDodgerBlue`*): TSI line color (Width: 2, Solid).
* `InpColorSignal` (*default: `clrOrangeRed`*): Signal line color (Width: 1, Solid).
* `InpColorOsc` (*default: `clrSilver`*): Histogram difference color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     TSI COMBO TRADING PLAYBOOKS                        │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Centerline Regime Cross: TSI > 0 = Bullish Macro Trend Dominance.   │
│                             TSI < 0 = Bearish Macro Trend Dominance.   │
│ 2. Signal Line Crossover:   TSI crosses Signal line in direction of    │
│                             macro baseline (0.0 level).                │
│ 3. Histogram Divergence:    Histogram contracting while TSI is beyond  │
│                             ±25 / ±37.5 signals early exhaustion.      │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The 0.0 Centerline Macro Regime Filter

* **Bullish Dominance:** When `TSI > 0.0`, double-smoothed upward price changes exceed downward changes. Only seek long continuation setups.
* **Bearish Dominance:** When `TSI < 0.0`, double-smoothed downward price changes dominate. Only seek short continuation setups.

### 5.2. Trend-Following Signal Line Crossovers (TSI / Signal)

* **Bullish Trend Trigger:** `TSI > 0.0` AND `TSI` crosses **above Signal Line** while the Histogram expands positively $\rightarrow$ High-probability long trend entry.
* **Bearish Trend Trigger:** `TSI < 0.0` AND `TSI` crosses **below Signal Line** while the Histogram expands negatively $\rightarrow$ High-probability short trend entry.

### 5.3. Multi-Timeframe Macro Confluence

* Attach an **H1-calculated TSI Combo** onto an **M5 execution chart**.
* **Rule:** Only take M5 long pullback entries when **H1 TSI is above 0.0 AND above its H1 Signal line**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferOsc` | `INDICATOR_DATA` | Histogram Difference Plot ($\text{TSI} - \text{Signal}$) |
| **1** | `BufferTSI` | `INDICATOR_DATA` | Main True Strength Index (TSI) Line |
| **2** | `BufferSignal` | `INDICATOR_DATA` | Smoothed Signal Trigger Line |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
