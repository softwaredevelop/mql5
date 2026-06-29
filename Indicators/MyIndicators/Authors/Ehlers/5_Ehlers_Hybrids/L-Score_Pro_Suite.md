# L-Score Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **L-Score Pro Suite** is an institutional-grade, ultra-low-lag statistical volatility arbitrage suite comprising two advanced indicators: `LScore_Pro` (Standard) and `LScore_MTF_Pro` (Multi-Timeframe).

Traditional statistical Z-Scores rely on standard moving averages (SMA, EMA) as their baseline mean ($\mu$). While mathematically sound, these averages carry significant phase lag, often causing the Z-Score to peak long after a market reversal has already commenced. The L-Score resolving this bottleneck by implementing **John Ehlers' Laguerre Filter** as its dynamic center line.

By mapping price coordinates into a four-dimensional Laguerre space (using stateful $L_0$ to $L_3$ polynomial filters), the suite establishes an ultra-responsive, highly adaptive baseline. It then calculates the population standard deviation ($\sigma_L$) and standard score relative to this low-lag baseline.

The suite features dynamic Heikin Ashi price integration, a **5-Zone Dynamic Thermal Color Histogram** that automatically realigns with user-defined input levels, an optional Signal Line trigger, and advanced multi-timeframe synchronization algorithms.

---

## 2. Mathematical Foundations and Calculation Logic

The L-Score algorithm translates price data into Laguerre space recursively on every bar. The calculation sequence operates on price coordinates $P_t$ (Standard or Heikin Ashi) using a dampening factor $\gamma$ (`InpGamma` $\in [0, 1]$) and a standard deviation lookback window $N$ (`InpPeriod`):

### A. Recursive Laguerre Polynomial States

At each bar $t$, the four Laguerre polynomial states ($L_0$ to $L_3$) are updated recursively. The persistent state registers from the previous bar ($t-1$) are utilized to maintain structural continuity:

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

### B. John Ehlers' Low-Lag Baseline Mean ($\mu_L$)

The dynamic central baseline $\mu_L$ is calculated as a weighted FIR combination of the four polynomial states. This formulation achieves maximum noise reduction with near-zero phase lag:

$$\mu_{L, t} = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### C. Laguerre Standard Deviation ($\sigma_L$)

The standard deviation measures the dispersion of closing prices around the dynamic Laguerre baseline $\mu_L$ over the rolling lookback window of size $N$:

$$\sigma_{L, t} = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \mu_{L, t})^2}$$

*Note: The mathematical engine calculates the Population Standard Deviation relative to the changing local mean $\mu_{L, t}$ to ensure absolute statistical alignment with volatility expansions.*

### D. Final Normalized L-Score ($L_t$)

The final L-Score represents the normalized distance of the current price from the Laguerre filter baseline, expressed in dynamic standard deviation (Sigma) units:

$$L_t = \frac{P_t - \mu_{L, t}}{\sigma_{L, t}}$$

To prevent division-by-zero exceptions during periods of absolute price consolidation, the calculation includes an active protection layer:

$$L_t = 0.0 \quad \text{if } \sigma_{L, t} \le 1.0 \times 10^{-9}$$

---

## 3. High-Performance Architecture (Zero-Copy Engine)

Standard indicator engines suffer from severe memory bottlenecks due to repetitive array copying (e.g., extracting price series to feed auxiliary standard deviation loops on every tick).

The L-Score Suite eliminates this overhead by implementing a **Zero-Copy Engine Pattern**:

* The compiled stateful `CLaguerreEngine` stores prepared price arrays inside its internal protected class member array `m_price[]`.
* To calculate the rolling variance, the standard deviation loop directly accesses price data via a fast, inlined constant pointer method:

  ```mql5
  double GetPrice(int index) const { return m_price[index]; }
  ```

This architecture bypasses MT5 deep-copy routines, enabling real-time, tick-by-tick MTF calculations across dozens of charts simultaneously without CPU spikes.

---

## 4. Multi-Stage Statistical Mapping (Swapped Thermal Palette)

To represent the progressive build-up of market momentum, the indicator implements a **6-Level Dynamic Sigma Boundary Layout** and a **5-Zone Dynamic Thermal Color Histogram** (Blue for Bullish, Red/Coral for Bearish, perfectly aligned with Heikin Ashi candle colors).

Because the color transition logic is dynamically linked to the inputs, updating the level parameters automatically reshapes the histogram classification boundaries in real-time:

| L-Score Value ($L$) | Color | Market Regime | Default Threshold | Action / Concept |
| :--- | :--- | :--- | :---: | :--- |
| **$L \ge \text{InpLevelClimaxHigh}$** | `clrDeepSkyBlue` | **Bullish Climax** (Exhaustion) | $\ge 2.5$ | **Severe Overbought.** High probability reversal zone. Prepare to Short. |
| **$L \in [\text{InpLevelFlowHigh}, \text{InpLevelClimaxHigh})$** | `clrLightSkyBlue` | **Bullish Flow** (Momentum) | $[2.0, 2.5)$ | **Strong Bullish Momentum.** Scale-in warning zone for short positions. |
| **$L \in (\text{InpLevelFlowLow}, \text{InpLevelFlowHigh})$** | `clrGray` | **Neutral Zone** (Random Noise) | $(-2.0, 2.0)$ | **Equilibrium.** Standard trend continuation / noise. |
| **$L \in (\text{InpLevelClimaxLow}, \text{InpLevelFlowLow}]$** | `clrCoral` | **Bearish Flow** (Momentum) | $(-2.5, -2.0]$ | **Strong Bearish Momentum.** Scale-in warning zone for long positions. |
| **$L \le \text{InpLevelClimaxLow}$** | `clrOrangeRed` | **Bearish Climax** (Exhaustion) | $\le -2.5$ | **Severe Oversold.** High probability reversal zone. Prepare to Buy. |

