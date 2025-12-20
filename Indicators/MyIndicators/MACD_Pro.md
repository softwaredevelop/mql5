# MACD Pro (with Selectable MA Types)

## 1. Summary (Introduction)

The MACD Pro is an enhanced version of the classic Moving Average Convergence/Divergence indicator. While the standard MACD uses Exponential Moving Averages (EMAs), this "Pro" version offers traders the flexibility to choose from **seven** different moving average types for its calculation.

This customization allows traders to fine-tune the indicator's responsiveness and smoothness. Our `MACD_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The MACD Pro follows the classic MACD structure but generalizes the moving average calculation.

### Required Components

* **Fast Period, Slow Period, Signal Period:** The lookback periods for the three moving averages.
* **Source MA Type:** The type of MA to be used for the Fast and Slow lines.
* **Signal MA Type:** The type of MA to be used for the Signal Line.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Fast MA:** Compute a moving average of the source price using the fast period and the selected `Source MA Type`.
    $\text{FastMA} = \text{MA}(\text{Price}, \text{FastPeriod}, \text{SourceMAType})$

2. **Calculate the Slow MA:** Compute a moving average of the source price using the slow period and the selected `Source MA Type`.
    $\text{SlowMA} = \text{MA}(\text{Price}, \text{SlowPeriod}, \text{SourceMAType})$

3. **Calculate the MACD Line:** Subtract the Slow MA from the Fast MA.
    $\text{MACD Line} = \text{FastMA} - \text{SlowMA}$

4. **Calculate the Signal Line:** Compute a moving average of the **MACD Line** using the signal period and the selected `Signal MA Type`.
    $\text{Signal Line} = \text{MA}(\text{MACD Line}, \text{SignalPeriod}, \text{SignalMAType})$

5. **Calculate the Histogram:** Subtract the Signal Line from the MACD Line.
    $\text{Histogram} = \text{MACD Line} - \text{Signal Line}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`MACD_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **Composition Pattern:** The calculator internally instantiates **three** dedicated `CMovingAverageCalculator` engines (from our universal `MovingAverage_Engine.mqh`):
    1. **Fast Engine:** Calculates the Fast MA.
    2. **Slow Engine:** Calculates the Slow MA.
    3. **Signal Engine:** Calculates the Signal Line smoothing.
    This ensures that the core MA logic is consistent across the entire indicator and allows for advanced combinations (e.g., DEMA-based MACD with TEMA Signal).

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations (Fast/Slow MA -> MACD Line -> Signal Line), ensuring that each step starts only when valid data is available. This prevents artifacts and "INF" errors at the beginning of the chart.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data, leveraging the same optimized engine.

## 4. Parameters

* **Fast Period (`InpFastPeriod`):** The period for the shorter-term MA. (Default: `12`).
* **Slow Period (`InpSlowPeriod`):** The period for the longer-term MA. (Default: `26`).
* **Signal Period (`InpSignalPeriod`):** The period for the signal line's MA. (Default: `9`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).
* **Source MA Type (`InpSourceMAType`):** The MA type for the Fast and Slow lines. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `EMA`).
* **Signal MA Type (`InpSignalMAType`):** The MA type for the Signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `EMA`).

## 5. Usage and Interpretation

The interpretation of the MACD Pro is identical to the standard MACD, but the signals may be faster or slower depending on the selected MA types.

* **Signal Line Crossovers:** The primary signal. A crossover of the MACD Line above the Signal Line is bullish; a cross below is bearish.
* **Zero Line Crossovers:** A secondary signal confirming the overall trend direction.
* **Divergence:** A powerful signal where the indicator's momentum disagrees with the price action.
* **Histogram:** Visually represents the momentum's acceleration or deceleration.

**Effect of MA Types:**

* **EMA (Default):** The classic, balanced MACD.
* **TEMA/DEMA:** Using these will result in a much faster, more responsive MACD, ideal for scalping.
* **TMA:** Using Triangular MA will result in a very smooth, laggy MACD, useful for filtering out noise in long-term trends.
