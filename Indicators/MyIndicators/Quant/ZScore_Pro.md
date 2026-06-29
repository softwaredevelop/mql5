# Z-Score Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Z-Score Pro Suite** is an institutional-grade, high-performance statistical arbitrage suite comprising two advanced indicators: `ZScore_Pro` (Standard) and `ZScore_MTF_Pro` (Multi-Timeframe).

Based on Gaussian statistics and modern portfolio theory, the suite measures the volatility-adjusted distance between the current price and its dynamic moving average baseline. Unlike traditional bounded retail oscillators (RSI, Stochastic) which suffer from scaling compressions during trends, the Z-Score is statistically confined but mathematically unbounded, delivering a highly responsive, scale-free momentum tool.

The suite integrates the powerful `MovingAverage_Engine.mqh` (supporting SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and VWMA baselines), an optional customizable Signal Line, a **5-Zone Dynamic Thermal Color Histogram** aligned with Heikin Ashi candle colors, and a dynamic volume-routing pipeline to support volume-weighted calculations.

With version 1.90/1.10, all horizontal significance boundaries and visual colors have been migrated to the input panel, allowing traders to adapt their volatility filters dynamically to different asset classes and timeframes.

---

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on synchronized closing prices $P_t$ (Standard or Heikin Ashi) over an active rolling lookback window of size $N$ (`InpPeriod`):

### A. Dynamic Mean ($\mu$ - Center Line)

The baseline central curve is represented by the selected moving average type calculated over the lookback window:

$$\text{Dynamic Mean} = \text{MA}(P_t, N) \quad \text{using selected MA Type}$$

* If **`VWMA`** is selected, the dynamic mean is calculated as the Volume-Weighted Moving Average, utilizing a double-precision volume translation pipeline.

### B. Standard Deviation ($\sigma$ - Volatility Range)

The standard deviation measures the dispersion of price around the selected moving average baseline over the lookback window $N$:

$$\sigma = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{i-k} - \text{Mean}_i)^2}$$

*Note: The calculator utilizes the Population Standard Deviation formula (divided by $N$), which is the industry standard for financial price distance measurements.*

### C. Final Normalized Z-Score

The dynamic mean is subtracted from the price, and the result is normalized by dividing it by the standard deviation:

$$Z_i = \frac{P_i - \text{Mean}_i}{\sigma_i}$$

---

## 3. Optional Signal Line (Wyckoff Reversal Trigger)

To assist traders in timing mean-reversion entries, the suite features an optional, highly customizable **Signal Line**.

* **The Concept:** The Signal Line calculates a secondary moving average directly on the Z-Score output buffer (`BufferZ[]`). This acts as a trigger line (e.g., a 5-period TMA of the Z-Score).
* **The Reversal Trigger:** Rather than entering a counter-trend position immediately when the Z-Score reaches an extreme, traders wait for the Z-Score histogram to cross back over its Signal Line. This crossover confirms that the extreme directional momentum has officially faded, and statistical mean reversion is underway.

---

## 4. Multi-Stage Statistical Mapping (The Swapped 5-Zone Palette)

To represent the progressive build-up of market momentum and tension, the indicator implements a **6-Level Dynamic Sigma Boundary Layout** and a **5-Zone Dynamic Thermal Color Histogram** (Blue for Bullish, Red/Coral for Bearish, perfectly aligned with Heikin Ashi candle colors).

Because the color transition logic is dynamically linked to the inputs, updating the level parameters automatically reshapes the histogram classification boundaries in real-time:

| Z-Score Value ($Z$) | Color | Market Regime | Default Threshold | Action / Concept |
| :--- | :--- | :--- | :---: | :--- |
| **$Z \ge \text{InpLevelClimaxHigh}$** | `clrDeepSkyBlue` | **Bullish Climax** (Exhaustion) | $\ge 2.5$ | **Severe Overbought.** High probability reversal zone. Prepare to Short. |
| **$Z \in [\text{InpLevelFlowHigh}, \text{InpLevelClimaxHigh})$** | `clrLightSkyBlue` | **Bullish Flow** (Momentum) | $[2.0, 2.5)$ | **Strong Bullish Momentum.** Scale-in warning zone for short positions. |
| **$Z \in (\text{InpLevelFlowLow}, \text{InpLevelFlowHigh})$** | `clrGray` | **Neutral Zone** (Random Noise) | $(-2.0, 2.0)$ | **Equilibrium.** Standard trend continuation / noise. |
| **$Z \in (\text{InpLevelClimaxLow}, \text{InpLevelFlowLow}]$** | `clrCoral` | **Bearish Flow** (Momentum) | $(-2.5, -2.0]$ | **Strong Bearish Momentum.** Scale-in warning zone for long positions. |
| **$Z \le \text{InpLevelClimaxLow}$** | `clrOrangeRed` | **Bearish Climax** (Exhaustion) | $\le -2.5$ | **Severe Oversold.** High probability reversal zone. Prepare to Buy. |

