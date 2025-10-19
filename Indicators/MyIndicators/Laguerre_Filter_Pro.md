# Laguerre Filter Professional

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter. Each member utilizes the filter's extremely low-lag and smooth characteristics to analyze different aspects of market behavior.
>
> * **Laguerre Filter:** A fast, responsive moving average.
> * **Laguerre RSI:** A smooth, noise-filtered momentum oscillator.

The Laguerre Filter, developed by John Ehlers, is a sophisticated, low-lag moving average based on the principles of digital signal processing. Unlike traditional moving averages (like SMA or EMA) which suffer from significant inherent delay, the Laguerre Filter is designed to follow the price action very closely while still filtering out high-frequency market noise.

It serves as a highly responsive trendline, providing a clearer and more timely view of the underlying trend.

Our `Laguerre_Filter_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator's logic is centered around the recursive Laguerre filter, which is controlled by a single parameter, `gamma`.

### Required Components

* **Gamma (γ):** A coefficient between 0 and 1 that controls the filter's smoothing and responsiveness.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

The calculation relies on the state of four internal filter components from the previous bar (`L0`, `L1`, `L2`, `L3`).

1. **Initialize Filter:** For the first bar, all `L` components are initialized with the current price.
2. **Calculate Laguerre Filter Components:** For each subsequent bar `i`, the filter components are updated recursively:
    * $L0_i = (1 - \gamma) \times P_i + \gamma \times L0_{i-1}$
    * $L1_i = -\gamma \times L0_i + L0_{i-1} + \gamma \times L1_{i-1}$
    * $L2_i = -\gamma \times L1_i + L1_{i-1} + \gamma \times L2_{i-1}$
    * $L3_i = -\gamma \times L2_i + L2_{i-1} + \gamma \times L3_{i-1}$
3. **Output:** The final value of the Laguerre Filter is the `L0` component.
    * $\text{Laguerre Filter}_i = L0_i$

## 3. MQL5 Implementation Details

* **Modular "Family" Architecture:** The core Laguerre filter calculation is encapsulated in a central `Laguerre_Engine.mqh` file. The `Laguerre_Filter_Calculator.mqh` is a thin adapter that includes this engine and simply outputs the `L0` component. This modular design ensures that all indicators in the Laguerre family (Filter, RSI, etc.) share the exact same, robust calculation core.
* **Heikin Ashi Integration:** An inherited `CLaguerreEngine_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** We employ a full recalculation within `OnCalculate`. For a highly state-dependent and recursive filter like Laguerre, this is the most robust and reliable method.

## 4. Parameters

* **Gamma (`InpGamma`):** The Laguerre filter coefficient, a value between 0.0 and 1.0. This is the most important parameter and controls the indicator's speed.
  * **Low Gamma (e.g., 0.1 - 0.3):** Slower, smoother line, similar to a longer-period traditional moving average.
  * **Medium Gamma (e.g., 0.4 - 0.6):** A balanced setting, offering a good compromise between responsiveness and smoothing.
  * **High Gamma (e.g., 0.7 - 0.9):** Faster, more responsive line that hugs the price very closely.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The Laguerre Filter is used as a superior, low-lag alternative to traditional moving averages.

* **Trend Identification:** It serves as a highly responsive trendline.
  * When the price is consistently above the Laguerre Filter and the line is rising, the trend is bullish.
  * When the price is consistently below the Laguerre Filter and the line is falling, the trend is bearish.
* **Crossover Signals:**
  * **Price Crossover:** A crossover of the price and the Laguerre Filter line can be used as a trade signal, similar to a standard moving average crossover. Due to its low lag, these signals are often more timely.
  * **Two-Line Crossover:** A classic fast/slow system can be created by placing two Laguerre Filter indicators on the chart with different `gamma` values (e.g., `0.5` for the fast line and `0.2` for the slow line). A crossover of the fast line above the slow line is a buy signal, and vice versa.
* **Dynamic Support and Resistance:** In a trending market, the Laguerre Filter line often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend), providing potential entry points on pullbacks.
