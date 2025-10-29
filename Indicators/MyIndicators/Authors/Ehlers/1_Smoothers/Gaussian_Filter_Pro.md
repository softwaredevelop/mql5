# Gaussian Filter Professional

## 1. Summary (Introduction)

The Gaussian Filter, developed by John Ehlers, is a low-lag, second-order (2-pole) smoothing filter. It is designed to provide a superior alternative to traditional moving averages by offering a very low lag comparable to other filters of the same order, while effectively smoothing price data.

Ehlers notes that a Gaussian filter can be implemented by taking an EMA of an EMA (a DEMA), but his version uses a precisely calculated `alpha` smoothing factor derived from the desired "cutoff" period. This ensures that the filter has a predictable and stable frequency response.

The result is a fast, smooth, and responsive trendline that is excellent for identifying the short- to mid-term trend with minimal delay.

## 2. Mathematical Foundations and Calculation Logic

The Gaussian Filter is a 2-pole Infinite Impulse Response (IIR) filter. Its calculation is recursive, meaning the current output depends on the two previous output values.

### Required Components

* **Period (N):** The "cutoff" period of the filter, which controls its smoothing and responsiveness.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Coefficients:** Based on the user-defined `Period`, three key coefficients (`c0`, `a1`, `a2`) are calculated. These are derived from an intermediate `alpha` value that is specifically calculated for Gaussian filters to relate it to the cutoff period.
    * $\beta = 2.415 \times (1 - \cos(\frac{2\pi}{N}))$
    * $\alpha = -\beta + \sqrt{\beta^2 + 2\beta}$
    * $c_0 = \alpha^2$
    * $a_1 = 2 \times (1 - \alpha)$
    * $a_2 = -(1 - \alpha)^2$
2. **Apply Recursive Formula:** The final filter value is calculated using the following recursive equation:
    $\text{Filt}_i = c_0 \times P_i + a_1 \times \text{Filt}_{i-1} + a_2 \times \text{Filt}_{i-2}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Gaussian_Filter_Calculator.mqh`):** The entire recursive calculation, including the coefficient computation, is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation is highly state-dependent. To ensure absolute stability, the indicator employs a **full recalculation** on every `OnCalculate` call, with the recursive state (`f[1]`, `f[2]`) managed internally within the calculation loop.
* **Definition-True Initialization:** The filter is "warmed up" by setting the initial output values to the raw price for the first few bars, providing a stable starting point for the recursion.

## 4. Parameters

* **Period (`InpPeriod`):** The cutoff period (`N`) of the filter. This acts similarly to the period of a traditional moving average.
  * A **shorter period** (e.g., 10-20) results in a faster, more responsive filter.
  * A **longer period** (e.g., 30-50) results in a smoother, slower filter that identifies longer-term trends.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Gaussian Filter should be used as a high-quality, low-lag replacement for traditional moving averages, particularly the EMA. Its usage is identical to other trend-following moving averages.

* **Dynamic Support and Resistance:** The filter line acts as a dynamic level of support in an uptrend and resistance in a downtrend.
* **Trend Filtering:** A longer-period Gaussian filter can be used to define the overall market bias.
* **Crossover Signals:** A system using a fast and a slow Gaussian filter will generate crossover signals with less lag than an equivalent EMA-based system.

The key advantage of the Gaussian filter is its excellent balance between smoothing and responsiveness.

### **Combined Strategy with Gaussian Momentum (Advanced)**

The filter's true potential is unlocked when used with its companion oscillator, the `Gaussian_Momentum_Pro`. A key predictive relationship exists between them:

* **The Momentum Oscillator's zero-cross predicts the Filter's turning point.**
  * When the `Gaussian_Momentum` oscillator crosses **above its zero line**, it provides an early warning that the `Gaussian_Filter` is about to form a **trough (a bottom)**.
  * When the `Gaussian_Momentum` oscillator crosses **below its zero line**, it provides an early warning that the `Gaussian_Filter` is about to form a **peak (a top)**.

This relationship allows a trader to use the momentum oscillator as a **leading indicator** to anticipate the turning points of the smoother, lagging Gaussian Filter, providing a significant edge in timing entries and exits.
