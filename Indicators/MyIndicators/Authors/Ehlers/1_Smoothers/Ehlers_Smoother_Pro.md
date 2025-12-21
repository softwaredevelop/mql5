# Ehlers Smoother Pro

## 1. Summary (Introduction)

> **Part of the Ehlers Filter Family**
>
> This indicator is a member of a family of advanced digital filters described in John Ehlers' article, "The Ultimate Smoother." Each filter is designed to provide a superior balance between smoothing and lag compared to traditional moving averages.
>
> * **Ehlers Smoother Pro:** A 2-in-1 indicator featuring the **SuperSmoother** (for maximum smoothing) and the **UltimateSmoother** (for near-zero lag).
> * [Band-Pass Filter](./BandPass_Filter_Pro.md): An oscillator that isolates the cyclical components of the market.
> * [Ehlers Smoother Momentum Pro](./Ehlers_Smoother_Momentum_Pro.md): The oscillator version of this smoother.

The Ehlers Smoother Pro is a versatile, "two-in-one" indicator that implements two of John Ehlers' most advanced digital filters: the **SuperSmoother** and the **UltimateSmoother**.

The user can choose between the two filter types based on their trading style and needs:

1. **SuperSmoother:** An optimized, second-order (2-pole) Butterworth filter. Its primary goal is to provide **maximum smoothing** with less lag than a traditional moving average of equivalent smoothing power. It is Ehlers' recommendation as a direct replacement for the EMA.
2. **UltimateSmoother:** A unique filter created by mathematically subtracting a High-Pass filter's response from the original price data. Its primary goal is to achieve **near-zero lag** in the trend component of the price, at the cost of slightly less smoothing.

This indicator serves as a high-fidelity, responsive trendline for modern algorithmic and discretionary trading.

## 2. Mathematical Foundations and Calculation Logic

Both filters are recursive Infinite Impulse Response (IIR) filters and use coefficients derived from the user-selected `Period` to define their characteristics.

### SuperSmoother

The SuperSmoother is a 2-pole Butterworth filter optimized for reduced lag. Its recursive formula depends on the two previous filter values (`Filt[1]`, `Filt[2]`) and the average of the last two prices (`P[0]`, `P[1]`).
$\text{Filt}_i = c_1 \times \frac{P_i + P_{i-1}}{2} + c_2 \times \text{Filt}_{i-1} + c_3 \times \text{Filt}_{i-2}$

### UltimateSmoother

The UltimateSmoother is conceptually derived by subtracting a High-Pass filter from the price itself. Ehlers provides a closed-form recursive equation that achieves this result efficiently. It depends on the two previous filter values and the last three price points.
$\text{Filt}_i = (1-c_1)P_i + (2c_1-c_2)P_{i-1} - (c_1+c_3)P_{i-2} + c_2\text{Filt}_{i-1} + c_3\text{Filt}_{i-2}$

The coefficients `c1, c2, c3` are calculated based on the `Period` input.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability and performance.

* **Unified Calculator (`Ehlers_Smoother_Calculator.mqh`):** The complex, recursive calculations for both filter types are encapsulated within a single, dedicated calculator class. A user input determines which formula is executed.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The indicator buffer itself acts as the persistent memory for the recursive calculation (`Filt[i-1]`, `Filt[i-2]`), ensuring seamless updates without drift or full recalculation.

* **Definition-True Initialization:** The filter is carefully "warmed up" by setting the initial output values to the raw price for the first few bars, providing a stable starting point for the recursion.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.

## 4. Parameters

* **Smoother Type (`InpSmootherType`):** Allows the user to select which filter to display (`SUPERSMOOTHER` or `ULTIMATESMOOTHER`).
* **Period (`InpPeriod`):** The "critical period" of the filter. A longer period results in a smoother, slower filter. (Default: `20`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The choice between the two smoothers depends on your primary goal.

### Using the SuperSmoother (Focus on Clarity)

Best used as a high-quality replacement for any traditional moving average, especially for **trend identification**.

### Using the Ultimate Smoother (Focus on Speed)

Excels where responsiveness is critical, making it an excellent tool for identifying **dynamic support/resistance zones**.

### Combined Strategy with Smoother Momentum (Advanced)

The filter's true potential is unlocked when used with its companion oscillator, the **[Ehlers Smoother Momentum Pro](./Ehlers_Smoother_Momentum_Pro.md)**.

* **The Momentum Oscillator's zero-cross predicts the Smoother's turning point.**
  * **Buy Signal:** Momentum crosses above zero -> Smoother forms a trough.
  * **Sell Signal:** Momentum crosses below zero -> Smoother forms a peak.
