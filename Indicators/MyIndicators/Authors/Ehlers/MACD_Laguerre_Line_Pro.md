# MACD Laguerre Line Professional

## 1. Summary (Introduction)

The `MACD_Laguerre_Line_Pro` is a modern variant of the classic MACD that replaces traditional Exponential Moving Averages (EMAs) with John Ehlers' extremely responsive, low-lag Laguerre filters. The result is an oscillator that tracks momentum changes with significantly less delay than its conventional counterpart, producing a much smoother, more cyclical output.

This specific indicator is a **"Line Only"** version, designed as a foundational component. It calculates and displays only the core MACD Line (the difference between the fast and slow Laguerre filters).

Its primary purpose is to serve as a clean base for building a complete, customized MACD system visually. It is intended to be used in conjunction with our modular helper indicators, such as `Signal_Line_Pro` or `MACD_Laguerre_Histogram_Pro`, allowing for flexible experimentation with different types of signal lines.

## 2. Mathematical Foundations and Calculation Logic

The concept is to create a momentum oscillator from the difference between a fast-reacting and a slow-reacting Laguerre filter.

### Required Components

* **Fast Gamma ($\gamma_{fast}$):** The coefficient for the fast Laguerre filter. A **smaller** gamma value (closer to 0) results in a faster, more responsive filter.
* **Slow Gamma ($\gamma_{slow}$):** The coefficient for the slow Laguerre filter. A **larger** gamma value (closer to 1) results in a slower, smoother filter.
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Fast Laguerre Filter:** A Laguerre filter is calculated on the source price `P` using the fast gamma, $\gamma_{fast}$.
    * $\text{Fast Filter}_t = \text{LaguerreFilter}(P, \gamma_{fast})_t$

2. **Calculate the Slow Laguerre Filter:** A second Laguerre filter is calculated on the same source price `P` using the slow gamma, $\gamma_{slow}$.
    * $\text{Slow Filter}_t = \text{LaguerreFilter}(P, \gamma_{slow})_t$

3. **Calculate the MACD Line:** The final MACD Line is the difference between the two filters.
    * $\text{MACD Line}_t = \text{Fast Filter}_t - \text{Slow Filter}_t$

## 3. MQL5 Implementation Details

* **Modular Engine (`Laguerre_Engine.mqh`):** The indicator leverages our existing, robust `Laguerre_Engine.mqh` for all core filter calculations.

* **Object-Oriented Design (Composition):** The `CMACDLaguerreLineCalculator` class does not re-implement the filter logic. Instead, it **contains two instances** of the `CLaguerreEngine` class—one for the fast filter and one for the slow one. This is a clean and highly reusable application of the composition design pattern.

* **Robust Initialization:** The `Init` method is "foolproof." It automatically identifies which of the two user-provided gamma values is smaller (fast) and which is larger (slow) using `MathMin` and `MathMax`, ensuring the indicator always works correctly regardless of the input order.

* **Heikin Ashi Integration:** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **Gamma 1 (`InpGamma1`):** The gamma coefficient for one of the Laguerre filters. A good starting value for the fast filter is `0.2`.
* **Gamma 2 (`InpGamma2`):** The gamma coefficient for the other Laguerre filter. A good starting value for the slow filter is `0.8`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

This indicator can be used both as a standalone momentum line and as the base for a full MACD system.

### As a Standalone Oscillator

* **Zero Line Crossover:** When the MACD Line crosses above the zero line, it indicates that the fast filter is now above the slow filter, signaling a shift to bullish momentum. A cross below zero signals a shift to bearish momentum.
* **Slope and Peaks/Troughs:** The steepness of the line indicates the strength of the momentum. Extreme peaks and troughs can signal potential momentum exhaustion.

### Building a Full MACD System (Recommended Use)

The primary purpose of this indicator is to be combined with a signal line.

**How to add a Signal Line:**

1. Add the `MACD_Laguerre_Line_Pro` indicator to a chart window.
2. Drag our `Signal_Line_Pro` indicator **onto the same indicator window**.
3. In the `Signal_Line_Pro` settings, go to the **"Source Indicator Settings"** group.
4. **Crucially, ensure that the `InpSourceGamma1` and `InpSourceGamma2` values exactly match the gamma values you set for the `MACD_Laguerre_Line_Pro` indicator.**
5. Now, you can freely experiment with the **"Signal Line Settings"** (`InpSignalPeriod`, `InpSignalMAType`) to find the best-fitting signal line for your strategy.

By combining these two modular indicators, you can visually test and create a fully customized Laguerre MACD system.
