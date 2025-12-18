# McGinley Dynamic MTF Pro

## 1. Summary (Introduction)

The `McGinleyDynamic_MTF_Pro` is a multi-timeframe (MTF) version of the McGinley Dynamic indicator. This indicator calculates the McGinley Dynamic on a **higher, user-selected timeframe** and projects its responsive, market-speed-adjusted trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying trend from a broader perspective. The higher-timeframe McGinley Dynamic acts as a superior dynamic benchmark for support, resistance, and overall market direction, as it automatically adjusts its speed to the conditions of that higher timeframe.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `McGinleyDynamic_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard McGinley Dynamic, utilizing a self-adjusting smoothing factor. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate McGinley Dynamic on the Higher Timeframe:** The complete recursive calculation (including the speed-adjustment ratio) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` values are mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`McGinleyDynamic_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `McGinleyDynamic_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffer for the higher timeframe is maintained globally, preserving the recursive state of the McGinley Dynamic between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `McGinleyDynamic_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the McGinley Dynamic will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Length (`InpLength`):** The base period for the indicator. (Default: `14`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of McGinley Dynamic is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Major Trend Filter:** The slope and position of the MTF McGinley line provide a clear view of the dominant market condition.
  * If the price is consistently above a **rising** MTF McGinley, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF McGinley, the market is in a strong downtrend.

* **Dynamic Support and Resistance:** The MTF McGinley line acts as a strong support/resistance level. Because it adjusts to market speed, it often hugs the price action more effectively than a standard MTF moving average, reducing false breakouts.

* **Trend Alignment:** Use the MTF McGinley to align your lower-timeframe entries with the higher-timeframe momentum. For example, only take long trades on the M5 chart when the H1 McGinley Dynamic is rising.
