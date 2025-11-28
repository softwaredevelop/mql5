# Moving Average Ribbon MTF Pro

## 1. Summary (Introduction)

The `MovingAverage_Ribbon_MTF_Pro` is a specialized multi-timeframe (MTF) analysis tool designed to project a complete Moving Average Ribbon from a higher timeframe onto your current chart.

Unlike standard ribbons that only show trends on the current chart, this indicator allows you to visualize the trend structure of a **higher, user-selected timeframe** (e.g., seeing the H4 ribbon structure while trading on M15). This provides invaluable context for trend alignment and dynamic support/resistance zones.

The indicator calculates four moving average lines on the chosen higher timeframe and projects them onto the current chart as "step-like" lines.

The indicator provides control over:

* **Central Timeframe:** One single higher timeframe that applies to the entire ribbon.
* **Period:** Independent period settings for each of the 4 lines.
* **MA Type:** Independent type settings (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA) for each of the 4 lines.
* **Price Source:** Standard or Heikin Ashi.

## 2. Mathematical Foundations and Calculation Logic

The indicator performs four independent MTF moving average calculations based on a shared higher timeframe.

1. **Fetch Higher Timeframe Data:** The indicator retrieves the OHLC price data for the single user-selected higher timeframe (`InpUpperTimeframe`).
2. **Calculate the Moving Averages:** Four separate moving averages are calculated on this higher timeframe data, using their respective periods and types.
3. **Project to Current Chart:** All four calculated series are mapped to the current chart. Each value from the higher timeframe is held constant for the duration of its corresponding bars on the lower timeframe, creating the visual "step" effect.

## 3. MQL5 Implementation Details

This indicator is built on a robust, `iCustom()`-free, and highly modular architecture.

* **Modular "Manager" Calculator (`MovingAverage_Ribbon_MTF_Calculator.mqh`):** The main engine uses the composition design pattern. It contains four independent instances of the `CSingleMAMTFCalculator` helper class.
  * Even though they share the same source timeframe, each line is calculated independently to allow for different MA types (e.g., mixing EMA and SMA) and periods.

* **Optimized Incremental Calculation:**
    The indicator employs a sophisticated incremental algorithm to ensure high performance.
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately.
  * **Persistent Buffers:** The internal buffers for recursive calculations (EMA, SMMA, DEMA, TEMA) persist between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data.
  * This results in **O(1) complexity** per tick, ensuring the indicator remains lightweight even when running on multiple charts.

* **No External Dependencies:** The entire calculation is self-contained. It directly fetches the required higher-timeframe price data using built-in `Copy...` functions.

## 4. Parameters

* **Timeframe & Price Source:**
  * **`InpUpperTimeframe`:** The single higher timeframe on which the entire ribbon will be calculated. If set to `PERIOD_CURRENT`, it behaves like a standard ribbon.
  * **`InpSourcePrice`:** The source price for all calculations (Standard or Heikin Ashi).

* **MA 1-4 Settings:**
  * **`InpPeriod1` - `InpPeriod4`:** The lookback period for each line.
  * **`InpMAType1` - `InpMAType4`:** The MA type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA) for each line.

## 5. Usage and Interpretation

The MTF Ribbon provides crucial context for lower-timeframe price action.

* **Trend Alignment:** Use the MTF Ribbon to ensure you are trading in the direction of the higher timeframe's momentum. If the H4 ribbon (displayed on your M15 chart) is expanding and sloping up, look primarily for buy setups.
* **Dynamic Support/Resistance Zones:** The space between the MTF lines acts as a strong support/resistance zone. When price pulls back to these "steps," it often presents a high-probability entry point.
* **Range Detection:** When the MTF ribbon lines become flat and intertwined, it indicates that the higher timeframe is in a consolidation phase.
