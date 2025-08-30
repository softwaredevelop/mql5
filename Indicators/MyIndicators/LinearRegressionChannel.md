# Linear Regression Channel

## 1. Summary (Introduction)

The Linear Regression Channel is a technical analysis tool that consists of three parallel lines plotted on a price chart. It is a statistically-based indicator that uses the **linear regression** (or "least squares fit") method to determine the primary trend direction.

- The **Middle Line** is the actual linear regression trendline.
- The **Upper and Lower Channel Lines** are plotted one standard deviation above and below the middle line.

The indicator provides an objective, mathematical measure of a trend and its trading channel, helping traders to identify trend direction and dynamic support and resistance levels.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core is the linear regression trendline, which is the straight line that best fits a series of data points (in this case, `Close` prices) over a specified period.

### Required Components

- **Period (N):** The lookback period for the regression calculation (e.g., 100).
- **Price Data (P):** The `Close` price series.

### Calculation Steps (Algorithm)

For the last `N` bars at any given point in time:

1. **Calculate the Linear Regression Line:** Using the method of least squares, find the straight line that best fits the `N` closing prices.
   $\text{Regression Line}_t = a + b \times t$

2. **Calculate the Standard Deviation:** Compute the standard deviation of the `N` closing prices from the calculated regression line.
   $\sigma = \sqrt{\frac{\sum_{k=1}^{N} (P_k - \text{Regression Line}_k)^2}{N}}$

3. **Calculate the Upper and Lower Channel Lines:** Add and subtract **one** standard deviation from the regression line.
   $\text{Upper Channel}_t = \text{Regression Line}_t + \sigma$
   $\text{Lower Channel}_t = \text{Regression Line}_t - \sigma$

**Important Note on "Repainting":** The Linear Regression Channel is a "repainting" indicator by nature. Because the entire line is recalculated for the most recent `N` bars every time a new bar forms, its position in the recent past can change. This is not a bug but a fundamental characteristic of the statistical method.

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed to be highly efficient and visually clean by leveraging MetaTrader 5's built-in graphical objects.

- **Object-Based Plotting:** Instead of using indicator buffers, our indicator uses a single, built-in `OBJ_REGRESSION` graphical object. This object is managed by the MetaTrader terminal, which handles the complex regression and standard deviation calculations internally using highly optimized code.

- **Clean, Non-Continuous Display:** By default, the indicator only displays the **single, most current** regression channel calculated on the last `N` bars. This provides a clean, uncluttered view of the present market structure.

- **Efficient "On New Bar" Updates:** The indicator is designed to be extremely light on terminal resources. It uses a simple time-check within `OnCalculate`. The channel object is only updated **once per bar**, when a new candle forms, preventing unnecessary recalculations on every tick.

- **Automatic Cleanup (RAII):** The graphical object is given a unique name upon creation. The `OnDeinit` function ensures that this object is always deleted from the chart when the indicator is removed, leaving no visual artifacts behind.

- **Fixed Parameters:** To accurately reflect the behavior of the underlying `OBJ_REGRESSION` object, our implementation has the following fixed characteristics:
  - **Applied Price:** The calculation always uses `PRICE_CLOSE`.
  - **Deviations:** The channel width is always fixed at **one** standard deviation from the center line. These properties cannot be changed.

## 4. Parameters

- **Regression Period (`InpRegressionPeriod`):** The number of bars to include in the regression calculation. A longer period creates a more stable, long-term trendline, while a shorter period is more responsive to recent price action. Default is `100`.
- **Channel Extensions:**
  - **`InpRayRight`**: If `true`, the calculated channel will be extended indefinitely into the future. Default is `false`.
  - **`InpRayLeft`**: If `true`, the channel will be extended indefinitely into the past. Default is `false`.

## 5. Usage and Interpretation

- **Trend Identification:** The slope of the middle line indicates the direction of the trend.
- **Dynamic Support and Resistance:** The channel lines act as dynamic support and resistance levels.
- **Overbought/Oversold:** A move to the upper channel line can be considered overbought relative to the current trend, while a move to the lower line can be considered oversold.
- **Breakouts:** A strong close outside the channel can signal that the current trend is accelerating or that a reversal is imminent.
- **Caution:** Due to its repainting nature, signals should be interpreted with care. The indicator is best used for confirming the current market structure rather than for generating precise entry signals from past data.
