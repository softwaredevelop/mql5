# Gaussian Momentum Professional

## 1. Summary (Introduction)

The Gaussian Momentum Pro is an oscillator based on the concepts of John Ehlers. It applies a low-lag, **2-Pole Gaussian Filter** to a **momentum source (Close - Open)** instead of the price.

While the standard `Gaussian_Filter_Pro` provides a smoothed representation of the trend, this indicator isolates and smooths the bar-by-bar momentum. The result is a responsive, zero-mean oscillator that measures the underlying strength and direction of price velocity.

The key advantage of using a Gaussian filter for this purpose is its ability to provide significant smoothing to the inherently noisy momentum data, while introducing minimal lag compared to traditional moving averages.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a Gaussian-smoothed average of the `Close - Open` value of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Gaussian Filter:** A 2-pole Gaussian filter is calculated on this `Momentum` data series. The recursive formula is:
    $\text{Filt}_i = c_0 \times \text{Momentum}_i + a_1 \times \text{Filt}_{i-1} + a_2 \times \text{Filt}_{i-2}$
    The `c0, a1, a2` coefficients are derived from the user-selected `Period`.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Unified Calculator (`Gaussian_Filter_Calculator.mqh`):** This indicator uses the exact same, powerful calculator engine as the `Gaussian_Filter_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The indicator buffer itself acts as the persistent memory for the recursive calculation, ensuring seamless updates without drift or full recalculation.

* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`).

## 4. Parameters

* **Period (`InpPeriod`):** The cutoff period of the Gaussian filter, which controls its smoothing and responsiveness.
* **Applied Price (`InpSourcePrice`):** Selects between `Standard` and `Heikin Ashi` candles for the `Close - Open` calculation.

## 5. Usage and Interpretation

The Gaussian Momentum is a classic zero-mean oscillator used for identifying momentum shifts and potential reversals. It is most powerful when used in conjunction with its companion smoother, the `Gaussian_Filter_Pro`.

### Standalone Usage

* **Zero-Line Crossover:**
  * A cross **above the zero line** indicates that bullish momentum is taking control.
  * A cross **below the zero line** indicates that bearish momentum is dominant.
* **Divergence:**
  * **Bullish Divergence:** Price makes a **new lower low**, but the Gaussian Momentum makes a **higher low**. This signals weakening sell pressure.
  * **Bearish Divergence:** Price makes a **new higher high**, but the Gaussian Momentum makes a **lower high**. This signals weakening buy pressure.

### Combined Strategy with Gaussian Filter (Primary Use)

The relationship between the momentum oscillator and its corresponding smoother provides a powerful timing signal.

* **The Zero-Cross Predicts the Filter's Turning Point:**
  * **Buy Signal:** When the **Gaussian Momentum** line crosses **above the zero line**, it signals that the `Gaussian_Filter` on the main chart is forming a **trough (a bottom)**. This is a leading signal that the short-term downtrend is ending.
  * **Sell Signal:** When the **Gaussian Momentum** line crosses **below the zero line**, it signals that the `Gaussian_Filter` is forming a **peak (a top)**. This is a leading signal that the short-term uptrend is ending.
