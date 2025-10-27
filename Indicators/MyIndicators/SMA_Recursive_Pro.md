# SMA Recursive Professional

## 1. Summary (Introduction)

The SMA Recursive Pro is an implementation of the classic Simple Moving Average (SMA) that uses a **computationally efficient, recursive calculation method**, as described by John Ehlers in his "Swiss Army Knife" article.

Unlike a traditional SMA, which recalculates the sum of the entire lookback period on every bar, the recursive method simply takes the previous SMA value, adds the newest price, and subtracts the oldest price. This results in significantly faster calculations, especially on very long periods, without sacrificing accuracy.

The final output of this indicator is **mathematically identical** to a standard Simple Moving Average. Its primary purpose is to serve as a robust and efficient building block for more complex strategies and indicators.

## 2. Mathematical Foundations and Calculation Logic

The indicator contrasts two methods of calculating an SMA.

### Standard SMA Calculation (Summation)

The conventional method involves summing the last `N` prices and dividing by `N` on every bar:
$\text{SMA} = \frac{\sum_{i=1}^{N} P_i}{N}$

### Recursive SMA Calculation

The recursive method provides a more efficient way to compute the same value by updating the previous average:
$\text{SMA}_i = \text{SMA}_{i-1} + \frac{P_i - P_{i-N}}{N}$
Where `P_i` is the current price and `P_{i-N}` is the price from `N` bars ago that is "falling off" the lookback window.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`SMA_Recursive_Calculator.mqh`):** The entire calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Robust Initialization:** The `Calculate` method first computes the very first SMA value using a standard summation to provide a stable starting point. All subsequent values are then calculated using the efficient recursive formula.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful calculation is always perfectly synchronized and stable.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the moving average.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The SMA Recursive Pro is used in **exactly the same way as a standard Simple Moving Average**. The "Recursive" in its name refers to the internal calculation method for performance, not a change in its trading characteristics.

* **Trend Identification:** The primary use is to identify the direction of the trend. Price trading above the SMA indicates an uptrend, while price below indicates a downtrend. The slope of the SMA also indicates the trend's strength.
* **Dynamic Support and Resistance:** The SMA line often acts as a dynamic level of support in an uptrend or resistance in a downtrend, providing potential entry zones on pullbacks.
* **Crossover Signals:**
  * **Price Crossover:** A cross of the price over the SMA line can be used as a trade signal.
  * **Two-Line Crossover:** A classic "Golden Cross" or "Death Cross" system can be created by using two instances of the indicator with different periods (e.g., a fast 50-period and a slow 200-period).
