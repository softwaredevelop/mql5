# Cutler's RSI Professional

## 1. Summary (Introduction)

Cutler's RSI is a variation of the classic Relative Strength Index (RSI). While the standard RSI (developed by J. Welles Wilder) uses Wilder's own smoothing method (an RMA/SMMA), Cutler's version simplifies the formula by using a **Simple Moving Average (SMA)** to average the positive and negative price changes. This results in an oscillator with a unique character.

Our professional toolkit provides a unified implementation of this indicator family:

* **`CutlerRSI_Pro.mq5`**: Plots the main Cutler's RSI line and a configurable moving average signal line.
* **`CutlerRSI_Oscillator_Pro.mq5`**: Displays the difference between the RSI and its signal line as a histogram for a clearer view of momentum.

Both indicators can be calculated using either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The core difference between Cutler's RSI and the standard RSI lies in the smoothing method applied to the price changes.

### Required Components

* **RSI Period (N):** The lookback period for the calculation.
* **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate Price Changes:** For each period, determine the change in price from the previous period.
    $\text{Change}_i = P_i - P_{i-1}$

2. **Separate Positive and Negative Changes:**
    * If $\text{Change}_i > 0$, then $\text{Positive Change}_i = \text{Change}_i$ and $\text{Negative Change}_i = 0$.
    * If $\text{Change}_i < 0$, then $\text{Positive Change}_i = 0$ and $\text{Negative Change}_i = \text{Abs}(\text{Change}_i)$.

3. **Calculate the Simple Moving Average of Changes:** Apply an SMA with period `N` to both the positive and negative change series.
    $\text{Avg Positive}_i = \text{SMA}(\text{Positive Change}, N)_i$
    $\text{Avg Negative}_i = \text{SMA}(\text{Negative Change}, N)_i$

4. **Calculate the Relative Strength (RS) and Final RSI:**
    $\text{RS}_i = \frac{\text{Avg Positive}_i}{\text{Avg Negative}_i}$
    $\text{Cutler's RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$

5. **Calculate the Signal Line & Oscillator:** The signal line is a moving average of the Cutler's RSI line, and the oscillator is the difference between the two.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a highly modular, object-oriented design to ensure accuracy, reusability, and maintainability across the entire indicator family.

* **Centralized Calculation Engine (`CutlerRSI_Engine.mqh`):**
    The core of our implementation is a single, powerful calculation engine. This include file contains the complete, mathematically precise logic for calculating both the Cutler's RSI and its signal line. It supports both standard and Heikin Ashi data sources through class inheritance (`CCutlerRSI_Engine` and `CCutlerRSI_Engine_HA`). This approach eliminates code duplication entirely.

* **Specialized Wrappers (`CutlerRSI_Calculator.mqh`, `CutlerRSI_Oscillator_Calculator.mqh`):**
    The final indicators use thin "wrapper" classes that utilize the central engine.
  * `CutlerRSI_Calculator` calls the engine and directly outputs the RSI and signal lines.
  * `CutlerRSI_Oscillator_Calculator` calls the same engine, receives the RSI and signal lines, and then performs one additional step: calculating the difference to produce the histogram.

* **Efficient RSI Calculation:** The engine calculates the Cutler's RSI in a single `for` loop using an efficient **sliding window sum** technique. This is mathematically equivalent to an SMA but significantly faster than recalculating the sum on every bar.

* **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation within `OnCalculate` to ensure maximum stability.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period for the SMA of price changes. Default is `14`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types. Default is `PRICE_CLOSE_STD`.
* **Signal Line Settings:**
  * `InpPeriodMA`: The lookback period for the signal line.
  * `InpMethodMA`: The type of moving average for the signal line.

## 5. Usage and Interpretation

The interpretation of Cutler's RSI is identical to the standard RSI.

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 70) and oversold (typically below 30) conditions.
* **Crossovers:**
  * **Signal Line Crossover:** When the Cutler's RSI line crosses above its moving average, it can be seen as a bullish signal. A cross below is a bearish signal.
  * **Centerline Crossover:** A crossover of the RSI line above the 50 level indicates that momentum is shifting to bullish. A crossover below 50 indicates bearish momentum.
* **Divergence:** Look for divergences between the RSI and the price action.
* **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the Cutler's RSI and its signal line, highlighting the acceleration and deceleration of momentum.
