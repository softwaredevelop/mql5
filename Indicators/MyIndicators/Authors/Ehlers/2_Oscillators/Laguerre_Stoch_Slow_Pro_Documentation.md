# John Ehlers' Laguerre Stochastic Slow Oscillator Pro (v3.00)

Quantitative Time-Warped Stochastic & Dual-Smoothed Momentum Oscillator Suite

---

## 1. Summary (Introduction)

**Laguerre Stoch Slow Pro** is an institutional-grade non-linear momentum oscillator developed by aerospace engineer and quantitative trading pioneer John Ehlers.

In classical technical analysis, George Lane's Stochastic Oscillator evaluates the closing price relative to a fixed $N$-bar price range ($H_N - L_N$), introducing significant phase lag and false boundary pinning during strong trends. **John Ehlers resolved this by replacing historical price lookback with four orthogonal Laguerre state registers ($L_0, L_1, L_2, L_3$)**:

* **Zero Historical Lookback Overhead:** The Stochastic envelope is derived dynamically from the instantaneous dispersion of the four Laguerre polynomial stages.
* **Dual-Stage Moving Average Smoothing:** Filters raw stochastic micro-noise by applying a Slowing Moving Average to generate **Slow %K** and a Signal Moving Average to generate **Signal %D**.
* **Near-Zero Phase Lag Inflections:** The time-warped all-pass transfer function enables the oscillator to recognize market cyclical turns with virtually zero phase delay.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE STOCHASTIC SLOW SYSTEM                      │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Slow %K Main Line    │ clrDodgerBlue (Width:2)│ Adaptive Momentum Line │
│ Signal %D Line       │ clrCoral (Width:1)     │ Smoothed Trigger Line  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Time-Warped 4-Element Stochastic Normalization:** Computes %K strictly from the internal envelope formed by $L_0, L_1, L_2,$ and $L_3$.
* **Dual-Engine Smoothing Flexibility:** Independent moving average algorithms for %K Slowing and %D Signal smoothing (supports SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA).
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter sensitivity with golden ratio proportions from ultra-sensitive scalping ($\gamma = 0.236$) to macro trend smoothing ($\gamma = 0.882$).
* **Unified 2026 MTF Framework:** Higher-timeframe Laguerre Stochastic curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Computes smoothed momentum from filtered Heikin Ashi candles via `CLaguerreStochSlowCalculator_HA` composition.

---

## 2. Mathematical Foundations & Laguerre Stochastic Mechanics

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
                  Highest = max(L0, L1, L2, L3)
                  Lowest  = min(L0, L1, L2, L3)
                  Raw %K  = [ (L0 - Lowest) / (Highest - Lowest) ] × 100
                                     │
                                     ▼
             Slow %K   = MA(Raw %K, Period = Slowing, Method = Slow_MA)
             Signal %D = MA(Slow %K, Period = Signal, Method = Sig_MA)

