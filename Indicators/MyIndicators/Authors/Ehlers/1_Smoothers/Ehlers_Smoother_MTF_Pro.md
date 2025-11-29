# Ehlers Smoother MTF Pro

## 1. Summary (Introduction)

The `Ehlers_Smoother_MTF_Pro` is a multi-timeframe (MTF) version of John Ehlers' advanced digital signal processing filters. This indicator calculates either the **SuperSmoother** or the **UltimateSmoother** on a higher, user-selected timeframe and projects the resulting smoothed line onto the current, lower-timeframe chart.

These filters are designed to provide superior smoothing with significantly less lag than traditional moving averages. By applying them on a higher timeframe, traders can visualize a clean, noise-reduced representation of the underlying trend, which can serve as a powerful dynamic benchmark for analysis on their primary trading chart.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `Ehlers_Smoother_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculations are identical to the standard Ehlers Smoothers, which are advanced second-order Infinite Impulse Response (IIR) filters.

### Core Concepts

* **SuperSmoother:** A two-pole Gaussian filter designed to provide excellent smoothing with minimal lag (typically half that of an equivalent EMA).
* **UltimateSmoother:** A more complex, three-pole filter that aims to provide even greater smoothing and noise rejection than the SuperSmoother, making it ideal for identifying longer-term trends.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator first retrieves the OHLC price data for the user-selected higher timeframe.
2. **Calculate Filter Coefficients:** Based on the user-selected `Period`, the filter's internal coefficients (`a1`, `b1`, `c1`, etc.) are calculated. These coefficients determine the filter's responsiveness and smoothing characteristics.
3. **Calculate the Smoother on the Higher Timeframe:** The selected filter (SuperSmoother or UltimateSmoother) is calculated recursively using the higher timeframe's price data. The formula uses the current and previous price values, as well as the filter's own previous output values, to generate the new smoothed value.
4. **Project to Current Chart:** The calculated higher-timeframe Smoother values are then mapped to the current chart, creating a "step-like" line where each value from the higher timeframe is held constant for the duration of its corresponding bars on the lower timeframe.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Stable Calculation Engine (`Ehlers_Smoother_Calculator.mqh`):** The indicator reuses the exact same, proven calculation engine as the standard `Ehlers_Smoother_Pro`. Crucially, this engine implements **correct state management** for the recursive filter's internal variables (`m_f1`, `m_f2`), ensuring a stable and accurate output.

* **Optimized Incremental Calculation:**
    Unlike basic MTF indicators that download and recalculate the entire higher-timeframe history on every tick, this indicator employs a sophisticated incremental algorithm.
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffer for the higher timeframe (`BufferFilter_HTF_Internal`) is maintained globally, preserving the recursive state of the IIR filter between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data, drastically reducing CPU usage.
  * This results in **O(1) complexity** per tick, ensuring the indicator remains lightweight even when running on multiple charts simultaneously.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `Ehlers_Smoother_Pro`, calculating directly on the current chart's data for maximum efficiency.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the Smoother will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Smoother Type (`InpSmootherType`):** Allows the user to select between the two available filters.
  * `SUPERSMOOTHER`: Faster, more responsive filter.
  * `ULTIMATESMOOTHER`: Slower, smoother filter for longer-term trends.
* **Period (`InpPeriod`):** The lookback period for the filter. This is analogous to a moving average period and controls the degree of smoothing.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of the Ehlers Smoother is a powerful tool for contextual analysis and trend filtering.

* **Dynamic Support and Resistance:** The primary use of the MTF Smoother is as a dynamic, high-level area of support and resistance. When the price on the lower timeframe pulls back to the higher-timeframe Smoother line, it can present a high-probability entry point in the direction of the larger trend.
* **Major Trend Filter:** The slope and position of the MTF Smoother line provide a clear, noise-free view of the dominant trend.
  * If the price is consistently above a rising MTF Smoother, the market is in a strong uptrend. Focus on buying opportunities.
  * If the price is consistently below a falling MTF Smoother, the market is in a strong downtrend. Focus on selling opportunities.
* **Confirmation of Breakouts:** A breakout on the lower timeframe that is also supported by the direction of the MTF Smoother line is a much stronger signal.
* **Range Detection:** A flat MTF Smoother line indicates that the higher timeframe is consolidating, signaling that range-bound strategies might be more appropriate on the lower timeframe.
