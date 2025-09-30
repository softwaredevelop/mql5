# Linear Regression Pro

## 1. Summary (Introduction)

The Linear Regression Pro is a highly flexible, manually calculated version of the classic Linear Regression Channel. It is a statistically-based indicator that uses the **linear regression** (or "least squares fit") method to determine the primary trend direction over a specified period.

Unlike the built-in MetaTrader 5 graphical objects, this "Pro" version offers full customization over its calculation, including the **source price** (standard or Heikin Ashi) and the **channel width calculation method**. It is designed to be a robust, efficient, and precise tool for advanced technical analysis.

* The **Middle Line** is the linear regression trendline.
* The **Upper and Lower Channel Lines** are plotted based on a selected deviation method.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core is the linear regression trendline, which is the straight line that best fits a series of data points over a specified period.

### Required Components

* **Period (N):** The lookback period for the regression calculation.
* **Source Price (P):** The price series used for the calculation.
* **Channel Mode:** The method for calculating the channel width.
* **Deviations (M):** The multiplier for the standard deviation.

### Calculation Steps (Algorithm)

For the last `N` bars at any given point in time:

1. **Calculate the Linear Regression Line:** Using the method of least squares, find the straight line that best fits the `N` source price points.
    $\text{Regression Line}_t = a + b \times t$

2. **Calculate the Channel Width (Deviation Offset):** Based on the selected `Channel Mode`:
    * **Standard Deviation Mode:** Compute the standard deviation of the `N` price points from the calculated regression line.
        $\sigma = \sqrt{\frac{\sum_{k=1}^{N} (P_k - \text{Regression Line}_k)^2}{N}}$
        $\text{Offset} = M \times \sigma$
    * **Maximum Deviation Mode:** Find the largest absolute distance between any of the `N` price points and the regression line.
        $\text{Offset} = \text{Max}(\text{Abs}(P_k - \text{Regression Line}_k))$

3. **Calculate the Upper and Lower Channel Lines:** Add and subtract the calculated `Offset` from the regression line.
    $\text{Upper Channel}_t = \text{Regression Line}_t + \text{Offset}$
    $\text{Lower Channel}_t = \text{Regression Line}_t - \text{Offset}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`LinearRegression_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CLinearRegressionCalculator`**: The base class that performs the full statistical calculation on a given source price.
  * **`CLinearRegressionCalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Efficient "On New Bar" Updates:** The indicator is designed to be extremely light on terminal resources. The entire complex calculation is only performed **once per bar** when a new candle forms, preventing unnecessary CPU load on every tick.

* **Clean, Non-Continuous Display:** The indicator only displays the **single, most current** regression channel calculated on the last `N` bars. This is achieved by dynamically setting the `PLOT_DRAW_BEGIN` property on each update.

## 4. Parameters

* **Regression Period (`InpRegressionPeriod`):** The number of bars to include in the calculation.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Channel Mode (`InpChannelMode`):** Allows the user to select the method for calculating the channel width:
  * `DEVIATION_STANDARD`: Based on the standard deviation (most common).
  * `DEVIATION_MAXIMUM`: Based on the maximum price deviation.
* **Deviations (`InpDeviations`):** The multiplier for the standard deviation, used only when `DEVIATION_STANDARD` mode is selected.

## 5. Usage and Interpretation

* **Trend Identification:** The slope of the middle line indicates the direction of the trend.
* **Dynamic Support and Resistance:** The channel lines act as dynamic support and resistance levels.
* **Overbought/Oversold:** A move to the upper channel line can be considered overbought relative to the current trend, while a move to the lower line can be considered oversold.
* **Caution:** The indicator is "repainting" by nature, as the entire channel is recalculated for the lookback period on each new bar. It is best used for confirming the current market structure rather than for generating precise entry signals from past data.
