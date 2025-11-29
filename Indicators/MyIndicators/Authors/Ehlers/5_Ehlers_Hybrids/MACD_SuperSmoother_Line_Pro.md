# MACD SuperSmoother Line Pro

## 1. Summary (Introduction)

The `MACD_SuperSmoother_Line_Pro` is a modern variant of the classic MACD that replaces traditional Exponential Moving Averages (EMAs) with John Ehlers' highly responsive, low-lag SuperSmoother filters. The result is an oscillator that tracks momentum changes with significantly less delay than its conventional counterpart.

This specific indicator is a **"Line Only"** version, designed as a foundational component for analysis and experimentation. It calculates and displays only the core MACD Line (the difference between the fast and slow SuperSmoother filters).

Its primary purpose is to serve as a clean base for visually testing different types of signal lines. It is intended to be used in conjunction with the platform's built-in "Moving Average" indicator, allowing for flexible experimentation.

## 2. Mathematical Foundations and Calculation Logic

The concept is to create a momentum oscillator from the difference between a fast-reacting and a slow-reacting SuperSmoother filter.

### Required Components

* **Fast Period (N):** The period for the fast SuperSmoother filter.
* **Slow Period (M):** The period for the slow SuperSmoother filter.
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Fast SuperSmoother Filter:** A SuperSmoother filter is calculated on the source price `P` using the fast period `N`.
    * $\text{Fast Smoother}_t = \text{SuperSmoother}(P, N)_t$

2. **Calculate the Slow SuperSmoother Filter:** A second SuperSmoother filter is calculated on the same source price `P` using the slow period `M`.
    * $\text{Slow Smoother}_t = \text{SuperSmoother}(P, M)_t$

3. **Calculate the MACD Line:** The final MACD Line is the difference between the two filters.
    * $\text{MACD Line}_t = \text{Fast Smoother}_t - \text{Slow Smoother}_t$

## 3. MQL5 Implementation Details

* **Modular Engine (`Ehlers_Smoother_Calculator.mqh`):** The indicator leverages our existing, robust, and state-managed `Ehlers_Smoother_Calculator.mqh` for all core filter calculations.

* **Object-Oriented Design (Composition):** The `CMACDSuperSmootherLineCalculator` class does not re-implement the filter logic. Instead, it **contains two instances** of the `CEhlersSmootherCalculator` class—one for the fast filter and one for the slow one. This is a clean and highly reusable application of the composition design pattern.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal SuperSmoother engines persist their state (`f1`, `f2`) between ticks, allowing the recursive calculation to continue seamlessly from the last known value.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Factory Method for HA:** A `CreateSmootherInstance` virtual method is used to instantiate the correct type of smoother (`standard` or `_HA`), allowing the Heikin Ashi logic to be cleanly integrated without duplicating the main calculation chain.

## 4. Parameters

* **Fast Period (`InpFastPeriod`):** The period for the fast SuperSmoother filter. Default is `12`.
* **Slow Period (`InpSlowPeriod`):** The period for the slow SuperSmoother filter. Default is `26`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

This indicator can be used both as a standalone momentum line and as the base for building a full MACD system for testing.

### As a Standalone Oscillator

* **Zero Line Crossover:** When the MACD Line crosses above the zero line, it indicates that the fast smoother is now above the slow smoother, signaling a shift to bullish momentum. A cross below zero signals a shift to bearish momentum.
* **Slope and Peaks/Troughs:** The steepness of the line indicates the strength of the momentum.

### Building a Full MACD System for Testing (Recommended Use)

The primary purpose of this indicator is to serve as a clean base for visually testing different types of signal lines using the platform's built-in tools.

**How to add a Signal Line for experimentation:**

1. Add the `MACD_SuperSmoother_Line_Pro` indicator to a chart window.
2. Open the "Navigator" window (Ctrl+N).
3. Find the built-in "Moving Average" indicator under the "Indicators" -> "Trend" section.
4. **Drag and drop** the "Moving Average" indicator directly **onto the `MACD_SuperSmoother_Line_Pro` indicator's window**.
5. The Moving Average properties window will appear. Go to the "Parameters" tab.
6. In the **"Apply to:"** dropdown menu, select **"Previous Indicator's Data"**.
7. Now, you can freely experiment with the `Period`, `MA method` (SMA, EMA, etc.), and `Shift` settings to find the best-fitting signal line for your strategy. The moving average will be calculated on the MACD Line and displayed in the same window.
