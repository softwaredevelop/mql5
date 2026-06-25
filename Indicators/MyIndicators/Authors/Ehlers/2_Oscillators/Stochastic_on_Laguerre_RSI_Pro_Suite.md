# Stochastic on Laguerre RSI Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Stochastic on Laguerre RSI Pro Suite** is an institutional-grade, high-performance separate window oscillator suite comprising four advanced indicators:

* `StochasticFast_on_LaguerreRSI_Pro` (Standard Fast %K + Signal %D)
* `StochasticFast_on_LaguerreRSI_MTF_Pro` (Multi-Timeframe Fast %K + Signal %D)
* `StochasticSlow_on_LaguerreRSI_Pro` (Standard Smoothed %K + Signal %D)
* `StochasticSlow_on_LaguerreRSI_MTF_Pro` (Multi-Timeframe Smoothed %K + Signal %D)

This suite represents a highly advanced mathematical fusion of John F. Ehlers' digital signal processing (Laguerre RSI) and George Lane's classical cycle detection (Stochastic).

While a standard Stochastic oscillator is calculated directly on raw price series (which are highly volatile and prone to erratic spikes), the **Stochastic on Laguerre RSI** is calculated **on top of the calculated Laguerre RSI output buffer**.

By applying stochastic range normalization to the already smoothed, low-lag Laguerre RSI line, the suite filters out high-frequency noise and consolidations with near-zero latency, delivering exceptionally clean, reliable cyclical signals and cross-overs at overbought/oversold extremes.

---

## 2. Mathematical Foundations and Calculation Logic

The calculation is a multi-stage process starting from raw prices and progressing through Laguerre spectral transformation to stochastic range mapping.

### A. Step 1: Ehlers' Laguerre RSI Calculation

First, Ehlers' 4-Pole Laguerre filter registers ($L_{0,t} \dots L_{3,t}$) are calculated recursively using a damping factor $\gamma$ (`InpGamma`). The directional up-thrust ($cu$) and down-thrust ($cd$) are computed to output the smoothed Laguerre RSI:

$$\text{LRSI}_t = 100 \times \frac{cu_t}{cu_t + cd_t}$$

### B. Step 2: Stochastic %K Range Mapping

The highest high and lowest low of the Laguerre RSI buffer are calculated over a lookback window $K$ (`InpKPeriod`):

$$\text{Highest LRSI}_t = \max(\text{LRSI}_{t \dots t-K+1})$$

$$\text{Lowest LRSI}_t = \min(\text{LRSI}_{t \dots t-K+1})$$

The raw stochastic $\%K$ position of the current Laguerre RSI value within this dynamic range is calculated as:

$$\%K_{\text{raw}, t} = 100 \times \frac{\text{LRSI}_t - \text{Lowest LRSI}_t}{\text{Highest LRSI}_t - \text{Lowest LRSI}_t}$$

### C. Step 3: Fast vs. Slow Smoothing (Slowing & Signal %D)

* **Fast Stochastic Version:**
  The raw $\%K$ is plotted directly as the main line:
  $$\%K_{\text{fast}, t} = \%K_{\text{raw}, t}$$
  The Signal $\%D$ line is computed by smoothing $\%K_{\text{fast}}$ over a signal period $D$ (`InpDPeriod`):
  $$\%D_{\text{fast}, t} = \text{MA}(\%K_{\text{fast}}, D) \quad \text{using selected MA Type}$$

* **Slow Stochastic Version:**
  The raw $\%K$ is smoothed first over a slowing period $S$ (`InpSlowingPeriod`) to yield the Slow $\%K$:
  $$\%K_{\text{slow}, t} = \text{MA}(\%K_{\text{raw}}, S) \quad \text{using selected MA Type}$$
  The Signal $\%D$ line is computed by smoothing $\%K_{\text{slow}}$ over a signal period $D$ (`InpDPeriod`):
  $$\%D_{\text{slow}, t} = \text{MA}(\%K_{\text{slow}}, D) \quad \text{using selected MA Type}$$

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

