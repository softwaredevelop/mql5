# MACD Laguerre Professional

## 1. Summary (Introduction)

The `MACD_Laguerre_Pro` is a modern, high-performance variant of the classic MACD indicator. It replaces all three traditional Exponential Moving Averages (EMAs) with John Ehlers' extremely responsive, low-lag Laguerre filters.

The result is a "pure" Laguerre-based system that provides a much smoother, more cyclical, and significantly faster representation of momentum compared to its conventional counterpart. By using Laguerre filters for the fast line, slow line, and the signal line, the indicator minimizes the cumulative lag that is a common drawback of the standard MACD.

This indicator calculates and displays all three core components of a MACD system:

* **MACD Line:** The difference between a fast and a slow Laguerre filter.
* **Signal Line:** A Laguerre filter applied to the MACD Line.
* **Histogram:** The difference between the MACD Line and the Signal Line.

## 2. Mathematical Foundations and Calculation Logic

The entire system is built using Laguerre filters, with their speed controlled by the `gamma` ($\gamma$) coefficient. A smaller gamma results in a faster, more responsive filter.

### Required Components

* **Fast Gamma ($\gamma_{fast}$)** and **Slow Gamma ($\gamma_{slow}$)** for the MACD Line.
* **Signal Gamma ($\gamma_{signal}$)** for the Signal Line.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate the Fast and Slow Laguerre Filters:** Two separate Laguerre filters are calculated on the source price `P`, one with a fast gamma and one with a slow gamma.
    * $\text{Fast Filter}_t = \text{LaguerreFilter}(P, \gamma_{fast})_t$
    * $\text{Slow Filter}_t = \text{LaguerreFilter}(P, \gamma_{slow})_t$

2. **Calculate the MACD Line:** The MACD Line is the difference between the two filters.
    * $\text{MACD Line}_t = \text{Fast Filter}_t - \text{Slow Filter}_t$

3. **Calculate the Signal Line:** A third Laguerre filter is applied directly to the `MACD Line` calculated in the previous step, using the signal gamma.
    * $\text{Signal Line}_t = \text{LaguerreFilter}(\text{MACD Line}, \gamma_{signal})_t$

4. **Calculate the Histogram:** The final output is the difference between the MACD Line and the Signal Line.
    * $\text{Histogram}_t = \text{MACD Line}_t - \text{Signal Line}_t$

## 3. MQL5 Implementation Details

* **Modular and Composite Design:** The core logic is encapsulated in the `MACD_Laguerre_Calculator.mqh`. This calculator uses a composition-based design:
  * It contains **two instances** of our robust `Laguerre_Engine` to generate the base MACD line from the source price.
  * For maximum stability and to avoid complexities with applying an engine to an already calculated array, the **signal line's Laguerre filter is calculated manually** within the `Calculate` method, with its own dedicated state-management variables.

* **Robust Initialization:** The `Init` method is "foolproof." It automatically identifies which of the two user-provided gamma values for the MACD line is smaller (fast) and which is larger (slow), ensuring the indicator always works correctly regardless of input order.

* **Heikin Ashi Integration:** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **Gamma 1 (`InpGamma1`):** The gamma coefficient for one of the base Laguerre filters (e.g., `0.2` for fast).
* **Gamma 2 (`InpGamma2`):** The gamma coefficient for the other base Laguerre filter (e.g., `0.8` for slow).
* **Signal Gamma (`InpSignalGamma`):** The gamma coefficient for the signal line's Laguerre filter. A mid-range value like `0.5` is a good starting point.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MACD Laguerre provides the same types of signals as a traditional MACD, but often with greater clarity and less delay.

* **Signal Line Crossover (Primary Signal):**
  * **Bullish Crossover:** When the **MACD Line (blue) crosses above the Signal Line (red)**, it is a buy signal. This is confirmed when the histogram crosses above zero.
  * **Bearish Crossover:** When the **MACD Line crosses below the Signal Line**, it is a sell signal. This is confirmed when the histogram crosses below zero.
* **Zero Line Crossover:**
  * When the MACD Line crosses **above the zero line**, it indicates that overall momentum has shifted to bullish.
  * When the MACD Line crosses **below the zero line**, it indicates that momentum has shifted to bearish. This can be used as a trend filter.
* **Histogram Dynamics:**
  * **Growing Bars:** Indicate that momentum is accelerating in the current direction.
  * **Shrinking Bars (towards zero):** Indicate that momentum is decelerating, providing an early warning of a potential trend change or consolidation.
* **Divergence:** As with any MACD, divergence between the histogram's peaks/troughs and price action can signal powerful, high-probability reversal opportunities. Because the Laguerre MACD is smoother, these divergences are often clearer and easier to spot than on a traditional MACD.
