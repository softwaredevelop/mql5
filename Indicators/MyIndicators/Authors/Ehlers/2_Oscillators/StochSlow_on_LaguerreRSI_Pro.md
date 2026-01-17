# StochSlow on Laguerre RSI Pro

## 1. Summary (Introduction)

The **StochSlow on Laguerre RSI Pro** is a sophisticated "meta-indicator" that combines the smoothness of the **Laguerre RSI** with the cycle-detection capabilities of the **Slow Stochastic Oscillator**.

By applying the Stochastic formula to the Laguerre RSI (instead of raw price), this indicator normalizes the RSI's movements into a bounded 0-100 range, making it easier to identify cyclical turning points and extremes. It offers a smoother, more reliable signal than the Fast version, making it suitable for swing trading and trend confirmation.

## 2. Mathematical Foundations

This indicator performs a multi-stage calculation:

1. **Stage 1: Laguerre RSI:** First, the Relative Strength Index is calculated using the Laguerre Filter method (instead of the standard Wilder method). This produces a smooth, low-lag RSI.
2. **Stage 2: Stochastic Calculation:** The standard Stochastic formula is applied to the Laguerre RSI values over a lookback period (**K Period**).
    * $\text{Raw } \%K = \frac{\text{Current RSI} - \text{Lowest RSI}(K)}{\text{Highest RSI}(K) - \text{Lowest RSI}(K)} \times 100$
3. **Stage 3: Smoothing (Slow Stochastic):**
    * **Slow %K:** The Raw %K is smoothed using a moving average (defined by **Slowing Period**). This is the main blue line.
    * **Signal %D:** The Slow %K is smoothed again (defined by **D Period**) to create the signal line (red line).

## 3. Parameters

* **Gamma (`InpGamma`):** Controls the smoothness of the underlying Laguerre RSI. Default is `0.5`.
* **K Period (`InpKPeriod`):** The lookback period for finding the highest and lowest RSI values. Default is `14`.
* **Slowing Period (`InpSlowingPeriod`):** The smoothing applied to the Raw %K to create the Slow %K. Default is `3`.
* **D Period (`InpDPeriod`):** The smoothing for the Signal line. Default is `3`.
* **MA Types:** You can select the averaging method (SMA, EMA, etc.) for both the Slowing and Signal calculations.

## 4. Usage and Interpretation

* **Cycle Detection:** This indicator is excellent at visualizing the market's "breathing" rhythm. It clearly shows when the Laguerre RSI has reached the top or bottom of its recent range.
* **Precision Entries:** While the Laguerre RSI shows the *trend* strength, the Stochastic on top of it helps pinpoint the exact *turn*. Wait for the Slow %K to cross the Signal %D.
* **Divergence:** Divergences between price and this indicator are powerful reversal signals, often more reliable than divergences on raw price stochastic.
