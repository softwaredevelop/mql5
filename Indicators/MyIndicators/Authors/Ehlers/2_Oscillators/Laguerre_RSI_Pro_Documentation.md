# John Ehlers' Laguerre Relative Strength Index (Laguerre RSI) Pro (v3.00)

Quantitative Time-Warped Zero-Lag Momentum & Relative Strength Oscillator Suite

---

## 1. Summary (Introduction)

**Laguerre RSI Pro** is an institutional-grade non-linear momentum oscillator developed by aerospace engineer and quantitative trading pioneer John Ehlers.

In classical technical analysis, J. Welles Wilder Jr.'s standard Relative Strength Index (RSI) averages price gains and losses over a fixed 14-bar lookback window, introducing unavoidable phase lag and slow signal resolution. **John Ehlers resolved this by applying the RSI mathematical concept across four orthogonal Laguerre polynomial state registers ($L_0, L_1, L_2, L_3$)**:

* **Zero Historical Lookback Overhead:** Rather than calculating across $N$ price bars, Laguerre RSI evaluates the instantaneous directional displacement between the four Laguerre filter stages.
* **Near-Zero Phase Lag Inflections:** The time-warped all-pass transfer function enables the oscillator to recognize market cyclical turns with virtually zero phase delay.
* **Bounded 0–100 Scale with Clear Extremes:** Provides precise, non-lagging overbought ($\ge 80.0 / 90.0$) and oversold ($\le 20.0 / 10.0$) reversal thresholds.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                      LAGUERRE RSI OSCILLATOR SUITE                     │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Laguerre RSI Line    │ clrMediumTurquoise (W:2│ Main Momentum Curve    │
│ Signal Line          │ clrLightCoral (Width:1)│ Smoothed Trigger Line  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Time-Warped 4-Element RSI Synthesis:** Computes relative strength strictly from internal $L_0 \dots L_3$ polynomial stage differences.
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter sensitivity with golden ratio proportions (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* **Integrated Signal Smoothing Engine:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) for the signal trigger line.
* **Unified 2026 MTF Framework:** Higher-timeframe Laguerre RSI curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Computes smoothed momentum from filtered Heikin Ashi candles via `CLaguerreRSICalculator_HA` composition.

---

## 2. Mathematical Foundations & Laguerre RSI Mechanics

```text

                  RAW PRICE (Market Highs, Lows & Closes)
                                     │
                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │        4-Stage Orthogonal Laguerre State Engine        │
        │   L0(t) = (1 - γ)·P(t) + γ·L0(t - 1)                   │
        │   L1(t) = -γ·L0(t) + L0(t - 1) + γ·L1(t - 1)           │
        │   L2(t) = -γ·L1(t) + L1(t - 1) + γ·L2(t - 1)           │
        │   L3(t) = -γ·L2(t) + L2(t - 1) + γ·L3(t - 1)           │
        └────────────────────────────┬───────────────────────────┘
                                     │
                                     ▼
           CU = (L0 - L1 if > 0) + (L1 - L2 if > 0) + (L2 - L3 if > 0)
           CD = (L1 - L0 if > 0) + (L2 - L1 if > 0) + (L3 - L2 if > 0)
                                     │
                                     ▼
                     Laguerre RSI = [ CU / (CU + CD) ] × 100
                                     │
                                     ▼
             Signal Line = MA(Laguerre RSI, Period = Signal, Type = MA_Type)

```

### 2.1. The 4-Element Laguerre State Engine

Given input price $P_t$ and damping coefficient $\gamma = \text{InpGamma}$ ($0.0 \le \gamma \le 1.0$):
$$L_0(t) = (1 - \gamma) P_t + \gamma L_0(t-1)$$
$$L_1(t) = -\gamma L_0(t) + L_0(t-1) + \gamma L_1(t-1)$$
$$L_2(t) = -\gamma L_1(t) + L_1(t-1) + \gamma L_2(t-1)$$
$$L_3(t) = -\gamma L_2(t) + L_2(t-1) + \gamma L_3(t-1)$$

---

### 2.2. Cumulative Upward ($\text{CU}$) and Downward ($\text{CD}$) Displacements

The directional displacement across adjacent stages is accumulated:

$$\text{Stage 1: } \text{if } L_0(t) \ge L_1(t) \implies \text{CU}_1 = L_0(t) - L_1(t), \quad \text{else } \text{CD}_1 = L_1(t) - L_0(t)$$
$$\text{Stage 2: } \text{if } L_1(t) \ge L_2(t) \implies \text{CU}_2 = L_1(t) - L_2(t), \quad \text{else } \text{CD}_2 = L_2(t) - L_1(t)$$
$$\text{Stage 3: } \text{if } L_2(t) \ge L_3(t) \implies \text{CU}_3 = L_2(t) - L_3(t), \quad \text{else } \text{CD}_3 = L_3(t) - L_2(t)$$

$$\text{CU}_t = \text{CU}_1 + \text{CU}_2 + \text{CU}_3$$
$$\text{CD}_t = \text{CD}_1 + \text{CD}_2 + \text{CD}_3$$

---

### 2.3. Normalized Laguerre RSI Formulation

$$\text{LRSI}_t = \begin{cases} \left( \frac{\text{CU}_t}{\text{CU}_t + \text{CD}_t} \right) \times 100, & \text{if } (\text{CU}_t + \text{CD}_t) > 10^{-9} \\ \text{LRSI}_{t-1}, & \text{if } (\text{CU}_t + \text{CD}_t) = 0 \end{cases}$$
$$\text{Clamped Bounds: } 0.0 \le \text{LRSI}_t \le 100.0$$

---

### 2.4. Signal Line Smoothing

$$\text{Signal}_t = \mathcal{MA}\left( \text{LRSI}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalMAType} \right)$$

