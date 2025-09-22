# Symmetric Weighted Moving Average (Symmetric WMA)

## 1. Summary (Introduction)

The Symmetric Weighted Moving Average is a type of weighted moving average that uses a simple, triangular (or tent-shaped) weighting scheme. It is the most straightforward implementation of a symmetrical, centered smoothing filter.

Like other symmetrical filters such as the Sine or Pascal WMA, its primary purpose is to **reduce market noise and provide a smooth representation of the price's central tendency**. It achieves this by assigning the heaviest weights to the price data in the middle of the lookback period and linearly decreasing the weights towards the ends of the period.

The result is a smooth line that lags the price but effectively filters out insignificant fluctuations. It serves as an excellent tool for identifying the underlying smoothed trend and for mean-reversion analysis, offering a simpler alternative to more complex mathematical filters.

## 2. Mathematical Foundations and Calculation Logic

The Symmetric WMA calculates a weighted average where the weights form a simple triangular pattern.

### Required Components

- **Period (N):** The lookback period for the moving average.
- **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Generate Symmetric Weights:** For a given period `N`, the weights are generated to form a triangle. They increase linearly from 1 to a peak at the midpoint of the period, and then decrease linearly back to 1.
    - Let `midpoint = (N + 1) / 2`
    - For `i` from 1 to `N`:
        - If `i <= midpoint`, $Weight_i = i$
        - If `i > midpoint`, $Weight_i = N - i + 1$
    - *Example for N=5:* The weights would be `1, 2, 3, 2, 1`.

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding triangular weights.
    - $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated triangular weights.
    - $\text{Sum of Weights} = \sum_{i=0}^{N-1} Weight_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    - $\text{Symmetric WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

This process results in a symmetrically weighted average that is centered on the data, providing a simple yet effective smoothing filter.

## 3. MQL5 Implementation Details

Our MQL5 implementation is a clean and robust indicator that accurately calculates the Symmetric WMA.

- **Self-Contained, Object-Oriented Design:** The entire logic is encapsulated within a single `.mq5` file but is internally structured into a dedicated `CSymmetricWMACalculator` class. This separates the calculation logic from the indicator's buffer management, ensuring the code is clean and maintainable.

- **Efficient Weight Generation:** The triangular weights are calculated only once during the indicator's initialization in the `Init()` method of the calculator class. The weights and their sum are stored in internal class members for efficient reuse in the main calculation loop.

- **Stability via Full Recalculation:** In line with our core principles, the indicator employs a "brute-force" full recalculation within the `OnCalculate` function. This is the most reliable method to ensure stability and prevent any potential glitches, while keeping the code simple and robust.

- **Correct Symmetrical Application:** The `Calculate` method applies the pre-calculated symmetrical weights directly to the price data. The weights are **not reversed**. The most recent price is multiplied by the first, smallest weight (1), and the price in the middle of the period is multiplied by the largest weight. This correctly implements the smoothing, centered nature of the filter. The inherent lag of `(Period-1)/2` bars is a mathematical property of the filter.

## 4. Parameters

- **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother line that is less sensitive to short-term price fluctuations. Default is `21`.
- **Source Price (`InpSourcePrice`):** The price data used for the calculation (Close, Open, High, Low, Median, etc.). Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

The Symmetric WMA should be interpreted as a **smoothing filter and a "mean" or "center of gravity" line**, similar to the Sine and Pascal WMAs.

- **Noise Reduction and Trend Clarity:** The primary use of the Symmetric WMA is to filter out market noise and provide a clearer picture of the underlying price movement. Its smooth nature helps to visualize the true, smoothed path of the market.
- **Mean Reversion Signals:** The line acts as a "magnet" for the price.
  - When the price moves significantly **above** the Symmetric WMA, it can be considered over-extended, increasing the probability of a reversion (downward correction) back towards the line.
  - When the price moves significantly **below** the Symmetric WMA, it can be considered oversold, increasing the probability of a reversion back up towards the line.
- **Confirmation of Trend Direction:** The slope of the Symmetric WMA provides a very stable, albeit lagging, confirmation of the main trend direction. Because it is slow to turn, a change in the slope's direction is a significant event, suggesting a potential major shift in the market.
- **Caution:** Due to its inherent nature as a centered, smoothing filter, the Symmetric WMA will always lag the price. It should **not** be used for fast crossover signals in the same way as an EMA. Its strength lies in its simplicity and smoothness, making it a reliable tool for mean-reversion strategies or as a baseline in more complex systems.
