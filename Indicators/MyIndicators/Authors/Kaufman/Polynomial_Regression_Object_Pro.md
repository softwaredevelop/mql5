# Polynomial Regression Object Professional

## 1. Summary (Introduction)

The `Polynomial_Regression_Object_Pro` is an advanced regression channel indicator that models price movements using a **curvilinear (2nd-order polynomial) function**. Unlike a standard linear regression channel, which can only fit a straight line to the data, this indicator can adapt to **accelerating and decelerating trends**, drawing a parabolic curve that more accurately reflects the market's momentum.

Instead of plotting a historical line, this indicator draws a single, "floating" channel object that is continuously recalculated for the most recent `N` bars. This provides a real-time, forward-looking view of the current trend's trajectory and curvature.

The indicator is an exceptionally powerful tool for:

* Identifying trend acceleration and exhaustion.
* Visualizing dynamic, curved support and resistance levels.
* Confirming trend reversals earlier than linear methods.

## 2. Mathematical Foundations and Calculation Logic

The indicator fits a 2nd-order polynomial equation (`y = a + bx + cx²`) to the last `N` data points using the method of least squares.

### Required Components

* **Regression Period (N):** The lookback period for the calculation.
* **Deviation Multiplier (D):** The multiplier for the standard deviation bands.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

For each new bar, the following process is performed on the most recent `N` price points:

1. **Calculate Sums:** The engine calculates all necessary sums for solving the regression equations. For a 2nd-order polynomial, these include `Σx, Σy, Σx², Σxy, Σx³, Σx⁴,` and `Σx²y`, where `y` is the price and `x` is the time index (0, 1, 2, ..., N-1).

2. **Solve for Coefficients:** The system of linear equations is solved to find the unique coefficients `a`, `b`, and `c` that define the parabola of best fit for the current data window.

3. **Calculate Midline Points:** Using the calculated coefficients, the indicator computes the price value of the parabola (`y = a + bx + cx²`) for each of the `N` points in the lookback period. This forms the curved midline.

4. **Calculate Standard Deviation of Errors:** The standard deviation between the actual price points and their corresponding values on the fitted parabola is calculated. This measures how well the curve fits the data.

5. **Calculate Channel Bands:** The upper and lower channel lines are calculated by adding/subtracting the standard deviation (multiplied by the deviation factor) from the midline points.
    * $\text{Upper Band}_t = \text{Midline}_t + (D \times \text{StdDev})$
    * $\text{Lower Band}_t = \text{Midline}_t - (D \times \text{StdDev})$

## 3. MQL5 Implementation Details

* **Object-Based Drawing:** This indicator does **not** use standard indicator buffers for plotting. Instead, it generates a set of graphical objects (`OBJ_TREND`) on the chart. The smooth curves are constructed from many small, connected straight-line segments.

* **High Efficiency:** The entire calculation and object redrawing process is computationally intensive. To ensure optimal performance, the logic is executed **only once per bar**, not on every tick. On each new bar, the old objects are deleted and the new channel is drawn.

* **Robust Object Management:** All objects created by the indicator share a unique, randomly generated prefix. This ensures that the indicator only manages its own objects and prevents conflicts with other tools on the chart. All objects are automatically cleaned up when the indicator is removed.

* **Modular Calculation Engine (`Polynomial_Regression_Object_Calculator.mqh`):** All complex mathematical and drawing logic is encapsulated within the dedicated calculator engine, keeping the main indicator file clean and simple.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the regression calculation. A larger period will result in a smoother, more stable curve, while a shorter period will be more responsive. Default is `50`.
* **Deviation (`InpDeviation`):** The standard deviation multiplier for the channel bands. Default is `2.0`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The Polynomial Regression Channel provides insights that are impossible to see with a linear channel.

* **Identifying Trend Curvature:** This is the indicator's primary strength.
  * **Upward Curve (Smiling Parabola):** Indicates that a downtrend is losing momentum and a bullish reversal or bottoming formation is in progress.
  * **Downward Curve (Frowning Parabola):** Indicates that an uptrend is losing momentum and a bearish reversal or topping formation is in progress.
  * **Steep Curve:** Signals a strongly accelerating trend.
* **Dynamic Support and Resistance:** The curved channel lines provide much more accurate support and resistance levels in non-linear trends compared to straight lines. Price bouncing off the lower band of an upward-curving channel is a strong bullish continuation signal.
* **Early Reversal Signals:** A change in the channel's curvature (e.g., from downward to flat, then to upward) can provide a very early visual confirmation of a major trend change, often well before traditional moving averages cross over.
