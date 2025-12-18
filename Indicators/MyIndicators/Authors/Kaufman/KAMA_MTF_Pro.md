# KAMA MTF Professional

## 1. Summary (Introduction)

The `KAMA_MTF_Pro` is a multi-timeframe (MTF) version of Perry Kaufman's renowned Adaptive Moving Average. This indicator calculates the KAMA on a **higher, user-selected timeframe** and projects its intelligent, adaptive trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying, noise-filtered trend from a broader perspective. The higher-timeframe KAMA acts as a superior dynamic benchmark for support, resistance, and overall market direction, as it automatically adjusts its speed to the conditions of that higher timeframe.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `KAMA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard KAMA, which uses the **Efficiency Ratio (ER)** to adjust its speed. The key concept is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate KAMA on the Higher Timeframe:** The complete KAMA calculation (including ER, dynamic smoothing constant, and the recursive formula) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` KAMA values are then mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's adaptive trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions.

* **Modular Calculation Engine (`KAMA_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `KAMA_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffer for the higher timeframe is maintained globally, preserving the recursive state of the KAMA between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `KAMA_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the KAMA will be calculated.
* **ER Period (`InpErPeriod`):** The lookback period for the Efficiency Ratio calculation. (Default: `10`).
* **Fast EMA Period (`InpFastEmaPeriod`):** The period for the fastest EMA speed. (Default: `2`).
* **Slow EMA Period (`InpSlowEmaPeriod`):** The period for the slowest EMA speed. (Default: `30`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

* **Dynamic Support/Resistance:** Use the MTF KAMA as a dynamic floor or ceiling. Price respecting the MTF KAMA suggests the higher timeframe trend is intact.
* **Trend Filter:**
  * **Rising:** Uptrend.
  * **Falling:** Downtrend.
  * **Flat:** The higher timeframe is ranging/consolidating. Avoid trend-following entries on the lower timeframe.
