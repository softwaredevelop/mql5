# Gann HiLo Activator MTF Pro

## 1. Summary (Introduction)

The `Gann_HiLo_MTF_Pro` is a multi-timeframe (MTF) version of the Gann HiLo Activator. This indicator calculates the trend direction and trailing stop levels on a **higher, user-selected timeframe** and projects them onto the current, lower-timeframe chart.

This allows traders to visualize the major trend and key support/resistance levels from a broader perspective, filtering out the noise of the lower timeframe. The higher-timeframe Gann HiLo acts as a robust dynamic stop-loss and trend filter.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `Gann_HiLo_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard Gann HiLo Activator, based on moving averages of Highs and Lows. The key innovation here is the multi-timeframe application.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC data for the user-selected higher timeframe (`htf`).
2. **Calculate Gann HiLo on the Higher Timeframe:** The complete calculation (MA of Highs, MA of Lows, Trend Logic) is performed using the `htf` price data.
3. **Project to Current Chart:** The calculated `htf` values (both the price level and the trend color) are mapped to the current chart using precise time-based alignment (`iBarShift`), creating a characteristic "step-like" line that represents the higher timeframe's trend.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`Gann_HiLo_Calculator.mqh`):** The indicator reuses the exact same calculation engine as the standard `Gann_HiLo_Pro`. This ensures mathematical consistency across all versions.

* **Engine Integration (`MovingAverage_Engine.mqh`):** Since the core calculator now uses the unified MA engine, the MTF version automatically benefits from all supported MA types (SMA, EMA, SMMA, LWMA, DEMA, TEMA, TMA).

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic MTF indicators that recalculate the entire history on every tick, this indicator employs a sophisticated incremental algorithm:
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`g_htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffers for the higher timeframe (HiAvg, LoAvg, Trend) are maintained globally, preserving the state between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `Gann_HiLo_Pro`.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the Gann HiLo will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Period (`InpPeriod`):** The lookback period for the high and low moving averages. (Default: `10`).
* **MA Method (`InpMAMethod`):** The type of moving average to use. Supports all standard and advanced types (SMA, EMA, DEMA, TEMA, etc.). (Default: `SMA`).
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation.
  * `CANDLE_STANDARD`: Uses the standard chart's High, Low, and Close.
  * `CANDLE_HEIKIN_ASHI`: Uses the smoothed Heikin Ashi High, Low, and Close.

## 5. Usage and Interpretation

The MTF version of Gann HiLo is an exceptionally powerful tool for multi-timeframe trend analysis.

* **Major Trend Filter:** The color of the MTF Gann HiLo line provides a clear view of the dominant market condition.
  * **Blue Line (Below Price):** The higher timeframe is in an uptrend. Look for buy setups on the lower timeframe.
  * **Red Line (Above Price):** The higher timeframe is in a downtrend. Look for sell setups on the lower timeframe.

* **Dynamic Support and Resistance:** The MTF Gann HiLo line acts as a strong support/resistance level. Price often bounces off this level during pullbacks in a strong trend.

* **Trailing Stop-Loss:** For swing traders, the MTF Gann HiLo provides an excellent trailing stop level that is less likely to be hit by random noise on the lower timeframe.
