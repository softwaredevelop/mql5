# KAMA MTF Professional

## 1. Summary (Introduction)

The `KAMA_MTF_Pro` is a multi-timeframe (MTF) version of Perry Kaufman's renowned Adaptive Moving Average. This indicator calculates the KAMA on a **higher, user-selected timeframe** and projects its intelligent, adaptive trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying, noise-filtered trend from a broader perspective. The higher-timeframe KAMA acts as a superior dynamic benchmark for support, resistance, and overall market direction, as it automatically adjusts its speed to the conditions of that higher timeframe.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `KAMA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard KAMA, which uses the **Efficiency Ratio (ER)** to adjust its speed. The key concept is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator first retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate KAMA on the Higher Timeframe:** The complete KAMA calculation (including ER, dynamic smoothing constant, and the recursive formula) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` KAMA values are then mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's adaptive trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`KAMA_Calculator.mqh`):** The indicator reuses the exact same, proven calculation engine as the standard `KAMA_Pro`. This engine, with its robust state management for the recursive KAMA formula, ensures mathematical consistency and leverages our modular design principles.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the full MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `KAMA_Pro`.

* **Stability via Full Recalculation:** We employ a full recalculation for both modes, which is the most reliable method for a state-dependent, recursive filter like KAMA.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the KAMA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **ER Period (`InpErPeriod`):** The lookback period for the Efficiency Ratio calculation. Kaufman's standard value is `10`.
* **Fast EMA Period (`InpFastEmaPeriod`):** The period for the fastest EMA speed. Kaufman's standard value is `2`.
* **Slow EMA Period (`InpSlowEmaPeriod`):** The period for the slowest EMA speed. Kaufman's standard value is `30`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of KAMA is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Superior Dynamic Support and Resistance:** The primary use of the MTF KAMA is as a dynamic, high-level area of support and resistance. Because KAMA adapts to the higher timeframe's volatility, the levels it provides are often more respected by price than a standard MTF moving average.

* **Major Trend and Range Filter:** The state of the MTF KAMA line provides a clear, smoothed-out view of the dominant market condition.
  * If the price is consistently above a **rising** MTF KAMA, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF KAMA, the market is in a strong downtrend.
  * If the MTF KAMA line **flattens out**, it is a very strong signal that the higher timeframe has entered a consolidation or ranging phase. This is a crucial piece of information, suggesting that breakout strategies on the lower timeframe are likely to fail and range-bound strategies may be more appropriate.

* **Confirmation of Breakouts:** A breakout on the lower timeframe that is supported by a steepening slope of the MTF KAMA line is a much stronger and more reliable signal.
