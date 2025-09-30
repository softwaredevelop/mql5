# Pascal Weighted Moving Average (Pascal WMA) Professional

## 1. Summary (Introduction)

The Pascal Weighted Moving Average (Pascal WMA) is a unique type of weighted moving average that derives its weights from the coefficients of Pascal's triangle. This produces a set of weights that are perfectly symmetrical and follow a smooth, bell-shaped (Gaussian-like) curve.

The Pascal WMA is a **symmetrical, zero-lag smoothing filter**. Its primary purpose is not to follow trends with minimal lag, but to provide an exceptionally smooth and stable representation of the market's central tendency.

Our `PascalWMA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Pascal WMA calculates a weighted average where the weights are the binomial coefficients found in a row of Pascal's triangle.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **Source Price:** The price series used for calculation.

### Calculation Steps (Algorithm)

1. **Generate Pascal Weights:** For a given period `N`, the weights are the coefficients of the binomial expansion of $(x+y)^{N-1}$. The `k`-th weight is calculated using the combination formula:
    * $Weight_k = C(N-1, k) = \frac{(N-1)!}{k! \cdot (N-1-k)!}$

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding Pascal coefficients.
    * $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated Pascal weights. The sum of the `n`-th row is $2^n$.
    * $\text{Sum of Weights} = 2^{N-1}$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    * $\text{Pascal WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`PascalWMA_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CPascalWMACalculator`**: The base class that performs the full calculation on a given source price.
  * **`CPascalWMACalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Efficient Weight Generation:** The Pascal's triangle coefficients are calculated only once during the indicator's initialization. The algorithm is optimized to handle large numbers by using the multiplicative formula and symmetry (`C(n, k) = C(n, n-k)`).

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother line. Default is `21`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The Pascal WMA should be interpreted as a **high-quality smoothing filter and a "mean" or "center of gravity" line**, not as a traditional trend-following moving average.

* **Noise Reduction and Trend Clarity:** The primary use is to filter out market noise and provide a clearer picture of the underlying price movement.
* **Mean Reversion Signals:** The line acts as a "magnet" for the price. When the price moves significantly away from the Pascal WMA, it can be considered over-extended, increasing the probability of a reversion back towards the line.
* **Heikin Ashi Version:** Using a Heikin Ashi price source provides an additional layer of smoothing. Because both Heikin Ashi and the Pascal WMA are strong smoothing techniques, the visual difference between the standard and HA versions may be subtle, especially on longer periods.
* **Caution:** Due to its inherent nature as a centered, smoothing filter, the Pascal WMA will always lag the price. It should **not** be used for fast crossover signals. Its strength lies in its exceptional smoothness and its ability to define the market's equilibrium point.