---

## 5. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

`ZScore_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step (both the Z-Score histogram and the Signal Line) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Solving Cumulative State Corruption on MTF Live Ticks

A critical, highly subtle mathematical hazard exists when calculating stateful cumulative indicators (such as VWAP) in a mocked MTF environment on live ticks.

* **The Hazard (Double-Accumulation):** If we call the calculator's `Calculate` method on every tick by passing `prev_calculated = live_idx` (where `live_idx = g_htf_count - 1`), the internal `CVWAPCalculator` begins its loop at index `start_index = prev_calculated - 1` (the last closed bar). This forces the loop to re-process the last closed bar, which overwrites and double-accumulates the volume and typical price state continuously on every single tick, corrupting the VWAP and dragging the live Z-Score to corrupted, near-zero values.
* **The Resolution (MT5-Aligned State Mocking):** `ZScore_MTF_Pro` completely eliminates this bug by mocking the live update call exactly how the MT5 terminal's native engine handles `prev_calculated` on live ticks. We pass `prev_calculated = g_htf_count` (which equals `rates_total`):

  ```mql5
  g_calculator.Calculate(g_htf_count, g_htf_count, InpPrice, h_open, h_high, ...);
  ```

  By passing `prev_calculated` as `g_htf_count`, the internal loop starts exactly at `start_index = g_htf_count - 1` (the live forming bar). The loop runs exactly once for the live bar, and since `i` is equal to `rates_total - 1`, the persistent registers are **never modified or double-accumulated**. This guarantees absolute mathematical stability on every tick.

### C. Ensuring Safe Chronological Mapping (Array Alignment Guard)

Multi-timeframe mapping functions (`iBarShift`) and volume integrations are highly sensitive to chronological array sorting. To guarantee maximum stability and prevent critical index mismatches, both the standard and MTF indicators explicitly enforce chronological sorting on all price inputs, time parameters, and cached data structures (`ArraySetAsSeries(..., false)`) at the very beginning of the `OnCalculate` event. This guarantees index consistency under any client terminal setup.

### D. Pointer Integrity Guard

To prevent severe runtime exceptions (such as access violation fatal crashes), the execution sequence includes a robust validation layer. Before any mathematical routing occurs inside `OnCalculate`, the core calculator is validated using the `CheckPointer` function. If the pointer is invalid (`POINTER_INVALID`), the routine exits safely, shielding the system from memory faults.

---

## 6. Parameters

### A. Core Z-Score Settings

* **Lookback Period (`InpPeriod`):** The rolling window size ($N$) for the volatility and moving average calculations (Default: `20`).
* **Z-Score MA Type (`InpMAType`):** Select the baseline dynamic mean (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA). Default: `SMA`.
* **Applied Price (`InpPrice`):** The price series source to analyze (Default: `PRICE_CLOSE`).

### B. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line (Default: `true`).
* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`).

### C. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate Z-Scores on (Default: `PERIOD_H1`).

### D. Indicator Levels Settings

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

### A. The Wyckoff Reversal Trigger (Z-Score + Signal crossover)

Instead of trading the moment the price touches the Extreme Levels, wait for structural momentum to fade:

1. Wait for the Z-Score to enter the Extreme Zone (**DeepSkyBlue** $\ge \text{InpLevelClimaxHigh}$ or **OrangeRed** $\le \text{InpLevelClimaxLow}$).
2. Wait for the Z-Score histogram to contract and **cross back over the Signal Line** (typically configured as a 5-period TMA or EMA).
3. **Execution:** Open a mean-reversion trade (Short if high, Long if low) on the crossover bar. Place the stop-loss strictly beyond the extreme candle's high/low.

### B. Top-Down Volatility Deviation (MTF Core Strategy)

1. **Macro Volatility Deviation (H1/H4):** Apply `ZScore_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart.
2. **The Setup:** Wait for the macro **H1 Z-Score** to enter the **Bear Extreme Zone (OrangeRed $\le \text{InpLevelClimaxLow}$)**, indicating that the macro price is extremely cheap relative to institutional fair value.
3. **Execution:** On the lower M5 chart, only look for buy setups. Once the local M5 Z-Score crosses back above its own **InpLevelFlowLow (e.g., -2.0)** level (or crosses its signal line), execute **BUY** orders, riding the wave of macro mean-reversion back to the macro fair value.
