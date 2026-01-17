# Laguerre Stochastic Slow Pro

## 1. Summary (Introduction)

The **Laguerre Stochastic Slow Pro** is a balanced oscillator designed to provide clear, actionable signals by filtering the noise inherent in the fast Laguerre Stochastic.

It occupies the "middle ground" in our Laguerre Stochastic family:

* **Faster than `StochSlow_on_LaguerreRSI_Pro`:** Because it derives its values directly from the Laguerre filter's internal state (not from an RSI calculation), it reacts more directly to price changes.
* **Smoother than `Laguerre_Stoch_Fast_Pro`:** By applying a "Slowing" moving average to the raw %K line, it eliminates false signals and whipsaws common in the Fast version.

This makes it an excellent all-around choice for traders who want the responsiveness of the Laguerre filter without the excessive noise.

## 2. Mathematical Foundations

The calculation process involves three distinct steps:

1. **Calculate Raw %K (Fast Stochastic):**
    First, the indicator calculates the raw Stochastic value based on the four internal components of the Laguerre Filter ($L0, L1, L2, L3$).
    * $\text{Raw } \%K = \frac{L0 - \min(L0..L3)}{\max(L0..L3) - \min(L0..L3)} \times 100$

2. **Calculate Slow %K (Main Line):**
    The Raw %K is then smoothed using a moving average. This smoothed line is the main blue line displayed on the chart.
    * $\text{Slow } \%K = \text{MA}(\text{Raw } \%K, \text{Slowing Period})$

3. **Calculate Signal %D (Signal Line):**
    Finally, the Slow %K is smoothed again to create the signal line (red line).
    * $\text{Signal } \%D = \text{MA}(\text{Slow } \%K, \text{Signal Period})$

## 3. Parameters

* **Gamma (`InpGamma`):** Controls the responsiveness of the underlying Laguerre filter. Default is `0.7`.
* **Source Price (`InpSourcePrice`):** Selects the input data (Standard or Heikin Ashi).
* **Slowing Period (`InpSlowingPeriod`):** The smoothing period applied to the Raw %K. Increasing this value makes the main line smoother but adds lag. Default is `3`.
* **Slowing Method (`InpSlowingMethod`):** The type of moving average used for slowing (SMA, EMA, etc.).
* **Signal Period (`InpSignalPeriod`):** The smoothing period for the Signal line. Default is `3`.
* **Signal Method (`InpSignalMethod`):** The type of moving average used for the signal line.

## 4. Usage and Interpretation

* **Crossovers:** The primary signal is the crossover of the **Slow %K** (Blue) and the **Signal %D** (Red).
  * **Buy:** Blue crosses above Red (ideally in the oversold zone < 20).
  * **Sell:** Blue crosses below Red (ideally in the overbought zone > 80).
* **Divergence:** Look for divergences between price action and the Slow %K line. If price makes a lower low but the oscillator makes a higher low, it suggests waning bearish momentum.
* **Trend Confirmation:** In a strong uptrend, the oscillator will tend to stay in the upper half (> 50). In a downtrend, it will stay in the lower half (< 50).
