# Double Smoothed Stochastic Professional

## 1. Summary (Introduction)

The `Stochastic_DoubleSmoothed_Pro` is an implementation of William Blau's "Double Smoothed Stochastics." It is an advanced and significantly smoother version of the classic Stochastic Oscillator, designed to reduce market noise and provide clearer signals while maintaining a surprisingly low amount of lag.

Unlike the standard Slow Stochastic, which smooths the final `%K` line, Blau's method applies a **double exponential smoothing** process directly to the **numerator and denominator** of the raw Stochastic calculation *before* the final division.

The result is an oscillator with much rounder, cleaner turning points, making it easier to identify the underlying momentum cycles and spot divergences.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core logic lies in the separate, multi-stage smoothing of the Stochastic components.

### Required Components

* **Stochastic Period (q):** The lookback period for the initial High/Low range.
* **Smoothing Periods (r, s):** The periods for the two consecutive exponential smoothing passes.
* **Signal Period:** The period for the final signal line smoothing.

### Calculation Steps (Algorithm)

1. **Calculate Raw Stochastic Components:** For each bar, calculate the raw numerator and denominator of the Stochastic formula.
    * $\text{Numerator}_t = \text{Close}_t - \text{LowestLow}(q)_t$
    * $\text{Denominator}_t = \text{HighestHigh}(q)_t - \text{LowestLow}(q)_t$

2. **First Exponential Smoothing (Period r):** Apply a first pass of exponential smoothing to both the numerator and denominator series.
    * $\text{EMA}(\text{Numerator}, r)_t$
    * $\text{EMA}(\text{Denominator}, r)_t$

3. **Second Exponential Smoothing (Period s):** Apply a second pass of exponential smoothing to the results of the first pass.
    * $\text{EMA}(\text{EMA}(\text{Numerator}, r), s)_t$
    * $\text{EMA}(\text{EMA}(\text{Denominator}, r), s)_t$

4. **Calculate the Final %K Line:** The main oscillator line is the ratio of the two double-smoothed components, scaled to 100.
    * $\text{\%K}_t = 100 \times \frac{\text{EMA}(\text{EMA}(\text{Numerator}, r), s)_t}{\text{EMA}(\text{EMA}(\text{Denominator}, r), s)_t}$

5. **Calculate the %D Signal Line:** A final, single exponential moving average is applied to the `%K` line to create the signal line.
    * $\text{\%D}_t = \text{EMA}(\text{\%K}, \text{Signal Period})_t$

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`Stochastic_DoubleSmoothed_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file.

* **Reusable Components:** The calculator leverages our universal `CalculateEMA` helper function (originally from the `MovingAverage_Engine`) to perform the multiple smoothing passes efficiently and consistently. This is a prime example of our modular toolkit in action.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

* **Robust Calculation Chain:** The implementation carefully manages the starting points of each consecutive smoothing calculation to ensure that each step is based on valid, previously calculated data, preventing errors and ensuring stability.

## 4. Parameters

* **Stochastic Period (`InpStochPeriod`):** The lookback period `(q)` for the initial High/Low range.
* **1st Smoothing Period (`InpSmoothPeriod1`):** The period `(r)` for the first EMA smoothing pass.
* **2nd Smoothing Period (`InpSmoothPeriod2`):** The period `(s)` for the second EMA smoothing pass.
* **Signal Line Period (`InpSignalPeriod`):** The period for the final EMA smoothing of the %K line.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The Double Smoothed Stochastic is a powerful tool for traders who find the classic Stochastic too "noisy" or erratic.

* **Comparison to Classic Slow Stochastic:**
  * The Double Smoothed Stochastic produces significantly **smoother, more rounded peaks and troughs**. This helps to filter out minor, insignificant momentum fluctuations and focus on the major swings.
  * Despite its smoothness, the use of exponential smoothing ensures that it remains surprisingly responsive and does not introduce excessive lag compared to an SMA-based Slow Stochastic.

* **Clearer Divergences:** Due to its smoothness, divergences between the oscillator and price are often much cleaner and easier to identify than on a standard Stochastic.

* **Trend and Momentum Confirmation:**
  * When the oscillator is consistently holding above the 50 level, it confirms a bullish momentum bias.
  * When it is holding below the 50 level, it confirms a bearish momentum bias.
  * Crossovers of the %K and %D lines provide standard bullish and bearish signals, but they tend to be less frequent and more significant than on a classic Stochastic.
