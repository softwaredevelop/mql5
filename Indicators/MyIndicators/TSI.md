# True Strength Index (TSI) Indicator Family

## 1. Summary (Introduction)

The True Strength Index (TSI), developed by William Blau, is a momentum oscillator designed to provide a smoother and more reliable measure of market momentum by using a double-smoothing mechanism with Exponential Moving Averages (EMAs).

Our professional implementation is an **indicator family** consisting of two versions, both powered by a single, universal calculation engine:

* **`TSI_Pro`:** The classic implementation, displaying the main TSI line and a signal line.
* **`TSI_Oscillator_Pro`:** A histogram version that displays the difference between the TSI and its signal line, providing a clearer view of momentum acceleration/deceleration.

Both indicators support calculations based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum, and then computing their ratio.

### Required Components

* **Slow Period (N_slow):** The period for the first, longer-term EMA smoothing (standard is 25).
* **Fast Period (N_fast):** The period for the second, shorter-term EMA smoothing (standard is 13).
* **Signal Period:** The period for the moving average signal line.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Price Momentum:** $\text{Momentum}_i = P_i - P_{i-1}$
2. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `Momentum` and its absolute value.
3. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
4. **Calculate the TSI Value:** Divide the double-smoothed momentum by the double-smoothed absolute momentum and scale the result to 100.
    $\text{TSI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Momentum}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsMomentum}))_i}$
5. **Calculate the Signal Line:** The signal line is a moving average of the TSI line itself.
6. **Calculate the Oscillator (Histogram):** The difference between the TSI and the Signal Line.
    $\text{Oscillator}_i = \text{TSI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Centralized Calculation Engine (`TSI_Calculator.mqh`):**
    The core of our implementation is a single, powerful calculation engine. This include file contains the complete, definition-true logic for calculating both the TSI and its signal line. It supports both standard and Heikin Ashi data sources through class inheritance (`CTSICalculator` and `CTSICalculator_HA`).

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_ema1_mtm`, `m_ema2_mtm`) persist their state between ticks. This allows the recursive EMA calculations to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag.

* **Specialized Wrapper (`TSI_Oscillator_Calculator.mqh`):**
    The oscillator indicator uses a thin "wrapper" class that utilizes the central engine. The wrapper's role is to:
    1. Instantiate the correct engine (standard or HA).
    2. Call the engine to get the calculated TSI and Signal lines.
    3. Perform one final step: calculate the difference between the two lines to produce the histogram.
    This approach ensures that both the `TSI_Pro` and `TSI_Oscillator_Pro` indicators are always based on the exact same core calculation logic.

* **Composition with MA Engine:** The TSI calculator internally uses our robust `MovingAverage_Engine` to calculate the Signal Line, ensuring consistency with other indicators.

## 4. Parameters

* **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `25`.
* **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `13`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line. Default is `13`.
  * `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

### `TSI_Pro` (Line Chart)

* **Zero Line Crossovers:** A crossover of the TSI line above the zero line indicates that long-term momentum has turned positive. A crossover below indicates negative momentum.
* **Signal Line Crossovers:** These provide earlier, shorter-term momentum signals. A bullish crossover is when the TSI line crosses above its signal line; a bearish crossover is the opposite.
* **Overbought/Oversold Levels:** The **+25 and -25** levels are often used to identify extreme momentum.
* **Divergence:** Due to its smoothness, the TSI is excellent for spotting divergences between price and momentum, which can foreshadow reversals.

### `TSI_Oscillator_Pro` (Histogram)

* **Histogram > 0:** The TSI is above its signal line (bullish momentum).
* **Histogram < 0:** The TSI is below its signal line (bearish momentum).
* **Growing Histogram:** Momentum is accelerating in the current direction.
* **Shrinking Histogram:** Momentum is decelerating, which can be an early warning of a potential crossover and trend change.