By forcing a full-block rewrite on every live tick, the active HTF step (both $\%K$ and $\%D$ lines) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strict Non-Repainting State Safety on MTF Live Ticks (State Mocking)

To support real-time updating without modifying closed historical wave states (which would cause severe repainting and backtesting discrepancies), the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive Laguerre, VWMA, and standard deviation registers.

### C. Asynchronous Volume Routing Pipeline for VWMA Smoothing

To support volume-weighted types (like **VWMA**) for slowing or signal lines, the calculator classes have been overloaded with volume-based `Calculate` signatures. Both standard and MTF indicators query `SYMBOL_VOLUME_LIMIT` to detect if the broker provides Real Volume, convert it to a double array incrementally ($O(1)$ complexity), and pass it down to the calculator, enabling volume-weighted smoothing on custom arrays:

```mql5
g_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, ... volume, BufferK_MTF, BufferD_MTF);
```

### D. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 4. Parameters

### A. Core Laguerre RSI Settings

* **Gamma (`InpGamma`):** The damping factor coefficient of the underlying Laguerre Filter (Range: $0.0 \dots 1.0$, Default: `0.5`).
* **Applied Price (`InpSourcePrice`):** The price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Stochastic Settings

* **Lookback Period (`InpKPeriod`):** The lookback window ($K$) used to find the highest and lowest Laguerre RSI values (Default: `14`).
* **Slowing Period (`InpSlowingPeriod` - Slow Version Only):** The lookback period used to smooth the raw %K into the Slow %K line (Default: `3`).
* **Signal Period (`InpDPeriod`):** The lookback period used to smooth the %K into the Signal %D line (Default: `3`).

### C. MA Smoothing Types

* **Slowing MA Type (`InpSlowingMAType` - Slow Version Only):** Select the MA type for the slowing line, fully supporting VWMA (Default: `SMA`).
* **Signal MA Type (`InpDMAType`):** Select the MA type for the Signal line, fully supporting VWMA (Default: `SMA`).

### D. MTF Specific Parameters

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Stochastic on Laguerre RSI on (Default: `PERIOD_H1`).

---

## 5. Usage and Interpretation

### A. Extreme Reversal Triggers (MACD-style crosses)

Because Laguerre RSI is incredibly smooth, applying Stochastic range normalization creates highly structured turning points.

* **Bullish Crossover:** The $\%K$ line (blue) crosses above the $\%D$ Signal Line (red) below the oversold threshold ($< 20$). This represents a high-probability bullish reversal.
* **Bearish Crossover:** The $\%K$ line crosses below the $\%D$ Signal Line above the overbought threshold ($> 80$). This represents a high-probability bearish reversal.

### B. Trend Continuation / Congestion Transitions

* **Momentum Continuation:** If the $\%K$ line crosses above the 50 level and holds, it indicates strong bullish momentum. If it crosses below 50, it indicates bearish momentum.
* **Congestion Squeeze:** If the $\%K$ and $\%D$ lines contract and run completely flat near the 50 level, the market is in a tight sideways compression, often setting up for a major breakout.

### C. Top-Down Cyclical Momentum Alignment (MTF Core Strategy)

1. **Macro Cycle Direction (H1/H4):** Apply `StochasticSlow_on_LaguerreRSI_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Trend Alignment:** Identify the macro trend direction based on the position of the macro **H1 MTF Slow %K** relative to the 50 centerline. If the macro line is above 50, only seek buy setups on the lower timeframe.
3. **The Local Entry:** When the local M5 Stochastic on Laguerre RSI is deeply oversold ($< 20$) and crosses above its Signal Line while the macro H1 MTF main line is rising, execute high-probability **BUY** entries. This allows you to trade lower timeframe cyclical pullbacks in the direction of the macro cycle with minimal lag.
