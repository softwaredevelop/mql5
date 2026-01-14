# Adaptive Laguerre Filter MTF Professional

## 1. Summary (Introduction)

The `Laguerre_Filter_Adaptive_MTF_Pro` is a multi-timeframe (MTF) version of John Ehlers' Adaptive Laguerre Filter. This indicator calculates the filter on a **higher, user-selected timeframe** and projects its smooth, responsive trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying trend from a broader perspective. The higher-timeframe Adaptive Laguerre acts as a superior dynamic benchmark for support, resistance, and overall market direction, as it automatically adjusts its speed (gamma) based on the measured market cycle period of that higher timeframe.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `Laguerre_Filter_Adaptive_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard Adaptive Laguerre Filter, utilizing the Homodyne Discriminator to measure the dominant cycle period and adjust the filter's gamma. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate Filter on the Higher Timeframe:** The complete adaptive calculation (including cycle measurement and recursive filtering) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` filter values are mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`Laguerre_Filter_Adaptive_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `Laguerre_Filter_Adaptive_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffers for the higher timeframe (Cycle Period, Gamma, Filter State) are maintained globally, preserving the recursive state between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `Laguerre_Filter_Adaptive_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the filter will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of the Adaptive Laguerre Filter is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Major Trend Filter:** The slope and position of the MTF filter line provide a clear view of the dominant market condition.
  * If the price is consistently above a **rising** MTF filter, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF filter, the market is in a strong downtrend.

* **Dynamic Support and Resistance:** The MTF filter line acts as a strong support/resistance level. Because the Adaptive Laguerre adjusts to the cycle period, it often hugs the price action more effectively than a standard MTF moving average.
