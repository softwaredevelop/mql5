# Laguerre Filter Professional

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter. Each member utilizes the filter's extremely low-lag and smooth characteristics to analyze different aspects of market behavior.
>
> * **Laguerre Filter:** A fast, responsive moving average.
> * **Laguerre RSI:** A smooth, noise-filtered momentum oscillator.

The Laguerre Filter, developed by John Ehlers, is a sophisticated, low-lag moving average based on the principles of digital signal processing. It applies a weighted average to the components of a Laguerre-transformed price series, resulting in a unique balance between smoothness and responsiveness.

It serves as an advanced trendline, and optionally, it can display a comparative **FIR (Finite Impulse Response) filter** to visually demonstrate the smoothing effect of the Laguerre transformation.

Our `Laguerre_Filter_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator's logic is centered around the recursive Laguerre filter and a final weighted summation.

### Required Components

* **Gamma (γ):** A coefficient between 0 and 1 that controls the filter's smoothing.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Laguerre Filter Components:** For each bar `i`, the four internal filter components (`L0`...`L3`) are updated recursively.
    * $L0_i = (1 - \gamma) \times P_i + \gamma \times L0_{i-1}$
    * $L1_i = -\gamma \times L0_i + L0_{i-1} + \gamma \times L1_{i-1}$
    * ...and so on for `L2` and `L3`.
2. **Calculate the Final Weighted Filter:** The final output is a weighted sum of the four components, as defined by Ehlers.
    * $\text{Laguerre Filter}_i = \frac{L0_i + 2 \times L1_i + 2 \times L2_i + L3_i}{6}$
3. **(Optional) Calculate the FIR Filter:** For comparison, a standard FIR filter with the same weights is calculated on the raw price data.
    * $\text{FIR Filter}_i = \frac{P_i + 2 \times P_{i-1} + 2 \times P_{i-2} + P_{i-3}}{6}$

## 3. MQL5 Implementation Details

* **Modular "Family" Architecture:** The core Laguerre filter calculation is encapsulated in a central `Laguerre_Engine.mqh` file. This engine is a **stateful class**, meaning it correctly maintains the previous values of its internal components (`L0`...`L3`) between calculations. This is critical for the stability and accuracy of the recursive filter. The `Laguerre_Filter_Calculator.mqh` is a thin adapter that uses this stable engine.
* **Heikin Ashi Integration:** An inherited `CLaguerreEngine_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** We employ a full recalculation within `OnCalculate` for maximum stability.

## 4. Parameters

* **Gamma (`InpGamma`):** The Laguerre filter coefficient, a value between 0.0 and 1.0. This parameter controls the trade-off between smoothing and lag.
  * **High Gamma (e.g., 0.7 - 0.9):** Results in a **slower, smoother** line with **more lag**.
  * **Low Gamma (e.g., 0.1 - 0.3):** Results in a **faster, more responsive** line (less lag) that is less smooth. At `gamma = 0`, the Laguerre Filter becomes identical to the FIR filter.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.
* **Show FIR (`InpShowFIR`):** A boolean switch to show or hide the comparative FIR filter line on the chart.

## 5. Usage and Interpretation

The Laguerre Filter is used as a superior, low-lag alternative to traditional moving averages.

* **Trend Identification:** It serves as a highly responsive trendline.
  * When the price is consistently above the Laguerre Filter and the line is rising, the trend is bullish.
  * When the price is consistently below the Laguerre Filter and the line is falling, the trend is bearish.
* **Crossover Signals:** ...
  * **Two-Line Crossover:** A classic fast/slow system can be created by placing two Laguerre Filter indicators on the chart with different `gamma` values (e.g., `0.2` for the fast line and `0.7` for the slow line). A crossover of the fast line above the slow line is a buy signal, and vice versa.
  * **Two-Line Crossover:** A classic fast/slow system can be created by placing two Laguerre Filter indicators on the chart with different `gamma` values (e.g., `0.5` for the fast line and `0.2` for the slow line). A crossover of the fast line above the slow line is a buy signal, and vice versa.
* **Dynamic Support and Resistance:** In a trending market, the Laguerre Filter line often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend), providing potential entry points on pullbacks.

### **Combined Strategy with Laguerre Momentum (Advanced)**

The filter's characteristics can be better understood when used with its companion oscillator, the `Laguerre_Momentum_Pro`. A key predictive relationship exists between them:

* **The Momentum Oscillator's zero-cross predicts the Filter's turning point.**
  * When the `Laguerre_Momentum` oscillator crosses **above its zero line**, it provides an early warning that the `Laguerre_Filter` on the main chart is about to form a **trough (a bottom)**.
  * When the `Laguerre_Momentum` oscillator crosses **below its zero line**, it provides an early warning that the `Laguerre_Filter` is about to form a **peak (a top)**.

This relationship allows a trader to use the momentum oscillator as a **leading indicator** to anticipate the turning points of the smoother, lagging Laguerre Filter.
