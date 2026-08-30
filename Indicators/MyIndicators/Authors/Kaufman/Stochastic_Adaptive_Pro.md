# Frank Key's Adaptive Stochastic Oscillator Pro (v3.00)

Quantitative Variable-Length Adaptive Momentum & Stochastic Oscillator Suite

---

## 1. Summary (Introduction)

**Stochastic Adaptive Pro** is an institutional-grade non-linear momentum oscillator developed by technical analyst Frank Key. It eliminates the fatal flaw of traditional fixed-period Stochastics by dynamically adjusting its lookback calculation window using **Perry Kaufman's Efficiency Ratio (ER)**.

Traditional Stochastics (George Lane) uses a rigid, constant period (e.g., 14). During explosive, sustained trends, fixed Stochastics gets pinned in "overbought" or "oversold" territory for dozens of bars, generating premature, false counter-trend signals. During choppy consolidations, it lags behind rapid swing reversals. **Frank Key's Adaptive Stochastic dynamically rescales its lookback window between a minimum and maximum period**:

* **Strong Directional Trend ($ER \to 1.0$):** Lookback period automatically expands toward $P_{\text{max}} = 30$. This smooths the oscillator, preventing premature overbought/oversold pinning and keeping traders aligned with the trend.
* **Choppy / Ranging Market ($ER \to 0.0$):** Lookback period automatically contracts toward $P_{\text{min}} = 5$. This transforms the oscillator into an ultra-responsive swing-trading tool that captures rapid turns at support and resistance boundaries.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   ADAPTIVE STOCHASTIC ARCHITECTURE                     │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ %K Main Line         │ clrDodgerBlue (Width:2)│ Adaptive Momentum Line │
│ %D Signal Line       │ clrCoral (Width:1)     │ Smoothed Trigger Line  │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Dynamic Lookback Rescaling ($P_{\text{min}} \dots P_{\text{max}}$):** Seamlessly shifts from fast scalping sensitivity to smooth macro trend retention.
* **Dual-Engine Smoothing Flexibility:** Independent moving average algorithms for %K Slowing and %D Signal smoothing (supports SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA).
* **Unified 2026 MTF Framework:** Synchronized with `DataSync_Tools.mqh` to project higher-timeframe adaptive curves (e.g., H1 or H4) onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps.
* **Synthetic Heikin Ashi Support:** Computes adaptive momentum from filtered Heikin Ashi candles via `CHeikinAshi_Calculator` composition.
* **Dynamic 5-Level Grid:** Fully customizable horizontal thresholds ($10, 20, 50, 80, 90$).

---

## 2. Mathematical Foundations & Adaptive Scaling

```text

                 Kaufman's Efficiency Ratio (ER) over Period P_ER
                                      │
                                      ▼
           Dynamic Period Scaling: NSP = round(ER · [P_max - P_min] + P_min)
                                      │
                                      ▼
             Adaptive Highest High & Lowest Low across dynamic NSP
                                      │
                                      ▼
             Raw %K = [ (Price - Lowest) / (Highest - Lowest) ] × 100
                                      │
                                      ▼
             Slow %K = MA(Raw %K, Period = Slowing, Method = K_MA)
                                      │
                                      ▼
             %D Signal = MA(Slow %K, Period = D_Period, Method = D_MA)

```

### 2.1. Kaufman's Efficiency Ratio ($ER_t$)

The market's directional signal-to-noise ratio is evaluated over lookback window $P_{\text{ER}} = \text{InpErPeriod}$:
$$\text{Direction}_t = | P_t - P_{t - P_{\text{ER}}} |$$
$$\text{Volatility}_t = \sum_{j=0}^{P_{\text{ER}}-1} | P_{t-j} - P_{t-j-1} |$$
$$\text{ER}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.2. Dynamic Lookback Scaling ($\text{NSP}_t$)

The Nominal Stochastic Period ($\text{NSP}$) rescales continuously between $P_{\text{min}} = \text{InpMinStochPeriod}$ and $P_{\text{max}} = \text{InpMaxStochPeriod}$:
$$\text{NSP}_t = \text{round}\left( \text{ER}_t \cdot (P_{\text{max}} - P_{\text{min}}) + P_{\text{min}} \right)$$
$$\text{Clamped Bounds: } P_{\text{min}} \le \text{NSP}_t \le P_{\text{max}}$$

---

### 2.3. Adaptive Raw %K Formulation

Across the dynamically evolving lookback window $\text{NSP}_t$:
$$\text{Highest}_t = \max_{j=0 \dots \text{NSP}_t-1} \left( P_{t-j} \right)$$
$$\text{Lowest}_t = \min_{j=0 \dots \text{NSP}_t-1} \left( P_{t-j} \right)$$
$$\text{Range}_t = \text{Highest}_t - \text{Lowest}_t$$

