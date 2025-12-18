# Hull Moving Average (HMA) MTF Pro

## 1. Summary (Introduction)

The `HMA_MTF_Pro` is a multi-timeframe (MTF) version of the Hull Moving Average. This indicator calculates the HMA on a **higher, user-selected timeframe** and projects its extremely responsive, low-lag trendline onto the current, lower-timeframe chart.

This allows traders to visualize the underlying trend from a broader perspective. The higher-timeframe HMA acts as a superior dynamic benchmark for support, resistance, and overall market direction, leveraging Alan Hull's formula to reduce lag while maintaining smoothness.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `HMA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard HMA, utilizing three separate Weighted Moving Averages (WMAs) to eliminate lag. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the user-selected higher timeframe (`htf`).
2. **Calculate HMA on the Higher Timeframe:** The complete multi-stage HMA calculation (WMA(n/2), WMA(n), WMA(sqrt(n))) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` HMA values are mapped to the current chart, creating a characteristic "step-like" line that represents the higher timeframe's trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`HMA_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `HMA_Pro`. This ensures mathematical consistency across all versions.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffers for the higher timeframe (including the intermediate `Raw HMA`) are maintained globally, preserving the state between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This ensures the indicator remains lightweight and high-performance even on heavy load.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `HMA_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the HMA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **HMA Period (`InpPeriodHMA`):** The main lookback period for the indicator. (Default: `14`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF version of HMA is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Major Trend Filter:** The slope and position of the MTF HMA line provide a clear view of the dominant market condition.
  * If the price is consistently above a **rising** MTF HMA, the market is in a strong uptrend.
  * If the price is consistently below a **falling** MTF HMA, the market is in a strong downtrend.

* **Dynamic Support and Resistance:** The MTF HMA line acts as a strong support/resistance level. Because HMA is so responsive, it often hugs the price action closely, providing tight dynamic stops.

* **Early Reversal Warning:** A turn in the MTF HMA line (e.g., from rising to falling) is often one of the earliest reliable signals that the higher timeframe trend is changing.
