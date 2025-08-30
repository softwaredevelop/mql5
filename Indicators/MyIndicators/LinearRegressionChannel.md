# Linear Regression Channel

## 1. Summary (Introduction)

The Linear Regression Channel is a technical analysis tool that consists of three parallel lines plotted on a price chart. It is a statistically-based indicator that uses the **linear regression** (or "least squares fit") method to determine the primary trend direction.

- The **Middle Line** is the actual linear regression trendline.
- The **Upper and Lower Channel Lines** are plotted a specified number of standard deviations above and below the middle line.

The indicator provides an objective, mathematical measure of a trend and its trading channel, helping traders to identify trend direction, dynamic support and resistance levels, and potential overbought/oversold conditions relative to the trend.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core is the linear regression trendline, which is the straight line that best fits a series of data points (in this case, prices) over a specified period.

### Required Components

- **Period (N):** The lookback period for the regression calculation (e.g., 100).
- **Price Data (P):** The price series used for the calculation. The standard implementation uses the **Close** price.
- **Deviations (M):** The number of standard deviations to shift the channel lines away from the middle line.

### Calculation Steps (Algorithm)

For the last `N` bars at any given point in time:

1. **Calculate the Linear Regression Line:** Using the method of least squares, find the straight line that minimizes the distance to each of the `N` price points. This line is defined by its slope (`b`) and y-intercept (`a`).
   $\text{Regression Line}_t = a + b \times t$
   _(where `t` is the time index from 0 to N-1)_

2. **Calculate the Standard Deviation:** Compute the standard deviation of the `N` price points from the calculated regression line. This measures the average dispersion or volatility around the trendline.
   $\sigma = \sqrt{\frac{\sum_{k=1}^{N} (P_k - \text{Regression Line}_k)^2}{N}}$

3. **Calculate the Upper and Lower Channel Lines:** Add and subtract a multiple of the standard deviation from the regression line.
   $\text{Upper Channel}_t = \text{Regression Line}_t + (M \times \sigma)$
   $\text{Lower Channel}_t = \text{Regression Line}_t - (M \times \sigma)$

**Important Note on "Repainting":** The Linear Regression Channel is a "repainting" indicator by nature. Because the entire line is recalculated for the most recent `N` bars every time a new bar forms, its position in the recent past can change. This is not a bug but a fundamental characteristic of the statistical method.

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed to be highly efficient and visually clean by leveraging MetaTrader 5's built-in graphical objects.

- **Object-Based Plotting:** Instead of using indicator buffers, our indicator uses a single, built-in `OBJ_REGRESSION` graphical object. This object is managed by the MetaTrader terminal, which handles the complex regression and standard deviation calculations internally using highly optimized code.

- **Clean, Non-Continuous Display:** By default, the indicator only displays the **single, most current** regression channel calculated on the last `N` bars. This provides a clean, uncluttered view of the present market structure.

- **Efficient "On New Bar" Updates:** The indicator is designed to be extremely light on terminal resources. It uses a simple time-check within `OnCalculate`. The channel object is only updated **once per bar**, when a new candle forms, preventing unnecessary recalculations on every tick.

- **Automatic Cleanup (RAII):** The graphical object is given a unique name upon creation. The `OnDeinit` function ensures that this object is always deleted from the chart when the indicator is removed, leaving no visual artifacts behind.

- **Heikin Ashi Variant:** A "pure" Heikin Ashi version can be created by calculating the Heikin Ashi prices into an array and then manually performing the regression calculation on that array (as the built-in `OBJ_REGRESSION` object cannot be pointed to a custom data source).

## 4. Parameters

- **Regression Period (`InpRegressionPeriod`):** The number of bars to include in the regression calculation. A longer period creates a more stable, long-term trendline, while a shorter period is more responsive to recent price action. Default is `100`.
- **Deviations (`InpDeviations`):** The multiplier for the standard deviation, which determines the width of the channel. Default is `2.0`.
- **Channel Extensions:**
  - **`InpRayRight`**: If `true`, the calculated channel will be extended indefinitely into the future, which can be used to project potential future support and resistance levels. Default is `false`.
  - **`InpRayLeft`**: If `true`, the channel will be extended indefinitely into the past. Default is `false`.

## 5. Usage and Interpretation

- **Trend Identification:** The slope of the middle line indicates the direction of the trend. An upward slope is bullish; a downward slope is bearish.
- **Dynamic Support and Resistance:** The channel lines act as dynamic support and resistance levels. In an uptrend, the lower line can be seen as a buy zone. In a downtrend, the upper line can be seen as a sell zone.
- **Overbought/Oversold:** A move to the upper channel line can be considered overbought relative to the current trend, while a move to the lower line can be considered oversold.
- **Breakouts:** A strong close outside the channel can signal that the current trend is accelerating or that a reversal is imminent.
- **Caution:** Due to its repainting nature, signals should be interpreted with care. A historical price touch of a channel line may not have appeared the same way in real-time. The indicator is best used for confirming the current market structure rather than for generating precise entry signals from past data.
