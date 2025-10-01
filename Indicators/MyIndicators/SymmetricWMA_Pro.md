# Symmetric Weighted Moving Average (Symmetric WMA) Professional

## 1. Summary (Introduction)

The Symmetric Weighted Moving Average is a type of weighted moving average that uses a simple, triangular weighting scheme. It is a **symmetrical, zero-lag smoothing filter**, designed to reduce market noise and provide a smooth representation of the price's central tendency.

It achieves this by assigning the heaviest weights to the price data in the middle of the lookback period. The result is a smooth line that lags the price but effectively filters out insignificant fluctuations.

Our `SymmetricWMA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Symmetric WMA calculates a weighted average where the weights form a simple triangular pattern.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **Source Price:** The price series used for calculation.

### Calculation Steps (Algorithm)

1. **Generate Symmetric Weights:** For a given period `N`, the weights are generated to form a triangle, increasing linearly from 1 to a peak at the midpoint, and then decreasing linearly back.
    * *Example for N=5:* The weights would be `1, 2, 3, 2, 1`.

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding triangular weights.
    * $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated triangular weights.
    * $\text{Sum of Weights} = \sum_{i=0}^{N-1} Weight_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    * $\text{Symmetric WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`SymmetricWMA_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CSymmetricWMACalculator`**: The base class that performs the full calculation on a given source price.
  * **`CSymmetricWMACalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Efficient Weight Generation:** The triangular weights are calculated only once during the indicator's initialization.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Correct Symmetrical Application:** The `Calculate` method applies the pre-calculated symmetrical weights directly. The inherent lag of `(Period-1)/2` bars is a mathematical property of the filter.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother line. Default is `21`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The Symmetric WMA should be interpreted as a **smoothing filter and a "mean" or "center of gravity" line**.

* **Noise Reduction and Trend Clarity:** The primary use is to filter out market noise and provide a clearer picture of the underlying price movement.
* **Mean Reversion Signals:** The line acts as a "magnet" for the price. When the price moves significantly away from the Symmetric WMA, it can be considered over-extended, increasing the probability of a reversion back towards the line.
* **Heikin Ashi Version:** Using a Heikin Ashi price source provides an additional layer of smoothing. Because both Heikin Ashi and the Symmetric WMA are strong smoothing techniques, the visual difference between the standard and HA versions may be subtle, especially on longer periods.
* **Caution:** Due to its inherent nature as a centered, smoothing filter, the Symmetric WMA will always lag the price. It should **not** be used for fast crossover signals.
