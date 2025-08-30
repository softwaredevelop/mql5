# Standard Deviation Channel

## 1. Summary (Introduction)

The Standard Deviation Channel is a technical analysis tool very similar to the Linear Regression Channel. It consists of three parallel lines plotted on a price chart, with a linear regression trendline at its center.

The key difference is how the channel width is determined. Instead of using the maximum price deviation, this indicator uses the **standard deviation** of the price from the trendline. This provides a more statistically robust measure of the channel's boundaries.

- The **Middle Line** is a linear regression trendline.
- The **Upper and Lower Channel Lines** are plotted a user-defined number of standard deviations above and below the middle line.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core is the linear regression trendline, with the channel width determined by the standard deviation.

### Calculation Steps (Algorithm)

For the last `N` bars at any given point in time:

1. **Calculate the Linear Regression Line:** Using the method of least squares, find the straight line that best fits the `N` closing prices.
2. **Calculate the Standard Deviation (σ):** Compute the standard deviation of the `N` closing prices from the calculated regression line.
3. **Calculate the Upper and Lower Channel Lines:** Add and subtract a user-defined multiple of the standard deviation from the regression line.
   $\text{Upper Channel}_t = \text{Regression Line}_t + (\text{Multiplier} \times \sigma)$
   $\text{Lower Channel}_t = \text{Regression Line}_t - (\text{Multiplier} \times \sigma)$

**Important Note on "Repainting":** This indicator is also "repainting" by nature, for the same reasons as the Linear Regression Channel.

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed to be highly efficient and visually clean by leveraging MetaTrader 5's built-in **`OBJ_STDDEVCHANNEL`** graphical object.

- **Object-Based Plotting:** The indicator uses a single, built-in `OBJ_STDDEVCHANNEL` object. This object is managed by the MetaTrader terminal, which handles the complex regression and standard deviation calculations internally.
- **Clean, Non-Continuous Display:** By default, the indicator only displays the single, most current channel calculated on the last `N` bars.
- **Efficient "On New Bar" Updates:** The indicator is extremely light on terminal resources. The channel object is only updated **once per bar** when a new candle forms.
- **Automatic Cleanup (RAII):** The graphical object is given a unique name and is always deleted from the chart when the indicator is removed.
- **Fixed Price Source:** The underlying `OBJ_STDDEVCHANNEL` object always performs its calculation on `PRICE_CLOSE`. This cannot be changed.

## 4. Parameters

- **Regression Period (`InpRegressionPeriod`):** The number of bars to include in the regression calculation. Default is `100`.
- **Deviations (`InpDeviations`):** The multiplier for the standard deviation, which determines the width of the channel. Default is `2.0`.
- **Channel Color (`InpChannelColor`):** Allows the user to customize the color of the channel lines. Default is `clrRed`.
- **Channel Extensions:**
  - **`InpRayRight`**: If `true`, the channel is extended indefinitely into the future. Default is `false`.
  - **`InpRayLeft`**: If `true`, the channel is extended indefinitely into the past. Default is `false`.

## 5. Usage and Interpretation

The usage is identical to the Linear Regression Channel, but the channel width is generally considered more statistically significant.

- **Trend Identification:** The slope of the middle line indicates the direction of the trend.
- **Dynamic Support and Resistance:** The channel lines act as dynamic support and resistance levels.
- **Overbought/Oversold:** A move to the upper channel line can be considered overbought relative to the current trend, while a move to the lower line can be considered oversold.
- **Caution:** Due to its repainting nature, the indicator is best used for confirming the current market structure.