```

### 2.1. The 4-Element Laguerre State Engine

Given input price $P_t$ and damping coefficient $\gamma = \text{InpGamma}$ ($0.0 \le \gamma \le 1.0$):
$$L_0(t) = (1 - \gamma) P_t + \gamma L_0(t-1)$$
$$L_1(t) = -\gamma L_0(t) + L_0(t-1) + \gamma L_1(t-1)$$
$$L_2(t) = -\gamma L_1(t) + L_1(t-1) + \gamma L_2(t-1)$$
$$L_3(t) = -\gamma L_2(t) + L_2(t-1) + \gamma L_3(t-1)$$

---

### 2.2. Dynamic Laguerre Envelope Extrema & Raw %K

The instantaneous highest and lowest boundaries across the 4 orthogonal stages are defined as:
$$\text{Highest}_t = \max \left( L_0(t), L_1(t), L_2(t), L_3(t) \right)$$
$$\text{Lowest}_t = \min \left( L_0(t), L_1(t), L_2(t), L_3(t) \right)$$
$$\text{Range}_t = \text{Highest}_t - \text{Lowest}_t$$

The position of the primary stage ($L_0$) within this envelope yields the Raw %K:
$$\text{Raw \%K}_t = \begin{cases} \left( \frac{L_0(t) - \text{Lowest}_t}{\text{Range}_t} \right) \times 100, & \text{if } \text{Range}_t > 10^{-9} \\ \text{Raw \%K}_{t-1}, & \text{if } \text{Range}_t = 0 \end{cases}$$

---

### 2.3. Slow %K (Main Line) & %D (Signal Line) Dual Smoothing

$$\text{Slow \%K}_t = \mathcal{MA}\left( \text{Raw \%K}, \text{Period} = \text{InpSlowingPeriod}, \text{Type} = \text{InpSlowingMethod} \right)$$
$$\text{Signal \%D}_t = \mathcal{MA}\left( \text{Slow \%K}, \text{Period} = \text{InpSignalPeriod}, \text{Type} = \text{InpSignalMethod} \right)$$

---

### 2.4. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

| Fibonacci Gamma | Damping Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Application |
| :---: | :---: | :---: | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** High-frequency turning points and micro-cycle reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 10\text{ EMA}$ | **Optimal Execution Baseline.** Fast cycle turns with minimal noise. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 50\text{ EMA}$ | **The Golden Ratio Anchor.** Smooth cycle transitions without whipsaws. |
| **`0.700`** | Default | Medium-High | Default Trend-Cycle Balance | $\approx 65\text{ EMA}$ | **Ehlers Default Damping.** Optimal separation of primary cycle waves. |
| **`0.764`** | Strong | High | Macro Cycle Filtering | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies macro turning points on H4/D1 charts. |
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
│            Laguerre_Stoch_Slow_Calculator.mqh          │
│    (Envelope Extrema & Dual-Stage Smoothing Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   MovingAverage_Engine   │   Composition Engine        │
│   • Slow %K Smoothing    │   • CLaguerreEngine_HA      │
│   • Signal %D Smoothing  │   • Full VWMA Support       │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs Slow %K and Signal %D in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│              Laguerre_Stoch_Slow_Pro.mq5               │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **4-Tier Modular Hierarchy:** Isolates raw polynomial physics (`Laguerre_Engine.mqh`) from stochastic calculation (`Laguerre_Stoch_Slow_Calculator.mqh`) and moving average smoothing (`MovingAverage_Engine.mqh`).
2. **Leak-Free Pointer Protection:** Factory methods safely verify pointer validity (`CheckPointer`) before re-allocation on parameter updates.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Laguerre Settings

* `InpGamma` (*default: `0.7`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.700`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Stochastic Slowing & Signal Settings

* `InpSlowingPeriod` (*default: `3`*): Smoothing period for the Raw %K line.
* `InpSlowingMethod` (*default: `SMA`*): Smoothing method for Slow %K (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSignalPeriod` (*default: `3`*): Smoothing period for the Signal %D line.
* `InpSignalMethod` (*default: `SMA`*): Smoothing method for Signal %D.

### Indicator Levels (0–100 Range)

* `InpLevelExtrHigh` (*default: `90.0`*): Extreme Overbought Climax boundary.
* `InpLevelHigh` (*default: `80.0`*): Overbought Warning threshold.
* `InpLevelMid` (*default: `50.0`*): Directional Equilibrium threshold.
* `InpLevelLow` (*default: `20.0`*): Oversold Warning threshold.
* `InpLevelExtrLow` (*default: `10.0`*): Extreme Oversold Climax boundary.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorK` (*default: `clrDodgerBlue`*): Slow %K line color (Width: 2, Solid).
* `InpColorD` (*default: `clrCoral`*): Signal %D line color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│               LAGUERRE STOCHASTIC TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 50-Line Equilibrium Cross: Slow %K crossing > 50 = Bullish Flow.    │
│                               Slow %K crossing < 50 = Bearish Flow.    │
│ 2. Signal Crossover Trigger:  Slow %K crosses Signal %D in direction   │
│                               of higher-timeframe trend.               │
│ 3. Deep Boundary Reversals:   Slow %K exiting > 90 / < 10 extreme      │
│                               boundaries signals cycle exhaustion.     │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The 50.0 Equilibrium Directional Shift

* **Bullish Momentum Dominance:** Slow %K crossing decisively **above 50.0** confirms that the primary Laguerre stage ($L_0$) is dominating upper envelope states ($L_1 \dots L_3$). Favor long positions.
* **Bearish Momentum Dominance:** Slow %K crossing decisively **below 50.0** confirms downward dominance.

### 5.2. Trend-Following Signal Line Crossovers (%K / %D)

* **Bullish Continuation Trigger:** Price is in an established uptrend, Slow %K pulls back toward the 50.0 line, and crosses **above Signal %D** $\rightarrow$ Enter Long.
* **Bearish Continuation Trigger:** Price is in a downtrend, Slow %K rallies toward 50.0, and crosses **below Signal %D** $\rightarrow$ Enter Short.

### 5.3. Multi-Timeframe Macro Confluence

* Attach an **H1-calculated Laguerre Stoch Slow ($\gamma=0.700$)** onto an **M5 execution chart**.
* **Rule:** Only take M5 long breakout/pullback entries when **H1 Slow %K is above 50.0 and rising**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferSlowK` | `INDICATOR_DATA` | Laguerre Stochastic Slow %K (Main Line) |
| **1** | `BufferSignalD` | `INDICATOR_DATA` | Smoothed Signal %D Line |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
