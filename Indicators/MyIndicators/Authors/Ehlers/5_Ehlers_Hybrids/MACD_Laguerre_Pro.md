# MACD Laguerre Pro

## 1. Summary (Introduction)

The `MACD_Laguerre_Pro` is a modern, high-performance variant of the classic MACD. It replaces the traditional Exponential Moving Averages (EMAs) of the MACD line with John Ehlers' extremely responsive, low-lag **Laguerre filters**.

The result is a MACD line that is smoother, more cyclical, and significantly faster than its conventional counterpart. This indicator then enhances this low-lag MACD line with a **fully customizable signal line**, allowing the user to choose from standard moving averages or another Laguerre filter for maximum flexibility.

This indicator calculates and displays all three core components of a MACD system:

* **MACD Line:** The difference between a fast and a slow Laguerre filter.
* **Signal Line:** A user-selectable smoothing of the MACD Line.
* **Histogram:** The difference between the MACD Line and the Signal Line.

## 2. Mathematical Foundations and Calculation Logic

The system is built by first creating a Laguerre-based MACD line, then applying a flexible signal line to it. The speed of the Laguerre filters is controlled by the `gamma` ($\gamma$) coefficient (a smaller gamma results in a faster filter).

### Calculation Steps (Algorithm)

1. **Calculate the Fast and Slow Laguerre Filters:** Two separate Laguerre filters are calculated on the source price `P`.
    * $\text{Fast Filter}_t = \text{LaguerreFilter}(P, \gamma_{fast})_t$
    * $\text{Slow Filter}_t = \text{LaguerreFilter}(P, \gamma_{slow})_t$

2. **Calculate the MACD Line:** The MACD Line is the difference between the two filters.
    * $\text{MACD Line}_t = \text{Fast Filter}_t - \text{Slow Filter}_t$

3. **Calculate the Signal Line:** A smoothing of the user-selected type (`MA Type`) is applied to the `MACD Line`.
    * $\text{Signal Line}_t = \text{Smoothing}(\text{MACD Line}, \text{Period}, \text{MA Type})_t$

4. **Calculate the Histogram:** The final output is the difference between the MACD Line and the Signal Line.
    * $\text{Histogram}_t = \text{MACD Line}_t - \text{Signal Line}_t$

## 3. MQL5 Implementation Details

* **Modular and Composite Design:** The `MACD_Laguerre_Calculator.mqh` uses a composition-based design: it **contains two instances** of our robust, state-managed `Laguerre_Engine` to generate the base MACD line.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal Laguerre engines persist their state (`L0`...`L3`) between ticks, allowing the recursive calculation to continue seamlessly from the last known value.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Flexible Signal Line Calculation:** The calculator dynamically instantiates either a third `Laguerre_Engine` or a `MovingAverage_Engine` for the signal line, depending on the user's choice. This ensures that the signal line calculation is also fully optimized and incremental.

* **Heikin Ashi Integration:** A "Factory Method" (`CreateEngineInstance`) is used to instantiate the correct type of Laguerre engine (`standard` or `_HA`), ensuring seamless Heikin Ashi integration.

## 4. Parameters

* **Laguerre MACD Settings:**
  * **`InpGamma1` / `InpGamma2`:** The gamma coefficients for the two base Laguerre filters. The smaller value will be the fast filter, the larger will be the slow one.
* **Signal Line Settings:**
  * **`InpSignalMAType`:** A dropdown menu to select the smoothing type for the signal line. Options include `Laguerre`, `SMA`, `EMA`, `SMMA`, `LWMA`.
  * **`InpSignalPeriod`:** The lookback period for standard MA signal lines.
  * **`InpSignalGamma`:** The gamma coefficient used **only** if the signal line type is set to `Laguerre`.
* **Price Source:**
  * **`InpSourcePrice`:** The source price for the calculation (Standard or Heikin Ashi).

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
