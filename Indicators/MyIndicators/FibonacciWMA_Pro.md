# Fibonacci Weighted Moving Average (Fibonacci WMA) Professional

## 1. Summary (Introduction)

The Fibonacci Weighted Moving Average (Fibonacci WMA) is a specialized type of weighted moving average that uses the Fibonacci number sequence to assign weights to price data. Unlike a Simple Moving Average (SMA) where all prices are weighted equally, the Fibonacci WMA assigns exponentially increasing weights to more recent prices.

The core principle is rooted in the idea that the most recent price action is exponentially more significant than older data. By using the Fibonacci sequence (1, 1, 2, 3, 5, 8, ...), the indicator creates a smooth, responsive moving average that closely follows the trend.

Our `FibonacciWMA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Fibonacci WMA calculates a weighted average where the weights are determined by the numbers in the Fibonacci sequence.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Generate Fibonacci Weights:** First, generate the first `N` numbers of the Fibonacci sequence (e.g., for N=5: 1, 1, 2, 3, 5).

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding Fibonacci numbers. The **most recent price gets the largest Fibonacci number** as its weight.
    * $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Fib_{N-i})$

3. **Calculate the Sum of Weights:** Sum the first `N` Fibonacci numbers used as weights.
    * $\text{Sum of Weights} = \sum_{i=1}^{N} Fib_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    * $\text{Fibonacci WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is built upon a clean, robust, and reusable calculation engine.

* **Modular Calculation Engine (`Fibonacci_WMA_Calculator.mqh`):** The entire calculation logic is encapsulated within a reusable include file.
  * **`CFibonacciWMACalculator`**: The base class that performs the calculation on standard price data.
  * **`CFibonacciWMACalculator_HA`**: A child class that inherits from the base class and overrides the data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Efficient Weight Generation:** The Fibonacci weights are calculated only once during the indicator's initialization in the `Init()` method. The weights are generated and then assigned to an internal array in **reverse order**, ensuring that the largest weight corresponds to the most recent price.

* **Stability via Full Recalculation:** The indicator employs a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Overflow Protection:** The Fibonacci sequence grows exponentially. To prevent potential `long` integer overflow with very large periods, the implementation caps the calculation period at `40`.

* **Correct Heikin Ashi Logic:** The `CFibonacciWMACalculator_HA` class has been corrected to **properly handle all Heikin Ashi price types** (Open, High, Low, Close, Median, etc.) based on the user's selection, ensuring consistent and logical behavior.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother, slower-reacting average. Default is `21`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard price types (e.g., `PRICE_CLOSE_STD`) and all Heikin Ashi price types (e.g., `PRICE_HA_CLOSE`). Default is `PRICE_CLOSE_STD`.

## 5. Usage and Interpretation

The Fibonacci WMA should be interpreted as a responsive, trend-following moving average.

* **Trend Identification:** The primary use is to identify the direction of the trend. When the price is consistently above the Fibonacci WMA and the line is sloping upwards, it indicates a bullish trend.
* **Dynamic Support and Resistance:** In a strong trend, the Fibonacci WMA can act as a dynamic level of support (in an uptrend) or resistance (in a downtrend).
* **Crossover Signals:** The crossover of the price and the Fibonacci WMA can be used as a basic trading signal. A price close above the line can be a buy signal, while a close below can be a sell signal.
* **Caution:** Like all moving averages, the Fibonacci WMA is a lagging indicator and can produce false signals in sideways or choppy markets.
