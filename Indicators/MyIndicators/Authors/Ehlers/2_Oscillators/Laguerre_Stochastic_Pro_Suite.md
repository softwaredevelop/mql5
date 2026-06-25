# Laguerre Stochastic Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Laguerre Stochastic Pro Suite** is an institutional-grade quantitative separate-window oscillator suite comprising four advanced technical indicators:

* `Laguerre_Stoch_Fast_Pro` (Standard Fast %K + Signal Line)
* `Laguerre_Stoch_Fast_MTF_Pro` (Multi-Timeframe Fast %K + Signal Line)
* `Laguerre_Stoch_Slow_Pro` (Standard Smoothed %K + Signal %D)
* `Laguerre_Stoch_Slow_MTF_Pro` (Multi-Timeframe Smoothed %K + Signal %D)

Based on John F. Ehlers' innovative digital signal processing (DSP) work, these oscillators do **not** calculate Stochastic values over traditional, lagged historical price windows. Instead, they calculate the Stochastic relationship directly from the four internal state variables ($L_0 \dots L_3$) of the Laguerre Filter **at the current bar**.

By evaluating the relative position of the fastest pole $L_0$ within the absolute maximum/minimum boundaries of all four poles, the Laguerre Stochastic suite delivers ultra-smooth, low-lag, and self-adjusting cyclical boundaries. It eliminates the traditional Stochastic's high-frequency "whipsaw" noise, providing crystal-clear overbought/oversold extreme signals.

---

## 2. Mathematical Foundations and Wave Mechanics

The calculations are executed on the four internal spectral registers ($L_0 \dots L_3$) generated recursively by the core `CLaguerreEngine` at each bar $t$.

### A. Dynamic Pole Boundaries ($HH$ and $LL$)

At each bar, the engine scans the four Laguerre registers to locate the absolute highest high ($HH$) and lowest low ($LL$) of the current spectral envelope:

$$HH_t = \max(L_{0, t}, L_{1, t}, L_{2, t}, L_{3, t})$$

$$LL_t = \min(L_{0, t}, L_{1, t}, L_{2, t}, L_{3, t})$$

### B. Fast Stochastic %K ($\%K_{\text{fast}}$)

The Fast Stochastic evaluates the position of the most responsive pole ($L_0$) relative to the current envelope range, scaled between $0$ and $100$:

$$\%K_{\text{fast}, t} = 100 \times \frac{L_{0, t} - LL_t}{HH_t - LL_t}$$

* **Fast Signal Line:** A smoothed moving average calculated over $\%K_{\text{fast}}$:
  $$\text{Signal}_t = \text{MA}(\%K_{\text{fast}}, P_{\text{sig}}) \quad \text{using selected MA Type}$$

### C. Slow Stochastic %K and Signal %D

Following classic Stochastic smoothing principles to filter out high-frequency noise:

* **Slow %K ($\%K_{\text{slow}}$):** A smoothed moving average of the raw $\%K_{\text{fast}}$ over a slowing period $P_{\text{slow}}$ (`InpSlowingPeriod`):
  $$\%K_{\text{slow}, t} = \text{MA}(\%K_{\text{fast}}, P_{\text{slow}}) \quad \text{using selected MA Type}$$
* **Signal %D ($\%D$):** A smoothed moving average of the $\%K_{\text{slow}}$ over a signal period $P_{\text{sig}}$ (`InpSignalPeriod`):
  $$\%D_t = \text{MA}(\%K_{\text{slow}}, P_{\text{sig}}) \quad \text{using selected MA Type}$$

---

## 3. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

MTF oscillators often suffer from visual warping (the live-bar warping bug where only the very last LTF bar gets updated, creating a jagged, diagonal line across the active HTF block). The suite resolves this by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step (both $\%K$ and Signal lines) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strict Non-Repainting State Safety on MTF Live Ticks (State Mocking)

To support real-time updating without modifying closed historical wave states (which would cause severe repainting and backtesting discrepancies), the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive Laguerre and VWAP registers.

### C. Dynamic Volume Routing Pipeline for VWMA Smoothing

To support volume-weighted types (like **VWMA**) for slowing or signal lines, the calculator classes have been overloaded with volume-based `Calculate` signatures. Both standard and MTF indicators query `SYMBOL_VOLUME_LIMIT` to detect if the broker provides Real Volume, convert it to a double array incrementally ($O(1)$ complexity), and pass it down to the calculator, enabling volume-weighted smoothing on custom arrays:

```mql5
g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, ... volume, BufferSlowK_MTF, BufferSignalD_MTF);
```

### D. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 4. Parameters

### A. Core Laguerre Settings

* **Gamma (`InpGamma`):** The damping factor coefficient, controlling the balance between lag and smoothness (Range: $0.0 \dots 1.0$, Default: `0.7`).

* **Applied Price (`InpSourcePrice`):** The applied price source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Fast Version Settings

* **Signal Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `3`).

* **Signal MA Type (`InpSignalMethod`):** Select the MA type for the Signal Line, fully supporting VWMA (Default: `SMA`).

### C. Slow Version Settings

* **Slowing Period (`InpSlowingPeriod`):** The lookback period to smooth the raw %K into the Slow %K line (Default: `3`).

* **Slowing MA Type (`InpSlowingMethod`):** Select the MA type for the Slowing line, fully supporting VWMA (Default: `SMA`).
* **Signal Period (`InpSignalPeriod`):** The lookback period to smooth the Slow %K into the Signal %D line (Default: `3`).
* **Signal MA Type (`InpSignalMethod`):** Select the MA type for the Signal line, fully supporting VWMA (Default: `SMA`).

### D. MTF Specific Parameters

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Laguerre Stochastic on (Default: `PERIOD_H1`).

---

## 5. Usage and Interpretation

### A. Extreme Reversal Climaxes (The 0 / 100 Clings)

Because the Laguerre Stochastic is calculated over a dynamic spectral range, the fastest pole ($L_0$) frequently reaches the absolute boundaries of the scale ($0$ or $100$). This represents maximum cycle exhaustion.

* **Bullish Reversal:** Wait for the main line to reach $0$ (Oversold Climax). Once the main line crosses **above 10 (or 20)**, or **crosses above its Signal Line**, enter a **BUY** position.
* **Bearish Reversal:** Wait for the main line to reach $100$ (Overbought Climax). Once the main line crosses **below 90 (or 80)**, or **crosses below its Signal Line**, enter a **SELL** position.

### B. Centerline Crossovers (50-Level Crossover)

The 50 centerline acts as the structural balance point of the cyclical spectrum.

* **Bullish Bias:** When the Laguerre Stochastic is trading consistently above the 50 level. Seek only long execution.
* **Bearish Bias:** When the Laguerre Stochastic is trading consistently below the 50 level. Seek only short execution.

### C. Top-Down Macro Cycle Alignment (MTF Core Strategy)

1. **Macro Stochastic Cycle (H1/H4):** Apply `Laguerre_Stoch_Slow_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart.
2. **The Trend Alignment:** Identify the macro trend direction based on the H1 MTF main line position relative to the 50 centerline. If the macro line is above 50, only seek buy setups on the lower timeframe.
3. **The Local Entry:** When the local M5 Laguerre Stochastic is deeply oversold ($< 20$) and crosses above its Signal Line while the macro H1 MTF main line is rising, execute high-probability **BUY** entries. This ensures you buy local pullbacks in the direction of the macro cycle with minimal lag.
