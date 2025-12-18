# Arnaud Legoux Moving Average (ALMA) MTF Pro

## 1. Summary (Introduction)

The `ALMA_MTF_Pro` is a multi-timeframe (MTF) version of the Arnaud Legoux Moving Average. This indicator calculates the ALMA on a **higher, user-selected timeframe** and projects its high-fidelity, low-lag trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying trend from a broader perspective. The higher-timeframe ALMA acts as a superior dynamic benchmark for support, resistance, and overall market direction, leveraging the Gaussian filter's ability to reduce lag while maintaining smoothness.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `ALMA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard ALMA, utilizing a Gaussian distribution for its weights. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate ALMA on the Higher Timeframe:** The complete ALMA calculation (using Gaussian weights based on Offset and Sigma) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` ALMA values are mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`ALMA_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `ALMA_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffer for the higher timeframe is maintained globally, preserving the state between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `ALMA_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the ALMA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Window Size / Period (`InpAlmaPeriod`):** The lookback period for the moving average. (Default: `9`).
* **Offset (`InpAlmaOffset`):** Controls the focus of the moving average (0 to 1). (Default: `0.85`).
* **Sigma (`InpAlmaSigma`):** Controls the smoothness of the moving average. (Default: `6.0`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of ALMA is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Dynamic Support and Resistance:** The primary use of the MTF ALMA is as a dynamic, high-level area of support and resistance. Because ALMA reduces lag, the levels it provides are often more responsive than a standard MTF moving average.

* **Major Trend Filter:** The slope and position of the MTF ALMA line provide a clear view of the dominant market condition.
  * If the price is consistently above a **rising** MTF ALMA, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF ALMA, the market is in a strong downtrend.

* **Confirmation of Breakouts:** A breakout on the lower timeframe that is supported by the direction of the MTF ALMA line is a much stronger and more reliable signal.
