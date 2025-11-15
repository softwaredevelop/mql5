# Polynomial Regression Slope Professional

## 1. Summary (Introduction)

The `Polynomial_Regression_Slope_Pro` is a sophisticated momentum oscillator derived from the principles of curvilinear regression. It is the companion indicator to our `Polynomial_Regression_Object_Pro`. While the channel indicator visually plots the parabolic trendline, this oscillator calculates and displays the **slope (or first derivative)** of that moving parabolic curve at its most recent point.

In essence, this indicator measures the **velocity and acceleration of the trend** as modeled by the polynomial regression. The result is an exceptionally smooth, low-lag oscillator that provides clear signals about momentum shifts, peaks, and troughs.

* A positive value indicates a rising trend.
* A negative value indicates a falling trend.
* The zero line represents the exact peak or trough of the parabolic curve—the point where momentum turns.

## 2. Mathematical Foundations and Calculation Logic

The indicator's value is the first derivative of the 2nd-order polynomial equation (`y = a + bx + cx²`) that is continuously fitted to the most recent `N` price bars.

### Required Components

* **Regression Period (N):** The lookback period for the calculation.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

For each bar `t` in the history, the following process is performed on the data window from `t-N+1` to `t`:

1. **Calculate Polynomial Coefficients:** The system solves for the coefficients `a`, `b`, and `c` of the best-fit parabola `y = a + bx + cx²` for the current `N`-period window. The time variable `x` is a simple series from 0 to N-1.

2. **Calculate the First Derivative (Slope):** The slope of a parabolic curve is not constant; it changes at every point. Its value is given by the first derivative of the polynomial equation:
    $\text{Slope}(x) = \frac{dy}{dx} = b + 2cx$

3. **Determine the Current Slope:** The indicator calculates the slope at the most recent point of the regression window, which corresponds to `x = N-1`.
    $\text{Slope}_t = b + 2c(N-1)$

This final `Slope_t` value is what is plotted on the chart for bar `t`.

## 3. MQL5 Implementation Details

* **Self-Contained Calculation Engine (`Polynomial_Regression_Slope_Calculator.mqh`):** The entire multi-stage calculation logic is encapsulated within a single, dedicated include file. The engine is a streamlined version of the channel calculator, focused only on calculating the `b` and `c` coefficients to derive the slope.

* **Moving Window Calculation:** The calculator iterates through the entire price history. For each bar, it performs a full polynomial regression calculation on the preceding `N` bars to determine the historical slope value at that specific point in time.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the regression calculation. A larger period will result in a smoother, slower oscillator, while a shorter period will be more responsive. Default is `50`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The Polynomial Regression Slope is a powerful momentum oscillator with clear, easy-to-interpret signals.

* **Zero Line Crossover (Primary Signal):** This is the most important signal, as it marks the turning point of the trend's momentum.
  * **Bullish Crossover:** When the Slope line crosses **from negative to positive**, it indicates that the parabolic trend has just bottomed out and is starting to rise. This is a strong signal of a bullish momentum shift.
  * **Bearish Crossover:** When the Slope line crosses **from positive to negative**, it indicates that the parabolic trend has just peaked and is starting to fall. This is a strong signal of a bearish momentum shift.

* **Peaks and Troughs:**
  * Extreme peaks in the oscillator correspond to points of **maximum bullish acceleration**.
  * Extreme troughs correspond to points of **maximum bearish acceleration**.

* **Divergence:** As with any momentum oscillator, divergence between the Slope's peaks/troughs and price action can signal powerful reversal opportunities. Due to its smoothness, these divergences are often very clean and reliable.

* **Combined Usage:** When used on the same chart as the `Polynomial_Regression_Object_Pro` (with identical parameters), the Slope oscillator provides a mathematical confirmation of what is visually apparent. The moment the Slope oscillator crosses the zero line is the exact moment the parabolic channel object on the main chart reaches its highest or lowest point.
