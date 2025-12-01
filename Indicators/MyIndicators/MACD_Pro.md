# MACD Pro (with Selectable MA Types)

## 1. Summary (Introduction)

The MACD Pro is an enhanced version of the classic Moving Average Convergence/Divergence indicator. While the standard MACD uses Exponential Moving Averages (EMAs), this "Pro" version offers traders the flexibility to choose from four different moving average types for its calculation (SMA, EMA, SMMA, LWMA).

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
  * **Composition over Inheritance:** The calculator internally instantiates two dedicated `CMovingAverageCalculator` engines (from our universal `MovingAverage_Engine.mqh`) to handle the Fast and Slow MA calculations. This ensures that the core MA logic is consistent across our entire indicator suite.

* **Hybrid Signal Line Implementation:**
    While the Fast and Slow MAs use the universal engine, the Signal Line calculation employs a specialized, local implementation.
  * **Why?** The MACD Line (the input for the Signal Line) does not start at the beginning of the chart; it has a significant "warm-up" period determined by the Slow MA. Standard MA engines often assume data starts at index 0.
  * **Solution:** Our custom Signal Line logic correctly handles this offset, ensuring that recursive smoothing methods (like EMA and SMMA) initialize correctly at the exact point where valid MACD data becomes available. This prevents calculation errors at the start of the data series.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (`m_fast_ma`, `m_slow_ma`) persist their state between ticks. This allows recursive calculations to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data, leveraging the same optimized engine.

## 4. Parameters

* **Fast Period (`InpFastPeriod`):** The period for the shorter-term MA. Default is `12`.
* **Slow Period (`InpSlowPeriod`):** The period for the longer-term MA. Default is `26`.
* **Signal Period (`InpSignalPeriod`):** The period for the signal line's MA. Default is `9`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Source MA Type (`InpSourceMAType`):** The MA type for the Fast and Slow lines. Default is `MODE_EMA` (classic MACD).
* **Signal MA Type (`InpSignalMAType`):** The MA type for the Signal line. Default is `MODE_EMA` (classic MACD).

## 5. Usage and Interpretation

The interpretation of the MACD Pro is identical to the standard MACD, but the signals may be faster or slower depending on the selected MA types.

* **Signal Line Crossovers:** The primary signal. A crossover of the MACD Line above the Signal Line is bullish; a cross below is bearish.
* **Zero Line Crossovers:** A secondary signal confirming the overall trend direction.
* **Divergence:** A powerful signal where the indicator's momentum disagrees with the price action.
* **Histogram:** Visually represents the momentum's acceleration or deceleration.

**Effect of MA Types:**

* **EMA (Default):** The classic, balanced MACD.
* **SMA:** Using SMAs will result in a much slower, smoother MACD with significant lag.
* **LWMA:** Using LWMAs will result in a faster, more responsive MACD.
