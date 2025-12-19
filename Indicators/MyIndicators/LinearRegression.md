# Linear Regression Pro Suite

## 1. Summary (Introduction)

The **Linear Regression Pro Suite** provides a comprehensive set of tools for analyzing price trends using statistical linear regression. Unlike standard tools, this suite offers two distinct indicators derived from the same robust calculation engine, giving traders complete flexibility.

### The Two Variants

1. **Linear Regression Channel Pro (Straight):**
    * This is the classic "Channel" tool. It calculates the best-fit straight line for the **most recent N bars** and projects it as a static channel.
    * *Best for:* Visualizing the current trend structure, identifying breakouts, and setting targets based on the current market geometry.

2. **Linear Regression Moving Pro (Curve):**
    * This is a dynamic "Moving Average" style indicator. It calculates the end-point of the regression line for **every single bar** in history.
    * *Best for:* Backtesting, identifying trend reversals historically, and using as a non-repainting signal line (similar to a Moving Average but statistically optimized).

Both versions support **Standard** and **Heikin Ashi** price sources and offer multiple channel calculation modes.

## 2. Comparison: Which one to use?

| Feature | Channel Pro (Straight) | Moving Pro (Curve) |
| :--- | :--- | :--- |
| **Visual Appearance** | Straight lines extending back N bars | A continuous, wavy curve |
| **Calculation Logic** | Fits one line to the *current* window | Fits a new line for *every* past window |
| **Repainting** | **Yes** (The whole line updates with every tick) | **No** (Past values are fixed history) |
| **Primary Use** | Current Market Structure Analysis | Trend Following & Signal Generation |

## 3. Mathematical Foundations

Both indicators use the **Least Squares Method** to minimize the distance between the price points and the trendline.

### Linear Regression Formula

For a window of $N$ bars, the line is defined as $y = a + bx$.

* **Slope ($b$):** Determines the trend direction.
* **Intercept ($a$):** Determines the starting level.

### Channel Width (Deviation)

The width of the channel is calculated based on the selected mode:

* **Standard Deviation:** Measures volatility around the regression line. The channel expands/contracts with market noise.
* **Maximum Deviation:** Finds the furthest price point to create an envelope that contains all price action within the window.

## 4. MQL5 Implementation Details

The suite is built on a shared, high-performance architecture.

* **Unified Engine (`LinearRegression_Calculator.mqh`):**
    A single calculation class handles the complex math for both indicators. This ensures that the "Straight" channel and the "Moving" curve are mathematically consistent (the end of the Straight channel always touches the Moving curve).

* **Optimized Performance:**
  * **Moving Pro:** Uses an O(1) incremental algorithm (`prev_calculated`) to calculate the rolling regression efficiently without re-processing the entire history.
  * **Channel Pro:** Only recalculates the active window on each tick, keeping the chart responsive.

* **Heikin Ashi Integration:** Both indicators can seamlessly switch to using Heikin Ashi smoothed prices via the `CLinearRegressionCalculator_HA` class.

## 5. Parameters

Both indicators share the same core parameters:

* **Regression Period (`InpRegressionPeriod`):** The lookback window size (N). (Default: `100`).
* **Applied Price (`InpSourcePrice`):** The source price (Standard or Heikin Ashi).
* **Channel Mode (`InpChannelMode`):**
  * `DEVIATION_STANDARD`: Volatility-based width.
  * `DEVIATION_MAXIMUM`: Envelope-based width.
* **Deviations (`InpDeviations`):** The multiplier for the Standard Deviation mode. (Default: `2.0`).

## 6. Usage and Interpretation

### Using the Channel Pro (Straight)

* **Mean Reversion:** Price tends to revert to the middle regression line. Extremes at the upper/lower bands are potential reversal zones.
* **Breakouts:** A strong close outside the channel (especially in Maximum Deviation mode) can signal a trend acceleration or a breakout.

### Using the Moving Pro (Curve)

* **Trend Filter:** Use it like a superior Moving Average.
  * **Rising:** Uptrend.
  * **Falling:** Downtrend.
* **Crossovers:** Price crossing the Middle Line is a statistically significant trend change signal.
* **Dynamic Support:** The Moving Upper/Lower bands act as dynamic support/resistance levels that adapt instantly to the trend's steepness.
