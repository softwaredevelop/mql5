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
  * **`CMACDCalculator`**: The base class that performs the full, multi-stage MACD calculation on a given source price.
  * **`CMACDCalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency, all moving average types (**SMA, EMA, SMMA, LWMA**) are implemented **manually** within the calculator engine.

* **TradingView-Style Visualization:** Our implementation plots all three standard components: the MACD Line, the Signal Line, and the true Histogram (the difference between the two lines).

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
