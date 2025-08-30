# Linear Regression Channel

## 1. Summary (Introduction)

The Linear Regression Channel is a technical analysis tool that consists of three parallel lines plotted on a price chart. It is a statistically-based indicator that uses the **linear regression** (or "least squares fit") method to determine the primary trend direction.

- The **Middle Line** is the actual linear regression trendline.
- The **Upper and Lower Channel Lines** are plotted based on the **maximum price deviation** from the middle line over the calculation period.

The indicator provides an objective, mathematical measure of a trend and its trading channel.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core is the linear regression trendline, which is the straight line that best fits a series of `Close` prices over a specified period.

### Calculation Steps (Algorithm)

For the last `N` bars at any given point in time:

1. **Calculate the Linear Regression Line:** Using the method of least squares, find the straight line that best fits the `N` closing prices.
2. **Calculate Maximum Deviation:** Find the largest vertical distance between any of the `N` closing prices and the calculated regression line.
3. **Calculate the Upper and Lower Channel Lines:** Shift the regression line up and down by the maximum deviation found in the previous step.

**Important Note on "Repainting":** The Linear Regression Channel is a "repainting" indicator by nature. Because the entire line is recalculated for the most recent `N` bars every time a new bar forms, its position in the recent past can change.

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed to be highly efficient and visually clean by leveraging MetaTrader 5's built-in **`OBJ_REGRESSION`** graphical object.

- **Object-Based Plotting:** The indicator uses a single, built-in `OBJ_REGRESSION` object. This object is managed by the MetaTrader terminal, which handles the complex regression and maximum deviation calculations internally using highly optimized code.
- **Clean, Non-Continuous Display:** By default, the indicator only displays the single, most current regression channel calculated on the last `N` bars.
- **Efficient "On New Bar" Updates:** The indicator is extremely light on terminal resources. The channel object is only updated **once per bar** when a new candle forms, preventing unnecessary recalculations on every tick.
- **Automatic Cleanup (RAII):** The graphical object is given a unique name and is always deleted from the chart when the indicator is removed.

## 4. Parameters

- **Regression Period (`InpRegressionPeriod`):** The number of bars to include in the regression calculation. Default is `100`.
- **Channel Color (`InpChannelColor`):** Allows the user to customize the color of the channel lines. Default is `clrRed`.
- **Channel Extensions:**
  - **`InpRayRight`**: If `true`, the channel is extended indefinitely into the future. Default is `false`.
  - **`InpRayLeft`**: If `true`, the channel is extended indefinitely into the past. Default is `false`.

## 5. Usage and Interpretation

- **Trend Identification:** The slope of the middle line indicates the direction of the trend.
- **Dynamic Support and Resistance:** The channel lines act as dynamic support and resistance levels.
- **Caution:** Due to its repainting nature, the indicator is best used for confirming the current market structure rather than for generating precise entry signals from past data.
