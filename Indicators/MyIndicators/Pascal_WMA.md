# Pascal Weighted Moving Average (Pascal WMA)

## 1. Summary (Introduction)

The Pascal Weighted Moving Average (Pascal WMA) is a unique type of weighted moving average that derives its weights from the coefficients of Pascal's triangle. This mathematical structure, known from combinatorics, produces a set of weights that are perfectly symmetrical and follow a smooth, bell-shaped (Gaussian-like) curve.

Similar to the Sine WMA, the Pascal WMA is a **symmetrical, zero-lag smoothing filter**. Its primary purpose is not to follow trends with minimal lag, but to provide an exceptionally smooth and stable representation of the market's central tendency or "fair value". By assigning the heaviest weights to the price data in the middle of the lookback period, it effectively filters out market noise and reduces the impact of short-term, insignificant price spikes.

The result is a clean, aesthetically pleasing line that glides through the price action, making it a powerful tool for identifying the underlying smoothed trend and for mean-reversion analysis.

## 2. Mathematical Foundations and Calculation Logic

The Pascal WMA calculates a weighted average where the weights are the binomial coefficients found in a row of Pascal's triangle.

### Required Components

- **Period (N):** The lookback period for the moving average. This determines which row of Pascal's triangle is used.
- **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Generate Pascal Weights:** For a given period `N`, the weights are the coefficients of the binomial expansion of $(x+y)^{N-1}$. These coefficients correspond to the `N`-th row of Pascal's triangle (starting the count from row 0). The `k`-th weight in the sequence (where `k` is from 0 to N-1) is calculated using the combination formula:
    - $Weight_k = C(N-1, k) = \frac{(N-1)!}{k! \cdot (N-1-k)!}$

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding Pascal coefficients.
    - $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated Pascal weights. A known property of Pascal's triangle is that the sum of the `n`-th row is $2^n$. Therefore, the sum of weights is $2^{N-1}$.
    - $\text{Sum of Weights} = \sum_{i=0}^{N-1} Weight_i = 2^{N-1}$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    - $\text{Pascal WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

This process results in a symmetrically weighted average that is centered on the data, providing a very smooth output with a Gaussian-like response.

## 3. MQL5 Implementation Details

Our MQL5 implementation is a clean and robust indicator that accurately calculates the Pascal WMA using an efficient algorithm.

- **Self-Contained, Object-Oriented Design:** The entire logic is encapsulated within a single `.mq5` file but is internally structured into a dedicated `CPascalWMACalculator` class. This separates the calculation logic from the indicator's buffer management, ensuring the code is clean and maintainable.

- **Efficient Weight Generation:** The Pascal's triangle coefficients are calculated only once during the indicator's initialization in the `Init()` method of the calculator class. The algorithm for calculating combinations (`n C k`) is optimized to handle large numbers by using the multiplicative formula and symmetry (`C(n, k) = C(n, n-k)`), preventing unnecessary computations and potential overflows. The weights and their sum are stored in internal class members for efficient reuse.

- **Stability via Full Recalculation:** In line with our core principles, the indicator employs a "brute-force" full recalculation within the `OnCalculate` function. This is the most reliable method to ensure stability and prevent any potential glitches, while keeping the code simple and robust.

- **Correct Symmetrical Application:** The `Calculate` method applies the pre-calculated symmetrical weights directly to the price data. The weights are **not reversed**. The most recent price is multiplied by the first (and smallest) coefficient, and the price in the middle of the period is multiplied by the largest coefficient. This correctly implements the smoothing, centered nature of the filter. The inherent lag of `(Period-1)/2` bars is a mathematical property of the filter.

## 4. Parameters

- **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother, more heavily filtered line that is less sensitive to short-term price fluctuations. Default is `21`.
- **Source Price (`InpSourcePrice`):** The price data used for the calculation (Close, Open, High, Low, Median, etc.). Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

The Pascal WMA should be interpreted as a **high-quality smoothing filter and a "mean" or "center of gravity" line**, not as a traditional trend-following moving average.

- **Noise Reduction and Trend Clarity:** The primary use of the Pascal WMA is to filter out market noise and provide a much clearer picture of the underlying price movement. Its extremely smooth, bell-shaped response makes it highly effective at ignoring insignificant price spikes.
- **Mean Reversion Signals:** The line acts as a "magnet" for the price.
  - When the price moves significantly **above** the Pascal WMA, it can be considered over-extended, increasing the probability of a reversion (downward correction) back towards the line.
  - When the price moves significantly **below** the Pascal WMA, it can be considered oversold, increasing the probability of a reversion back up towards the line.
- **Confirmation of Trend Direction:** The slope of the Pascal WMA provides a very stable, albeit lagging, confirmation of the main trend direction. Because it is very slow to turn, a change in the slope's direction is a significant event, suggesting a potential major shift in the market.
- **Caution:** Due to its inherent nature as a centered, smoothing filter, the Pascal WMA will always lag the price. It should **not** be used for fast crossover signals in the same way as an EMA. Its strength lies in its exceptional smoothness and its ability to define the market's equilibrium point, making it an excellent tool for mean-reversion strategies or as a baseline in more complex systems.
