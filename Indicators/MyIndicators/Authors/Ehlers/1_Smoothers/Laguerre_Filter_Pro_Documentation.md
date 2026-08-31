# John Ehlers' Laguerre Filter Pro (v3.00)

Quantitative Time-Warped Digital Filter & Low-Lag Trend Baseline Suite

---

## 1. Summary (Introduction)

**Laguerre Filter Pro** is an institutional-grade digital signal processing (DSP) trendline indicator developed by aerospace engineer and quantitative trading pioneer John Ehlers.

In classical electronic filter design, time series smoothing relies on linear unit delays ($z^{-1}$), which unavoidably introduce phase lag across all frequencies. Ehlers bypassed this limitation by implementing **orthogonal Laguerre polynomials**, replacing standard unit delays with an **all-pass time-warped transfer function**.

This mathematical innovation allows the filter to achieve the smoothing power of a 20-to-100 period moving average using only **four recursive data registers ($L_0, L_1, L_2, L_3$)**, providing dramatically reduced phase delay and instantaneous trend inflection recognition.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     EHLERS LAGUERRE FILTER ENGINE                      │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ Laguerre Filter Line │ clrCrimson (Width:2)   │ Low-Lag Adaptive Trend │
│ FIR Comparison Line  │ clrDarkBlue (Width:1)  │ 4-Point FIR Benchmark  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Time-Warped 4-Element IIR Architecture:** Synthesizes higher-order low-pass smoothing from just four state registers ($L_0 \dots L_3$).
* **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter dampening with golden ratio proportions from ultra-sensitive scalping ($\gamma = 0.236$) to secular macro cycle smoothing ($\gamma = 0.882$).
* **Optional 4-Point FIR Benchmark:** Provides an on-chart FIR comparison baseline ($\text{FIR} = \frac{P + 2P_1 + 2P_2 + P_3}{6}$) to visually expose phase lead and lag divergence.
* **Unified 2026 MTF Framework:** Higher-timeframe Laguerre curves (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CLaguerreEngine_HA` composition.

---

## 2. Mathematical Foundations & Laguerre Transform Theory

```text

                  RAW PRICE (Market Noise & High Frequencies)
                                       │
                                       ▼
      ┌─────────────────────────────────────────────────────────────────┐
      │             All-Pass Time-Warp Transfer Function                │
      │                H(z) = (z⁻¹ - γ) / (1 - γ·z⁻¹)                   │
      └────────────────────────────────┬────────────────────────────────┘
                                       │
        ┌──────────────┬───────────────┴───────────────┬──────────────┐
        ▼              ▼                               ▼              ▼
     L0 State       L1 State                        L2 State       L3 State
        │              │                               │              │
        └──────────────┴───────────────┬───────────────┴──────────────┘
                                       ▼
               Laguerre Filter = (L0 + 2·L1 + 2·L2 + L3) / 6

```

### 2.1. The 4-Element Recursive Difference Equations

Given input price $P_t$ and dampening coefficient $\gamma = \text{InpGamma}$ ($0.0 \le \gamma \le 1.0$):
$$L_0(t) = (1 - \gamma) P_t + \gamma L_0(t-1)$$
$$L_1(t) = -\gamma L_0(t) + L_0(t-1) + \gamma L_1(t-1)$$
$$L_2(t) = -\gamma L_1(t) + L_1(t-1) + \gamma L_2(t-1)$$
$$L_3(t) = -\gamma L_2(t) + L_2(t-1) + \gamma L_3(t-1)$$

---

### 2.2. Weighted Median Synthesis

The final output is computed as a symmetrical weighted average of the four state elements:
$$\text{Laguerre Filter}_t = \frac{L_0(t) + 2 \cdot L_1(t) + 2 \cdot L_2(t) + L_3(t)}{6}$$

---

### 2.3. The 4-Point FIR Comparison Filter

When enabled (`InpShowFIR = true`), an unwarped 4-point Finite Impulse Response (FIR) filter is plotted for direct lag benchmarking:
$$\text{FIR}_t = \frac{P_t + 2 \cdot P_{t-1} + 2 \cdot P_{t-2} + P_{t-3}}{6}$$

---

### 2.4. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

Utilizing **Fibonacci ratios** as Gamma parameters aligns the filter's dampening curve with the golden proportions of natural market expansions:

| Fibonacci Gamma | Smoothing Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Institutional Application |
| :---: | :---: | :---: | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** Tracks price closely. Identifies immediate trend acceleration and micro-reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 9\text{--}10\text{ EMA}$ | **Optimal Execution Baseline.** Excellent alternative to 9 EMA. Filters out noise while keeping crossovers fast. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 15\text{--}20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 30\text{--}50\text{ EMA}$ | **The Golden Ratio Anchor.** Outstanding core filter. Replaces 20/50 standard moving averages with 50% less Fourier lag. |
| **`0.764`** | Strong | Medium-High | Macro Trend Identification | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies institutional trend direction on H4/D1 charts. Bypasses consolidation whipsaws. |
| **`0.882`** | Ultra-Strong | High | Secular Trend Smoothing | $\approx 200\text{ EMA}$ | **Absolute Noise Elimination.** Ideal for long-term investing and tracking macro market cycles on weekly/monthly charts. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                   Laguerre_Engine.mqh                  │
│    (Core DSP Math: Computes L0..L3 States & Filter)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds Filter Series & Price Getter
                           ▼
┌────────────────────────────────────────────────────────┐
│              Laguerre_Filter_Calculator.mqh            │
│    (Engine Adapter: Computes Laguerre & FIR Output)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Filter & FIR in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                Laguerre_Filter_Pro.mq5                 │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Hierarchy:** Isolates raw Laguerre state registers (`Laguerre_Engine.mqh`) from adapter calculation (`Laguerre_Filter_Calculator.mqh`), allowing oscillators like `Laguerre_RSI_Pro` to reuse internal $L_0 \dots L_3$ states directly via `GetLBuffers()`.
2. **Stateful Historical Preservation:** Array allocation safeguards (`ArrayResize` without destructive wiping) ensure that recursive registers ($L_0 \dots L_3$) preserve 100% of historical states across live bar additions.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Laguerre Settings

* `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### FIR Comparison Filter Settings

* `InpShowFIR` (*default: `false`*): Toggle on-chart visibility of the 4-point FIR benchmark line.

### Visual Settings - Laguerre Filter

* `InpColorLaguerre` (*default: `clrCrimson`*): Color of the main Laguerre Filter line (Width: 2, Solid).
* `InpStyleLaguerre` (*default: `STYLE_SOLID`*): Line style of the Laguerre Filter.
* `InpWidthLaguerre` (*default: `2`*): Line thickness.

### Visual Settings - FIR Filter

* `InpColorFIR` (*default: `clrDarkBlue`*): Color of the FIR comparison line (Width: 1, Solid).
* `InpStyleFIR` (*default: `STYLE_SOLID`*): Line style of the FIR line.
* `InpWidthFIR` (*default: `1`*): Line thickness.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE FILTER TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic S/R Pullback:   In strong trends, pullbacks into the        │
│                            Laguerre line offer low-drawdown entries.   │
│ 2. Laguerre / FIR Cross:   Laguerre crossing above FIR confirms trend  │
│                            inflection with zero phase delay.           │
│ 3. MTF Trend Filter:       Attach H1/H4 Laguerre Filter on M5 chart    │
│                            to trade strictly in direction of macro flow│
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dynamic Support & Resistance Retests

* **Bullish Retest:** In an established uptrend, price pulls back into the rising `Laguerre Filter (γ=0.382 or γ=0.500)` line and forms a rejection candle $\rightarrow$ High-conviction long continuation entry with stop-loss placed just below the curve.
* **Bearish Retest:** In a downtrend, price rallies into the falling `Laguerre Filter` line and rejects $\rightarrow$ Enter short.

### 5.2. Laguerre vs. FIR Lead-Lag Crossover

* **Bullish Crossover:** The `Laguerre Filter` line crosses **above** the `FIR Filter` line $\rightarrow$ Confirms that price is accelerating upward faster than linear 4-bar momentum.
* **Bearish Crossover:** The `Laguerre Filter` line crosses **below** the `FIR Filter` line $\rightarrow$ Confirms downward acceleration.

### 5.3. Multi-Timeframe Macro Baseline Alignment

* Attach an **H1-calculated Laguerre Filter ($\gamma=0.618$ or $\gamma=0.764$)** onto an **M5 execution chart**.
* **Rule:** Only take intraday long pullbacks on M5 when **price is trading above the H1 Laguerre flat step**. This ensures you never trade against higher-timeframe institutional trend structure.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferFilter` | `INDICATOR_DATA` | Main John Ehlers Laguerre Filter Plot Line |
| **1** | `BufferFIR` | `INDICATOR_DATA` | Optional 4-Point FIR Comparison Filter Line |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