---

## 5. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

`LScore_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step (both the L-Score histogram and the Signal Line) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Recursive State Safety on Live HTF Ticks (State Mocking)

Recursive engines like the Laguerre Filter are highly state-sensitive. If we calculate the filter on the live HTF bar repeatedly on every tick, the belső registers ($L_{0}$ to $L_{3}$) will accumulate calculation states and drift away from their true mathematical values.

`LScore_MTF_Pro` eliminates this cumulative state corruption by mocking the live update call exactly how the MT5 terminal's native engine handles `prev_calculated` on live ticks. We pass `prev_calculated = g_htf_count`:

```mql5
g_calculator.Calculate(g_htf_count, g_htf_count, price_type, h_open, h_high, ...);
```

By passing `prev_calculated` as `g_htf_count`, the internal loop starts exactly at the live forming bar index `start_index = g_htf_count - 1`. The loop runs exactly once for the live bar. Since `i` is equal to `rates_total - 1`, the stable closed historical registers ($L_0[i-1]$ to $L_3[i-1]$) are read but **never overwritten or corrupted**, ensuring absolute mathematical stability on every tick.

---

## 6. Parameters

### A. Laguerre Baseline Settings

* **Laguerre Gamma (`InpGamma`):** Dampening factor ($\gamma$) that determines the responsiveness of the baseline filter. Smaller values increase speed but introduce more noise; larger values increase smoothing but add minimal lag (Default: `0.5`, Range: `0.0 to 1.0`).
* **Price Source (`InpPrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Volatility Settings

* **Lookback Period (`InpPeriod`):** The rolling window size ($N$) for the standard deviation volatility calculation (Default: `20`).

### C. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line (Default: `true`).
* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`).

### D. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate L-Scores on (Default: `PERIOD_H1`).

### E. Indicator Levels Settings

* **High Warning Level (`InpLevelFlowHigh`):** Volatility band indicating positive structural expansion (Default: `2.0`).
* **Low Warning Level (`InpLevelFlowLow`):** Volatility band indicating negative structural expansion (Default: `-2.0`).
* **High Climax Level (`InpLevelClimaxHigh`):** Extreme bullish exhaustion threshold (Default: `2.5`).
* **Low Climax Level (`InpLevelClimaxLow`):** Extreme bearish exhaustion threshold (Default: `-2.5`).
* **High Exhaustion Level (`InpLevelExtremeHigh`):** Advanced statistical exhaustion threshold (Default: `3.0`).
* **Low Exhaustion Level (`InpLevelExtremeLow`):** Advanced statistical exhaustion threshold (Default: `-3.0`).
* **Levels Color (`InpLevelColor`):** Customize the color of the horizontal line layout (Default: `clrSilver`).
* **Levels Style (`InpLevelStyle`):** Customize the line style of the horizontal line layout (Default: `STYLE_DOT`).

---

## 7. Advanced Trading Strategies

### A. Laguerre Mean-Reversion Wyckoff Crossover

The Laguerre baseline filter reacts to price turns significantly faster than traditional moving averages, making the L-Score an exceptionally sensitive mean-reversion tool.

1. Wait for the L-Score to stretch beyond the dynamic Climax boundaries:
   * Bullish Climax: $L_t \ge \text{InpLevelClimaxHigh}$ (Blue Histogram)
   * Bearish Climax: $L_t \le \text{InpLevelClimaxLow}$ (Red Histogram)
2. Monitor the contraction of the histogram bars.
3. **Execution Trigger:** Enter a short position when the L-Score crosses back below the Signal Line from above. Enter a long position when the L-Score crosses back above the Signal Line from below.
4. **Stop-Loss Placement:** Place the stop-loss strictly beyond the extreme candle's swing high or swing low.

### B. Top-Down Macro Laguerre Volatility Corridor (MTF Core Strategy)

Using a multi-timeframe setup filters out low-timeframe noise and aligns execution with institutional flow:

1. **Macro Volatility Setup (H1/H4):** Apply `LScore_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Trend Alignment:** Identify if the macro **H1 L-Score** is stretched to statistical extremes:
   * Bullish Climax ($\ge \text{InpLevelClimaxHigh}$): Only prepare to Short.
   * Bearish Climax ($\le \text{InpLevelClimaxLow}$): Only prepare to Buy.
3. **The Local Execution:** Once the H1 L-Score reaches the Bearish Climax zone (e.g., $\le -2.5$):
   * Switch focus to the local M5 chart.
   * Execute **BUY** orders on the local M5 chart as soon as the local M5 L-Score crosses back above its own **InpLevelFlowLow (-2.0)**, riding the high-probability macro mean-reversion corridor back to fair value.