---

### 2.5. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

| Fibonacci Gamma | Damping Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Application |
| :---: | :---: | :---: | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** Instantaneous cycle inflection and micro-reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 10\text{ EMA}$ | **Optimal Execution Baseline.** Fast cycle turns with minimal noise. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 50\text{ EMA}$ | **The Golden Ratio Anchor.** Smooth momentum transitions without whipsaws. |
| **`0.764`** | Strong | High | Macro Cycle Filtering | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies macro momentum exhaustion on H4/D1 charts. |
| **`0.882`** | Ultra-Strong | Very High | Secular Cycle Smoothing | $\approx 200\text{ EMA}$ | **Absolute Noise Elimination.** Identifies macro secular bull/bear cycle bottoms. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                   Laguerre_Engine.mqh                  │
│    (Core DSP Math: Computes L0..L3 Orthogonal States)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds L0..L3 State Buffers
                           ▼
┌────────────────────────────────────────────────────────┐
│               Laguerre_RSI_Calculator.mqh              │
│    (CU/CD Extraction & Normalized Laguerre RSI Engine) │
├──────────────────────────┬─────────────────────────────┤
│   MovingAverage_Engine   │   Composition Engine        │
│   • Signal MA Smoothing  │   • CLaguerreEngine_HA      │
│   • Full VWMA Support    │   • Clean Pointer Safety    │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs LRSI and Signal in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                  Laguerre_RSI_Pro.mq5                  │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Hierarchy:** Isolates polynomial tracking (`Laguerre_Engine.mqh`) from ratio calculation (`Laguerre_RSI_Calculator.mqh`) and moving average smoothing (`MovingAverage_Engine.mqh`).
2. **Leak-Free Pointer Protection:** Factory methods safely verify pointer validity (`CheckPointer`) before re-allocation on parameter updates.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Laguerre RSI Settings

* `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Signal Line Settings

* `InpDisplayMode` (*default: `DISPLAY_LRSI_AND_SIGNAL`*): Display mode (`DISPLAY_LRSI_ONLY` or `DISPLAY_LRSI_AND_SIGNAL`).
* `InpSignalPeriod` (*default: `3`*): Smoothing period for the Signal line.
* `InpSignalMAType` (*default: `EMA`*): Smoothing method for Signal line (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).

### Indicator Levels (0–100 Range)

* `InpLevelExtrHigh` (*default: `90.0`*): Extreme Overbought Climax boundary.
* `InpLevelHigh` (*default: `80.0`*): Overbought Warning threshold.
* `InpLevelMid` (*default: `50.0`*): Directional Equilibrium threshold.
* `InpLevelLow` (*default: `20.0`*): Oversold Warning threshold.
* `InpLevelExtrLow` (*default: `10.0`*): Extreme Oversold Climax boundary.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorLRSI` (*default: `clrMediumTurquoise`*): Laguerre RSI line color (Width: 2, Solid).
* `InpColorSignal` (*default: `clrLightCoral`*): Signal line color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE RSI TRADING PLAYBOOKS                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 50-Line Equilibrium Cross: LRSI crossing > 50 = Bullish Momentum.   │
│                               LRSI crossing < 50 = Bearish Momentum.   │
│ 2. Signal Crossover Trigger:  LRSI crosses Signal line in direction of │
│                               higher-timeframe macro trend baseline.   │
│ 3. Deep Boundary Reversals:   LRSI exiting > 90 / < 10 extreme         │
│                               boundaries signals cycle exhaustion.     │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The 50.0 Equilibrium Directional Shift

* **Bullish Momentum Dominance:** Laguerre RSI crossing decisively **above 50.0** confirms that upward stage displacements ($\text{CU}$) are dominating downward displacements ($\text{CD}$). Favor long continuation setups.
* **Bearish Momentum Dominance:** Laguerre RSI crossing decisively **below 50.0** confirms downward dominance.

### 5.2. Trend-Following Signal Line Crossovers (LRSI / Signal)

* **Bullish Continuation Trigger:** Price is in an established uptrend, Laguerre RSI pulls back toward the 50.0 line, and crosses **above the Signal Line** $\rightarrow$ Enter Long.
* **Bearish Continuation Trigger:** Price is in a downtrend, Laguerre RSI rallies toward 50.0, and crosses **below the Signal Line** $\rightarrow$ Enter Short.

### 5.3. Multi-Timeframe Macro Confluence

* Attach an **H1-calculated Laguerre RSI ($\gamma=0.618$)** onto an **M5 execution chart**.
* **Rule:** Only take M5 long breakout/pullback entries when **H1 Laguerre RSI is above 50.0 and rising**. This ensures you never trade against higher-timeframe institutional momentum.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferLRSI` | `INDICATOR_DATA` | Main Laguerre Relative Strength Index Line |
| **1** | `BufferSignal` | `INDICATOR_DATA` | Smoothed Signal Trigger Line |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
