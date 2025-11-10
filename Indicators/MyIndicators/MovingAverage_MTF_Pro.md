# Moving Average MTF Professional

## 1. Summary (Introduction)

The `MovingAverage_MTF_Pro` is a versatile multi-timeframe (MTF) version of our universal moving average indicator. It allows a trader to calculate one of the four fundamental moving average types (SMA, EMA, SMMA, LWMA) on a **higher, user-selected timeframe** and project it onto the current, lower-timeframe chart.

This provides a clear, smoothed-out view of the underlying trend from a broader perspective. The higher-timeframe moving average acts as a powerful, dynamic benchmark for identifying major trend direction, support, and resistance, all without needing to switch between different charts.

The indicator is highly flexible:

* The user can select the moving average type from a simple dropdown menu.
* If the current chart's timeframe is selected, it functions identically to the standard `MovingAverage_Pro` indicator.
* It fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculations for each moving average type are standard. The key concept is the multi-timeframe application.

### Core MA Types

* **SMA (Simple Moving Average):** An unweighted average of the last N prices.
* **EMA (Exponential Moving Average):** A weighted average that gives more importance to recent prices.
* **SMMA (Smoothed Moving Average):** A smoothed average, often used in Wilder's indicators, with a longer "memory" than an EMA.
* **LWMA (Linear Weighted Moving Average):** A weighted average that gives linearly more weight to recent prices.

### MTF Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator first retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate the Moving Average on the Higher Timeframe:** The chosen moving average type (e.g., EMA) is calculated recursively or directly using the `htf` price data over the specified period.
3. **Project to Current Chart:** The calculated `htf` moving average values are then mapped to the current chart. This creates a characteristic "step-like" line, where each value from the higher timeframe is held constant for the duration of its corresponding bars on the lower timeframe.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability and performance.

* **Universal Calculation Engine (`MovingAverage_Engine.mqh`):** The indicator reuses the exact same, proven calculation engine as the standard `MovingAverage_Pro`. This engine can calculate all four MA types, ensuring mathematical consistency and leveraging our modular design principles.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the full MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `MovingAverage_Pro`, calculating directly on the current chart's data for maximum efficiency.

* **Stability via Full Recalculation:** We employ a full recalculation for both modes, which is the most reliable method for ensuring data integrity, especially when dealing with historical data from different timeframes.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the moving average will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Period (`InpPeriod`):** The lookback period for the moving average.
* **MA Type (`InpMAType`):** A dropdown menu to select the desired moving average type (SMA, EMA, SMMA, LWMA).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The MTF version of a moving average is a cornerstone of multi-timeframe analysis, providing crucial context for lower-timeframe price action.

* **Dynamic Support and Resistance:** The primary use of the MTF MA is as a dynamic, high-level area of support and resistance. When the price on the lower timeframe pulls back to the higher-timeframe MA line, it can present a high-probability entry point in the direction of the larger trend.
* **Major Trend Filter:** The slope and position of the MTF MA line provide a clear view of the dominant trend.
  * If the price is consistently above a rising MTF MA, the market is in a strong uptrend. Traders should focus on buying opportunities.
  * If the price is consistently below a falling MTF MA, the market is in a strong downtrend. Traders should focus on selling opportunities.
* **Confirmation of Breakouts:** A breakout on the lower timeframe that is also supported by the direction of the MTF MA line is a much stronger and more reliable signal.
* **Range Detection:** A flat MTF MA line indicates that the higher timeframe is consolidating, signaling that range-bound strategies might be more appropriate on the lower timeframe.
