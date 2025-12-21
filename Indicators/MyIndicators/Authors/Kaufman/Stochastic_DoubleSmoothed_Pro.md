# Double Smoothed Stochastic Professional

## 1. Summary (Introduction)

The `Stochastic_DoubleSmoothed_Pro` is an implementation of William Blau's "Double Smoothed Stochastics." It is an advanced and significantly smoother version of the classic Stochastic Oscillator, designed to reduce market noise and provide clearer signals.

**The Blau Difference:** Unlike the standard Slow Stochastic, which smooths the final `%K` ratio, Blau's method applies a **double smoothing** process directly to the **numerator and denominator** of the raw Stochastic calculation *before* the final division. This results in a mathematically superior, cleaner signal.

**Pro Features:** Our implementation extends this concept by allowing full customization of the smoothing methods (not just EMA) and supporting Heikin Ashi price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator's core logic lies in the separate, multi-stage smoothing of the Stochastic components.

### Required Components

* **Stochastic Period (q):** The lookback period for the initial High/Low range.
* **Smoothing Periods (r, s):** The periods for the two consecutive smoothing passes.
* **Signal Period:** The period for the final signal line smoothing.

### Calculation Steps (Algorithm)

1. **Calculate Raw Components:** For each bar, calculate the raw numerator and denominator.
    * $\text{Numerator}_t = \text{Close}_t - \text{LowestLow}(q)_t$
    * $\text{Denominator}_t = \text{HighestHigh}(q)_t - \text{LowestLow}(q)_t$

2. **First Smoothing (Period r):** Apply the first pass of smoothing (e.g., EMA) to both the numerator and denominator series.

3. **Second Smoothing (Period s):** Apply the second pass of smoothing to the results of the first pass.

4. **Calculate the Final %K Line:** The main oscillator line is the ratio of the two double-smoothed components.
    * $\text{\%K}_t = 100 \times \frac{\text{MA}_2(\text{MA}_1(\text{Numerator}))_t}{\text{MA}_2(\text{MA}_1(\text{Denominator}))_t}$

5. **Calculate the %D Signal Line:** A final moving average is applied to the `%K` line.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The calculator (`Stochastic_DoubleSmoothed_Calculator.mqh`) is a powerhouse that utilizes **five** instances of our universal `MovingAverage_Engine.mqh`:
    1. **Numerator Smoothing 1**
    2. **Denominator Smoothing 1**
    3. **Numerator Smoothing 2**
    4. **Denominator Smoothing 2**
    5. **Signal Line Smoothing**
    This architecture allows for extreme flexibility (e.g., using DEMA for internal smoothing) while maintaining code consistency.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks, ensuring seamless updates for the recursive smoothing chains.

## 4. Parameters

* **Stochastic Period (`InpStochPeriod`):** The lookback period `(q)`. (Default: `5`).
* **1st Smoothing Period (`InpSmoothPeriod1`):** The period `(r)` for the first smoothing pass. (Default: `3`).
* **1st Smoothing Type (`InpSmoothMAType1`):** The MA type for the first pass. (Default: `EMA`).
* **2nd Smoothing Period (`InpSmoothPeriod2`):** The period `(s)` for the second smoothing pass. (Default: `3`).
* **2nd Smoothing Type (`InpSmoothMAType2`):** The MA type for the second pass. (Default: `EMA`).
* **Signal Line Period (`InpSignalPeriod`):** The period for the final smoothing. (Default: `3`).
* **Signal Line Type (`InpSignalMAType`):** The MA type for the signal line. (Default: `EMA`).
* **Applied Price (`InpSourcePrice`):** The source price (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The Double Smoothed Stochastic is a powerful tool for traders who find the classic Stochastic too "noisy" or erratic.

* **Smoother Signals:** It produces significantly **smoother, more rounded peaks and troughs**, filtering out minor fluctuations.
* **Clearer Divergences:** Divergences between the oscillator and price are often much cleaner and easier to identify.
* **Trend Confirmation:** Holding above 50 confirms bullish momentum; below 50 confirms bearish momentum.
