# Laguerre RSI Adaptive Pro

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter. Each member utilizes the filter's extremely low-lag and smooth characteristics to analyze different aspects of market behavior.
>
> * [Laguerre Filter](./Laguerre_Filter_Pro.md): A fast, responsive moving average.
> * [Laguerre RSI](./Laguerre_RSI_Pro.md): A smooth, noise-filtered momentum oscillator.
> * [Laguerre Filter Adaptive](./Laguerre_Filter_Adaptive_Pro.md): A self-adjusting Laguerre Filter.
> * **Laguerre RSI Adaptive:** A self-adjusting Laguerre RSI that dynamically adapts its smoothing based on the measured market cycle.

The Laguerre RSI Adaptive is the culmination of John Ehlers' cycle analysis and filtering techniques, applied to the concept of the Relative Strength Index. It is an intelligent oscillator that **automatically adjusts its own speed and smoothness** by measuring the dominant cycle period of the market in real-time.

* In **strong, trending markets**, the indicator measures a long cycle period. It automatically becomes **slower and smoother**, staying pinned to the overbought/oversold zones to avoid generating premature, trend-fading exit signals.
* In **choppy, sideways markets**, it measures a short cycle period. It automatically becomes **faster and more responsive**, oscillating quickly between extremes to capture the turning points of the range.

This self-adjusting mechanism creates a robust oscillator that aims to be "fast when you need it, slow when you don't," providing clearer signals across different market conditions.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a multi-stage digital signal processing (DSP) pipeline. The core of this is the **Homodyne Discriminator**, a method for measuring the instantaneous cycle period, which then controls the `gamma` of the Laguerre RSI calculation.

### Calculation Steps (Algorithm)

1. **Band-Pass Filtering:** The source price is first passed through a band-pass filter to isolate the most common market cycle components.
2. **Hilbert Transform:** The filtered price data is processed by a Hilbert Transform to generate its "InPhase" (I) and "Quadrature" (Q) components.
3. **Homodyne Discriminator:** The algorithm calculates the rate of change of the signal's phase from the I/Q components.
4. **Cycle Period Calculation:** The rate of phase change is converted into the dominant cycle period (in bars), which is then smoothed and stabilized.
5. **Adaptive Gamma Calculation:** The measured cycle period is used to calculate the optimal `gamma` for that specific bar:
    $\gamma = \frac{4}{\text{Cycle Period}}$
6. **Laguerre Filter Application:** The standard four-component Laguerre filter (`L0, L1, L2, L3`) is applied to the source price, using the **dynamically calculated `gamma`** for that bar.
7. **Final RSI Calculation:** The final indicator value is calculated from the components of the adaptive filter using the standard Laguerre RSI formula:
    * The "up" (`cu`) and "down" (`cd`) sums are calculated from the differences between the `L0, L1, L2, L3` components.
    * $\text{Adaptive Laguerre RSI}_i = 100 \times \frac{cu}{cu + cd}$

## 3. MQL5 Implementation Details

* **Self-Contained, Stateful Calculator:** Due to the complexity of the cycle measurement algorithm, this indicator uses a dedicated, self-contained calculator (`Laguerre_RSI_Adaptive_Calculator.mqh`). This calculator is designed as a **stateful class**, where all internal recursive variables (for cycle measurement and filtering) are stored as member variables. This ensures that the indicator's state is correctly maintained between ticks.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers for the Homodyne Discriminator (`m_filt_buf`, `m_I1_buf`, etc.) and the Laguerre RSI (`m_L0_buf`, etc.) persist their state between ticks. This allows the complex DSP pipeline to continue seamlessly from the last known values without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the entire adaptive calculation to be performed seamlessly on smoothed Heikin Ashi data, leveraging the same optimized engine.

* **Value Clamping:** The final calculated value is mathematically clamped to the 0-100 range.

## 4. Parameters

* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Note:** This indicator has **no `gamma` or period parameters**, as its primary function is to calculate these values automatically from the price action.

## 5. Usage and Interpretation

The Adaptive Laguerre RSI should be interpreted as an "intelligent" RSI that changes its character based on the market's behavior.

* **Context-Aware Signals:** The key advantage is that the indicator's signals are more reliable across different market regimes.
  * **In a Ranging Market:** The indicator will be fast and responsive, providing clear overbought/oversold signals near the top and bottom of the range. A cross down from the 80 level or up from the 20 level can be used as a reversal signal.
  * **In a Trending Market:** The indicator will become slow and smooth, "hugging" the 80-100 zone in a strong uptrend or the 0-20 zone in a strong downtrend. In this state, it acts as a **trend confirmation tool**. A brief dip out of the extreme zone followed by a return can signal a trend continuation entry point.
* **Reduced False Signals:** By slowing down in trends, the indicator avoids generating premature "sell" signals in an uptrend or "buy" signals in a downtrend, which is a common problem with standard, fixed-period oscillators.
* **Divergence:** Divergence signals (as described in the standard Laguerre RSI documentation) are still valid and can be particularly powerful, as they indicate a mismatch between price action and the adaptively measured momentum.