$$\text{Raw \%K}_t = \begin{cases} \left( \frac{P_t - \text{Lowest}_t}{\text{Range}_t} \right) \times 100, & \text{if } \text{Range}_t > 10^{-9} \\ \text{Raw \%K}_{t-1}, & \text{if } \text{Range}_t = 0 \end{cases}$$

---

### 2.4. Slow %K (Main Line) & %D (Signal Line) Smoothing

The Raw %K is smoothed using the user-defined Slowing Moving Average ($\mathcal{MA}$):
$$\text{\%K}_t = \mathcal{MA}\left( \text{Raw \%K}, \text{Period} = \text{InpSlowingPeriod}, \text{Type} = \text{InpSlowingMAType} \right)$$

The final signal line is produced by smoothing the %K series:
$$\text{\%D}_t = \mathcal{MA}\left( \text{\%K}, \text{Period} = \text{InpDPeriod}, \text{Type} = \text{InpDMAType} \right)$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│           Stochastic_Adaptive_Calculator.mqh           │
│   (Core Math: ER Computation & Adaptive Lookback Engine│
├──────────────────────────┬─────────────────────────────┤
│   MovingAverage_Engine   │   Composition Engine        │
│   • Slow %K Smoothing    │   • CHeikinAshi_Calculator  │
│   • %D Signal Smoothing  │   • Full VWMA Support       │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs %K and %D in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│               Stochastic_Adaptive_Pro.mq5              │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular Composition Architecture:** `CStochasticAdaptiveCalculator` encapsulates `CHeikinAshi_Calculator` and `CMovingAverageCalculator` via composition, guaranteeing zero memory fragmentation.
2. **Leak-Free Pointer Protection:** Factory methods safely verify pointer validity (`CheckPointer`) before re-allocation on parameter updates.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe history readiness without GUI freezes.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Adaptive Lookback Settings

* `InpErPeriod` (*default: `10`*): Lookback period ($N$) for Kaufman's Efficiency Ratio calculation.
* `InpMinStochPeriod` (*default: `5`*): Minimum Stochastic lookback period used during noisy, sideways consolidations ($ER \to 0$).
* `InpMaxStochPeriod` (*default: `30`*): Maximum Stochastic lookback period used during strong, efficient trends ($ER \to 1$).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Smoothing & Signal Settings

* `InpSlowingPeriod` (*default: `3`*): Smoothing period for the %K main line.
* `InpSlowingMAType` (*default: `SMA`*): Smoothing method for %K (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpDPeriod` (*default: `3`*): Smoothing period for the %D signal line.
* `InpDMAType` (*default: `SMA`*): Smoothing method for %D.

### Indicator Levels (0–100 Range)

* `InpLevelExtrHigh` (*default: `90.0`*): Extreme Overbought Climax boundary.
* `InpLevelHigh` (*default: `80.0`*): Overbought Warning threshold.
* `InpLevelMid` (*default: `50.0`*): Directional Equilibrium threshold.
* `InpLevelLow` (*default: `20.0`*): Oversold Warning threshold.
* `InpLevelExtrLow` (*default: `10.0`*): Extreme Oversold Climax boundary.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorK` (*default: `clrDodgerBlue`*): %K adaptive line color (Width: 2, Solid).
* `InpColorD` (*default: `clrCoral`*): %D signal line color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│               ADAPTIVE STOCHASTIC TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Trend Retention Rule:     In strong trends (high ER), %K stays      │
│                              in 50-80 zone without premature exits.    │
│ 2. Range Boundary Scalp:     In chop (low ER), %K contracts to period  │
│                              5, generating sharp turns at 20 and 80.   │
│ 3. Signal Line Crossovers:   %K crosses %D near 50.0 line in direction │
│                              of the macro trend baseline.              │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Trend Retention vs. Range Fading

* **Trending Market ($ER > 0.60$):** The lookback expands to $25 \dots 30$. %K smooths out and tracks the markup/markdown. Do **NOT** sell simply because %K enters the 80.0 zone; wait for %K to cross below %D and drop below 80.0.
* **Consolidating Market ($ER < 0.30$):** The lookback contracts to $5 \dots 10$. Look for aggressive mean-reversion fades when %K rejects from the `20.0 (Oversold)` or `80.0 (Overbought)` levels.

### 5.2. The 50.0 Equilibrium Directional Shift

* **Bullish Dominance:** %K crossing decisively **above 50.0** confirms that buyers are taking control of the active cycle.
* **Bearish Dominance:** %K crossing decisively **below 50.0** confirms seller dominance.

### 5.3. Multi-Timeframe Macro Confluence

* Attach an **H1-calculated Adaptive Stochastic** onto an **M5 execution chart**.
* **Rule:** Only take M5 long pullback entries when **H1 %K is above 50.0 and rising**. This guarantees that intraday entries are synchronized with higher-timeframe adaptive momentum.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferK` | `INDICATOR_DATA` | Adaptive %K Main Line |
| **1** | `BufferD` | `INDICATOR_DATA` | Smoothed %D Signal Line |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
