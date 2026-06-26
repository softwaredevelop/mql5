# Welles Wilder ADX Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Welles Wilder ADX Pro Suite** is an institutional-grade trend-intensity and direction analysis suite comprising two advanced technical indicators: `ADX_Pro` (Standard) and `ADX_MTF_Pro` (Multi-Timeframe).

Originally developed by J. Welles Wilder in his seminal 1978 work, the Average Directional Index (ADX) is designed to measure the **absolute strength of a trend**, completely independent of its direction. It does not identify whether the market is bullish or bearish, but quantifies its momentum.

The ADX system consists of three distinct lines:

* **ADX Line (DodgerBlue):** The main line that quantifies trend strength.
* **+DI (Positive Directional Indicator - OliveDrab):** Measures the strength of the upward price movement.
* **-DI (Negative Directional Indicator - Tomato):** Measures the strength of the downward price movement.

Our ADX Suite is a highly optimized, professional-grade implementation that combines Welles Wilder's definition-true smoothing with modern object-oriented design and Heikin Ashi candle smoothing integration.

---

## 2. Mathematical Foundations and Calculation Logic

The ADX calculation is a complex, multi-stage process that relies heavily on Wilder's smoothing technique (a specific type of Smoothed or Running Moving Average - SMMA/RMA).

### Required Components

* **ADX Period ($P$):** The lookback period used for all internal calculations (Default: `14`).
* **Directional Movement (+DM, -DM):** Measures the portion of the current bar's range that is outside the previous bar's range.
* **True Range (TR):** The standard measure of a single bar's volatility.

### Calculation Steps (Algorithm)

1. **Calculate Directional Movement and True Range:** For each period, calculate:
    * $\text{Up Move}_t = \text{High}_t - \text{High}_{t-1}$
    * $\text{Down Move}_t = \text{Low}_{t-1} - \text{Low}_t$
    * If $\text{Up Move}_t > \text{Down Move}_t$ and $\text{Up Move}_t > 0$, then $\text{+DM}_t = \text{Up Move}_t$, else $\text{+DM}_t = 0$.
    * If $\text{Down Move}_t > \text{Up Move}_t$ and $\text{Down Move}_t > 0$, then $\text{-DM}_t = \text{Down Move}_t$, else $\text{-DM}_t = 0$.
    * $\text{True Range (TR)}_t = \max[(\text{High}_t - \text{Low}_t), \text{Abs}(\text{High}_t - \text{Close}_{t-1}), \text{Abs}(\text{Low}_t - \text{Close}_{t-1})]$

2. **Smooth +DM, -DM, and TR:** Apply Wilder's smoothing method over period $P$.
    * **Initialization:** The first value is the sum of the first $P$ periods:
        $$\text{Smoothed +DM}_{P} = \sum_{i=1}^{P} \text{+DM}_i$$
    * **Recursive Calculation:**
        $$\text{Smoothed +DM}_t = \text{Smoothed +DM}_{t-1} - \frac{\text{Smoothed +DM}_{t-1}}{P} + \text{+DM}_t$$
    * *(The same logic applies to -DM and TR)*

3. **Calculate Directional Indicators (+DI, -DI):**
    $$\text{+DI}_t = 100 \times \frac{\text{Smoothed +DM}_t}{\text{Smoothed TR}_t}$$
    $$\text{-DI}_t = 100 \times \frac{\text{Smoothed -DM}_t}{\text{Smoothed TR}_t}$$

4. **Calculate the Directional Index (DX):**
    $$\text{DX}_t = 100 \times \frac{\text{Abs}(\text{+DI}_t - \text{-DI}_t)}{\text{+DI}_t + \text{-DI}_t}$$

5. **Calculate the Final ADX:** The ADX is a Wilder-smoothed moving average of the DX.
    * **Initialization:** The first ADX value is a simple average of the first $P$ DX values (calculated starting at index $2P-1$).
    * **Recursive Calculation:**
        $$\text{ADX}_t = \frac{(\text{ADX}_{t-1} \times (P-1)) + \text{DX}_t}{P}$$

---

## 3. Advanced MQL5 MTF Implementation Details

### A. Shared Core Engines

The fundamental calculation of Directional Movement (+DI, -DI) is outsourced to a shared engine (`DMI_Engine.mqh`). This ensures that the ADX and other DMI-based indicators use the exact same, validated mathematical core, eliminating code duplication and potential inconsistencies. The `CADXCalculator` uses **Composition** to include the `CDMIEngine`.

### B. Forming LTF Block Flat-Force (The Warping Solution)

`ADX_MTF_Pro` resolves the classic MTF live-bar warping bug (where only the very last LTF bar gets updated, creating a jagged, diagonal line across the active HTF block) by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step (Middle, Upper, and Lower bands) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Strict Non-Repainting State Safety on MTF Live Ticks (State Mocking)

Welles Wilder's smoothing equations (+DM, -DM, TR, and DX) are highly stateful. To support real-time updating without modifying closed historical states (which would cause severe repainting and backtesting discrepancies), the MTF indicator utilizes a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive Wilder's smoothing registers.

### D. Asynchronous Timer Guard & Hybrid HA Pricing

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **Heikin Ashi Support:** Standard pricing is used by default. An inherited `CADXCalculator_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data, leveraging the same optimized engine.

---

## 4. Parameters

### A. Timeframe Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Welles Wilder ADX on (Default: `PERIOD_H1`).

### B. Core ADX Settings

* **ADX Period (`InpPeriodADX`):** The lookback period used for all internal calculations. Wilder's original recommendation and the most common value is `14` (Default: `14`).

* **Candle Source (`InpCandleSource`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `CANDLE_STANDARD`).

---

## 5. Usage and Interpretation

* **Trend Strength:** The primary signal is the ADX line itself (DodgerBlue).
  * **ADX < 25:** Weak or non-existent trend (ranging market). Trend-following strategies should be avoided.
  * **ADX > 25:** Strong trend. The higher the ADX, the stronger the trend.
  * **Rising ADX:** The trend is gaining strength.
  * **Falling ADX:** The trend is losing strength.
* **Trend Direction (+DI and -DI Crossover):**
  * When the **+DI line (green) crosses above the -DI line (red)**, it suggests the start of a bullish trend.
  * When the **-DI line (red) crosses above the +DI line (green)**, it suggests the start of a bearish trend.
* **Trade Confirmation:** A common strategy is to wait for a +DI/-DI crossover and then confirm that the ADX line is above 25 (or rising) before entering a trade. This helps to filter out signals that occur in weak or non-trending markets.

### C. Top-Down Macro Trend Alignment (MTF Core Strategy)

1. **Macro Trend Filter (H1/H4):** Apply `ADX_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Trend Strength Alignment:** Identify if the macro timeframe is trending strongly. The **H1 MTF ADX** must be above 25.
3. **The Local Entry:** If the H1 MTF +DI is above the -DI (bullish trend), only seek long entries on the lower M5 timeframe. Execute long trades when local LTF momentum shifts, avoiding counter-trend positions. If H1 MTF ADX is below 25 (ranging), avoid all trend-following breakouts and instead run range-trading grid bots on the lower timeframe.
