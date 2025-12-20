# True Strength Index (TSI) Indicator Family

## 1. Summary (Introduction)

The True Strength Index (TSI), developed by William Blau, is a momentum oscillator designed to provide a smoother and more reliable measure of market momentum.

Our professional implementation is an **indicator family** consisting of two versions, both powered by a single, universal calculation engine:

* **`TSI_Pro`:** The classic implementation, displaying the main TSI line and a signal line.
* **`TSI_Oscillator_Pro`:** A histogram version that displays the difference between the TSI and its signal line, providing a clearer view of momentum acceleration/deceleration.

**Pro Features:** Both indicators support calculations based on either **standard** or **Heikin Ashi** price data, and offer unprecedented customization by allowing traders to replace the standard EMAs with other smoothing methods (like SMA, DEMA, or TEMA) for every step of the calculation.

## 2. Mathematical Foundations and Calculation Logic

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum, and then computing their ratio.

### Required Components

* **Slow Period (N_slow):** The period for the first, longer-term smoothing (standard is 25).
* **Fast Period (N_fast):** The period for the second, shorter-term smoothing (standard is 13).
* **Signal Period:** The period for the moving average signal line.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Price Momentum:** $\text{Momentum}_i = P_i - P_{i-1}$

2. **First Smoothing (Slow Period):** Apply an `N_slow`-period Moving Average to both the `Momentum` and its absolute value.
   * *Classic TSI uses EMA here.*

3. **Second Smoothing (Fast Period):** Apply an `N_fast`-period Moving Average to the results of the first smoothing step.
   * *Classic TSI uses EMA here.*

4. **Calculate the TSI Value:** Divide the double-smoothed momentum by the double-smoothed absolute momentum and scale the result to 100.
    $\text{TSI}_i = 100 \times \frac{\text{MA}_{\text{fast}}(\text{MA}_{\text{slow}}(\text{Momentum}))_i}{\text{MA}_{\text{fast}}(\text{MA}_{\text{slow}}(\text{AbsMomentum}))_i}$

5. **Calculate the Signal Line:** The signal line is a moving average of the TSI line itself.

6. **Calculate the Oscillator (Histogram):** The difference between the TSI and the Signal Line.
    $\text{Oscillator}_i = \text{TSI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The core TSI calculator (`TSI_Calculator.mqh`) is a powerful orchestrator that utilizes **five** instances of our universal `MovingAverage_Engine.mqh`:
    1. **Slow Momentum Engine:** Smooths raw momentum.
    2. **Fast Momentum Engine:** Double-smooths the result.
    3. **Slow Abs Momentum Engine:** Smooths absolute momentum.
    4. **Fast Abs Momentum Engine:** Double-smooths the result.
    5. **Signal Engine:** Smooths the final TSI line.
    This architecture allows for extreme flexibility while maintaining code consistency.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Composition Pattern (Oscillator):**
    The `TSI_Oscillator_Calculator` uses composition instead of inheritance. It internally owns and manages an instance of the main `CTSICalculator`. This ensures that the Oscillator version uses exactly the same mathematical logic as the Line version, guaranteeing 100% consistency.

## 4. Parameters

* **TSI Calculation Settings:**
  * `InpSlowPeriod`: The period for the first smoothing step. (Default: `25`).
  * `InpSlowMAType`: The MA type for the first smoothing. Set to **EMA** for classic TSI behavior. (Default: `EMA`).
  * `InpFastPeriod`: The period for the second smoothing step. (Default: `13`).
  * `InpFastMAType`: The MA type for the second smoothing. Set to **EMA** for classic TSI behavior. (Default: `EMA`).
  * `InpSourcePrice`: The source price for the calculation. (Standard or Heikin Ashi).
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line. (Default: `13`).
  * `InpSignalMAType`: The type of moving average for the signal line. (Default: `EMA`).

## 5. Usage and Interpretation

### `TSI_Pro` (Line Chart)

* **Zero Line Crossovers:** A crossover of the TSI line above the zero line indicates that long-term momentum has turned positive.
* **Signal Line Crossovers:** These provide earlier, shorter-term momentum signals.
* **Overbought/Oversold Levels:** The **+25 and -25** levels are often used to identify extreme momentum.
* **Divergence:** Excellent for spotting divergences between price and momentum.

### `TSI_Oscillator_Pro` (Histogram)

* **Histogram > 0:** The TSI is above its signal line (bullish momentum).
* **Histogram < 0:** The TSI is below its signal line (bearish momentum).
* **Growing Histogram:** Momentum is accelerating.
* **Shrinking Histogram:** Momentum is decelerating (potential reversal warning).
