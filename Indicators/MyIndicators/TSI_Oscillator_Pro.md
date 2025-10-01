# TSI Oscillator Professional

## 1. Summary (Introduction)

The TSI Oscillator is a supplementary indicator to the True Strength Index (TSI). It displays the difference between the main TSI line and its signal line as a histogram, providing a clearer visual representation of accelerating and decelerating momentum, similar to the MACD histogram.

Our `TSI_Oscillator_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The TSI Oscillator is the final step in the TSI calculation chain.

### Calculation Steps (Algorithm)

1. **Calculate the TSI Line:** The full, double-smoothed True Strength Index is calculated first.
2. **Calculate the Signal Line:** A moving average of the TSI line is calculated.
3. **Calculate the TSI Oscillator:** The oscillator is the difference between the TSI line and its Signal Line.
    $\text{Oscillator}_i = \text{TSI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Centralized Calculation Engine (`TSI_Engine.mqh`):**
    The core of our implementation is the single, powerful `TSI_Engine.mqh`. This include file contains the complete, definition-true logic for calculating both the TSI and its signal line.

* **Specialized Wrapper (`TSI_Oscillator_Calculator.mqh`):**
    The oscillator indicator uses a thin "wrapper" class that utilizes the central engine. The wrapper's role is to:
    1. Instantiate the correct engine (standard or HA).
    2. Call the engine to get the calculated TSI and Signal lines.
    3. Perform one final step: calculate the difference between the two lines to produce the histogram.
    This approach ensures that both the `TSI_Pro` and `TSI_Oscillator_Pro` indicators are always based on the exact same core calculation logic.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

## 4. Parameters

* **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `25`.
* **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `13`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line. Default is `13`.
  * `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

The TSI Oscillator provides a clear visual of the relationship between the TSI and its signal line.

* **Histogram > 0:** The TSI is above its signal line (bullish momentum).
* **Histogram < 0:** The TSI is below its signal line (bearish momentum).
* **Growing Histogram:** Momentum is accelerating in the current direction.
* **Shrinking Histogram:** Momentum is decelerating, which can be an early warning of a potential crossover and trend change.
* **Zero Line Crossover:** A crossover of the histogram through the zero line corresponds directly to a crossover of the TSI and its signal line, providing clear entry/exit signals.
