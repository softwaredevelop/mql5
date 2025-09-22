# Fibonacci Weighted Moving Average (Fibonacci WMA)

## 1. Summary (Introduction)

The Fibonacci Weighted Moving Average (Fibonacci WMA) is a specialized type of weighted moving average that uses the Fibonacci number sequence to assign weights to price data. Unlike a Simple Moving Average (SMA) where all prices are weighted equally, the Fibonacci WMA assigns exponentially increasing weights to more recent prices.

The core principle is rooted in the idea that the most recent price action is exponentially more significant than older data. By using the Fibonacci sequence (1, 1, 2, 3, 5, 8, ...), the indicator creates a smooth, responsive moving average that closely follows the trend while effectively filtering out minor market noise. It is a pure **trend-following tool** designed to identify and track the direction of the market.

## 2. Mathematical Foundations and Calculation Logic

The Fibonacci WMA calculates a weighted average where the weights are determined by the numbers in the Fibonacci sequence.

### Required Components

- **Period (N):** The lookback period for the moving average.
- **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Generate Fibonacci Weights:** First, generate the first `N` numbers of the Fibonacci sequence (e.g., for N=5: 1, 1, 2, 3, 5).

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding Fibonacci numbers. The **most recent price gets the largest Fibonacci number** as its weight, and the oldest price in the period gets the smallest weight.
    - $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Fib_{N-i})$

3. **Calculate the Sum of Weights:** Sum the first `N` Fibonacci numbers used as weights.
    - $\text{Sum of Weights} = \sum_{i=1}^{N} Fib_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    - $\text{Fibonacci WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

This process results in an asymmetrically weighted average that is highly sensitive to recent price changes.

## 3. MQL5 Implementation Details

Our MQL5 implementation is a clean, robust, and self-contained indicator that accurately reflects the mathematical definition of the Fibonacci WMA.

- **Modular, Reusable Calculation Engine (`Fibonacci_WMA_Calculator.mqh`):** The entire calculation logic for both standard and Heikin Ashi versions is encapsulated within a single, powerful include file.
  - **`CFibonacciWMACalculator`**: The base class that performs the calculation on standard price data.
  - **`CFibonacciWMACalculator_HA`**: A child class that inherits from the base class and overrides the data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

- **Efficient Weight Generation:** The Fibonacci weights are calculated only once during the indicator's initialization in the `Init()` method. The weights are generated and then assigned to the internal weights array in **reverse order**, ensuring that the largest weight is at index `0`. This simplifies the main calculation loop and improves performance.

- **Stability via Full Recalculation:** In line with our core principles, the indicator employs a "brute-force" full recalculation within the `OnCalculate` function. This ensures maximum stability and prevents any potential glitches, while keeping the code simple and robust.

- **Correct Weight Application:** The `Calculate` method applies the pre-calculated weights directly. The most recent price (`m_price[i - j]` where `j=0`) is correctly multiplied by the largest weight (`m_weights[j]` where `j=0`), ensuring the proper trend-following behavior of the indicator.

- **Overflow Protection:** The Fibonacci sequence grows exponentially. To prevent potential `long` integer overflow with very large periods, the implementation caps the calculation period at `40`.

- **Heikin Ashi Variant (`Fibonacci_WMA_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version. It uses the same robust calculation engine, but the engine is configured to first transform the standard OHLC prices into Heikin Ashi prices and then perform the WMA calculation on the **Heikin Ashi Close** values.
  - This results in an even smoother, more trend-stable moving average, ideal for strategies that aim to filter out market noise as much as possible.

## 4. Parameters

- **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother, slower-reacting average, while a shorter period makes it more sensitive to price changes. Default is `21`.
- **Source Price (`InpSourcePrice`):** The price data used for the calculation (Close, Open, High, Low, etc.). **Note: This parameter is ignored by the Heikin Ashi version**, which always uses the HA Close price. Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

The Fibonacci WMA should be interpreted as a responsive, trend-following moving average.

- **Trend Identification:** The primary use is to identify the direction of the trend. When the price is consistently above the Fibonacci WMA and the line is sloping upwards, it indicates a bullish trend. When the price is below the line and the line is sloping downwards, it indicates a bearish trend.
- **Dynamic Support and Resistance:** In a strong trend, the Fibonacci WMA can act as a dynamic level of support (in an uptrend) or resistance (in a downtrend). Pullbacks to the line can offer potential entry opportunities in the direction of the trend.
- **Crossover Signals:** The crossover of the price and the Fibonacci WMA can be used as a basic trading signal. A price close above the line can be a buy signal, while a close below can be a sell signal.
- **Caution:** Like all moving averages, the Fibonacci WMA is a lagging indicator and can produce false signals in sideways or choppy markets. It is most effective when used in clearly trending markets and in conjunction with other forms of analysis to confirm signals.
