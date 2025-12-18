# Adaptive Moving Average (AMA) MTF Pro

## 1. Summary (Introduction)

The `AMA_MTF_Pro` is a multi-timeframe (MTF) version of Perry Kaufman's renowned Adaptive Moving Average. This indicator calculates the AMA on a **higher, user-selected timeframe** and projects its intelligent, adaptive trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying, noise-filtered trend from a broader perspective. The higher-timeframe AMA acts as a superior dynamic benchmark for support, resistance, and overall market direction, as it automatically adjusts its speed to the conditions of that higher timeframe.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `AMA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard AMA, utilizing the **Efficiency Ratio (ER)** to dynamically adjust the smoothing factor. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate AMA on the Higher Timeframe:** The complete AMA calculation (including ER, Scaled Smoothing Constant, and the recursive formula) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` AMA values are mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's adaptive trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`AMA_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `AMA_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffer for the higher timeframe is maintained globally, preserving the recursive state of the AMA between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `AMA_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the AMA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **AMA Period (`InpAmaPeriod`):** The lookback period for the Efficiency Ratio calculation. (Default: `10`).
* **Fast EMA Period (`InpFastEmaPeriod`):** The period for the fastest EMA speed. (Default: `2`).
* **Slow EMA Period (`InpSlowEmaPeriod`):** The period for the slowest EMA speed. (Default: `30`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of AMA is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Dynamic Support and Resistance:** The primary use of the MTF AMA is as a dynamic, high-level area of support and resistance. Because AMA adapts to the higher timeframe's volatility, the levels it provides are often more respected by price than a standard MTF moving average.

* **Major Trend and Range Filter:** The state of the MTF AMA line provides a clear, smoothed-out view of the dominant market condition.
  * If the price is consistently above a **rising** MTF AMA, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF AMA, the market is in a strong downtrend.
  * If the MTF AMA line **flattens out**, it is a very strong signal that the higher timeframe has entered a consolidation or ranging phase. This suggests that breakout strategies on the lower timeframe are likely to fail.

* **Confirmation of Breakouts:** A breakout on the lower timeframe that is supported by a steepening slope of the MTF AMA line is a much stronger and more reliable signal.
