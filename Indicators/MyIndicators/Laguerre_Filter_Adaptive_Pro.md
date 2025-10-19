# Laguerre Filter Adaptive Professional

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter. Each member utilizes the filter's extremely low-lag and smooth characteristics to analyze different aspects of market behavior.
>
> * [Laguerre Filter](./Laguerre_Filter_Pro.md): A fast, responsive moving average with a fixed `gamma`.
> * [Laguerre RSI](./Laguerre_RSI_Pro.md): A smooth, noise-filtered momentum oscillator.
> * **Laguerre Filter Adaptive:** A self-adjusting Laguerre Filter that dynamically adapts its smoothing based on the measured market cycle.

The Laguerre Filter Adaptive, developed by John Ehlers, represents the pinnacle of his cycle analysis research. It is an intelligent moving average that **automatically adjusts its own smoothing factor (gamma)** in real-time by measuring the dominant cycle period of the market.

* In **long, trending markets**, the indicator measures a long cycle period and automatically **increases its smoothing** (lowers its gamma) to provide a stable trendline.
* In **choppy, sideways markets**, it measures a short cycle period and **decreases its smoothing** (increases its gamma) to react more quickly to oscillations.

This self-adjusting mechanism aims to solve the classic dilemma of choosing between a fast or a slow moving average, offering a filter that is "in tune" with the market's current rhythm.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a multi-stage digital signal processing (DSP) pipeline to achieve its adaptive behavior. The core of this is the **Homodyne Discriminator**, a method for measuring the instantaneous cycle period.

### Calculation Steps (Algorithm)

1. **Band-Pass Filtering:** The source price is first passed through a band-pass filter. This isolates the most common market cycle components (typically between 6 and 50 bars) by removing very long-term trends and high-frequency noise.
2. **Hilbert Transform:** The filtered price data is then processed by a Hilbert Transform to generate its analytical "InPhase" (I) and "Quadrature" (Q) components. These two components describe the cyclical signal as a complex number.
3. **Homodyne Discriminator:** This is the core of the cycle measurement. By comparing the current I/Q values with the previous ones, the algorithm calculates the rate of change of the signal's phase.
4. **Cycle Period Calculation:** The rate of phase change is directly converted into the dominant cycle period (in bars). This value is then smoothed and limited to a reasonable range (e.g., 6 to 50 bars) to ensure stability.
5. **Adaptive Gamma Calculation:** The measured and smoothed cycle period is used to calculate the optimal `gamma` for the Laguerre filter for that specific bar. The formula is typically:
    $\gamma = \frac{4}{\text{Cycle Period}}$
6. **Laguerre Filter Application:** Finally, the standard Laguerre Filter algorithm is applied to the original source price, but instead of using a fixed `gamma`, it uses the **dynamically calculated `gamma`** from the previous step. The output of the indicator is the final, weighted result of this adaptive filter.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator:** Due to the complexity of the cycle measurement algorithm, this indicator uses a dedicated, self-contained calculator (`Laguerre_Filter_Adaptive_Calculator.mqh`) and does not rely on the simpler `Laguerre_Engine.mqh`.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the entire adaptive calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation is a highly complex, multi-stage recursive process where every new value depends on multiple previous states. To ensure absolute stability and prevent desynchronization, the indicator employs a **full recalculation** on every `OnCalculate` call. This is the only robust method for this type of DSP filter.

## 4. Parameters

* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Note:** Unlike the standard Laguerre Filter, this indicator has **no `gamma` parameter**, as its primary function is to calculate this value automatically.

## 5. Usage and Interpretation

The Adaptive Laguerre Filter should be interpreted as an "intelligent" moving average that changes its character based on the market's behavior.

* **Trend Identification:** Like any moving average, its primary use is to identify the trend. Price action above a rising filter is bullish; price action below a falling filter is bearish.
* **Adaptive Behavior:**
  * **In a strong trend:** The filter will appear smooth and slow, acting as a stable baseline for the trend, similar to a long-period EMA.
  * **In a choppy/ranging market:** The filter will become faster and more "wiggly," hugging the price more closely to capture the shorter oscillations.
* **Dynamic Support and Resistance:** The filter line acts as a dynamic level of support or resistance. Its adaptive nature means that the "strength" of this level can be inferred from its smoothness. A smooth, flat line in a range is often a very strong S/R level.
* **Contextual Analysis:** The main advantage is context. By observing the filter's behavior (is it smooth or is it fast?), the trader can gain insight into the market's current cyclical state and choose the appropriate strategy (trend-following vs. mean-reversion).
