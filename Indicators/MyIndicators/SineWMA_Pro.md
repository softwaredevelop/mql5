# Sine Weighted Moving Average (Sine WMA) Professional

## 1. Summary (Introduction)

The Sine Weighted Moving Average (Sine WMA) is a specialized type of weighted moving average that uses a sine wave function to assign weights to price data. It was developed as an advanced smoothing filter, designed to reduce lag and provide a cleaner representation of the market's underlying trend.

The Sine WMA is a **symmetrical, zero-lag filter**. It achieves this by assigning the heaviest weights to the price data in the middle of the lookback period. The result is an exceptionally smooth line that acts as the "center of gravity" for the price action.

Our `SineWMA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Sine WMA calculates a weighted average where the weights are derived from a sine function, creating a smooth, bell-shaped weighting curve.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **Source Price:** The price series used for calculation.

### Calculation Steps (Algorithm)

1. **Generate Sine Weights:** For a given period `N`, the weight for each bar `i` (where `i` ranges from 0 to N-1) is calculated using the sine function.
    * $Weight_i = \sin\left(\frac{\pi \cdot (i+1)}{N+1}\right)$

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding sine-based weights.
    * $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated sine weights.
    * $\text{Sum of Weights} = \sum_{i=0}^{N-1} Weight_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    * $\text{Sine WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`SineWMA_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CSineWMACalculator`**: The base class that performs the full calculation on a given source price.
  * **`CSineWMACalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Efficient Weight Generation:** The sine-based weights are calculated only once during the indicator's initialization.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Correct Symmetrical Application:** The `Calculate` method applies the pre-calculated symmetrical weights directly to the price data. The inherent lag of `(Period-1)/2` bars is a mathematical property of the filter, not an implementation error.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother line. Default is `21`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The Sine WMA should be interpreted as a **smoothing filter and a "mean" or "center of gravity" line**, not as a traditional trend-following moving average.

* **Noise Reduction and Trend Clarity:** The primary use of the Sine WMA is to filter out market noise and provide a clearer picture of the underlying price movement.
* **Mean Reversion Signals:** The line acts as a "magnet" for the price. When the price moves significantly away from the Sine WMA, it can be considered over-extended, increasing the probability of a reversion back towards the line.
* **Heikin Ashi Version:** Using a Heikin Ashi price source provides an additional layer of smoothing. Because both Heikin Ashi and the Sine WMA are strong smoothing techniques, the visual difference between the standard and HA versions may be subtle, especially on longer periods.
* **Caution:** Due to its inherent nature as a centered, smoothing filter, the Sine WMA will always lag the price. It should **not** be used for fast crossover signals. Its strength lies in its smoothness and its ability to define the market's equilibrium point.
