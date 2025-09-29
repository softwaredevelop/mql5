# Commodity Channel Index (CCI) Professional

## 1. Summary (Introduction)

The Commodity Channel Index (CCI) is a versatile momentum oscillator developed by Donald Lambert. Despite its name, it is used effectively in any market, including stocks, forex, and futures.

The CCI measures the current price level relative to an average price level over a specified period. It is designed to identify cyclical turns but is widely used to detect overbought and oversold conditions.

Our professional toolkit provides a unified implementation of this indicator family:

* **`CCI_Pro.mq5`**: Plots the main CCI line and a configurable moving average signal line.
* **`CCI_Oscillator_Pro.mq5`**: Displays the difference between the CCI and its signal line as a histogram, providing a clearer visual of momentum.

Both indicators can be calculated using either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The CCI is based on the relationship between the price, its moving average, and the average deviation from that moving average.

### Required Components

* **Period (N):** The lookback period for all calculations (e.g., 20).
* **Source Price (P):** The price series used for the calculation. The classic definition uses the **Typical Price** `(High + Low + Close) / 3`.
* **Constant:** A statistical constant of `0.015` used to scale the result.

### Calculation Steps (Algorithm)

1. **Calculate the Source Price:** For each bar, calculate the source price (e.g., Typical Price).
    $\text{P}_i = \frac{\text{High}_i + \text{Low}_i + \text{Close}_i}{3}$

2. **Calculate the Simple Moving Average (SMA):** Compute an `N`-period SMA of the source price.
    $\text{SMA}_i = \text{SMA}(P, N)_i$

3. **Calculate the Mean Absolute Deviation (MAD):** For each bar, calculate the average absolute difference between the source price and its SMA over the `N` period.
    $\text{MAD}_i = \frac{1}{N} \sum_{k=i-N+1}^{i} \text{Abs}(P_k - \text{SMA}_i)$

4. **Calculate the CCI Value:** Apply the final formula.
    $\text{CCI}_i = \frac{P_i - \text{SMA}_i}{0.015 \times \text{MAD}_i}$

5. **Calculate the Signal Line & Oscillator:** The signal line is a moving average of the CCI line, and the oscillator is the difference between the two.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a highly modular, object-oriented design to ensure accuracy, reusability, and maintainability across the entire indicator family.

* **Centralized Calculation Engine (`CCI_Engine.mqh`):**
    The core of our implementation is a single, powerful calculation engine. This include file contains the complete, mathematically precise logic for calculating both the CCI and its signal line. It supports both standard and Heikin Ashi data sources through class inheritance (`CCCI_Engine` and `CCCI_Engine_HA`). This approach eliminates code duplication entirely.

* **Specialized Wrappers (`CCI_Calculator.mqh`, `CCI_Oscillator_Calculator.mqh`):**
    The final indicators use thin "wrapper" classes that utilize the central engine.
  * `CCI_Calculator` calls the engine and directly outputs the CCI and signal lines.
  * `CCI_Oscillator_Calculator` calls the same engine, receives the CCI and signal lines, and then performs one additional step: calculating the difference to produce the histogram.

* **Mathematically Precise Implementation:** Our engine adheres strictly to the mathematical definition of CCI. It uses a nested loop structure to calculate the Mean Absolute Deviation (MAD) precisely for each bar, ensuring maximum accuracy rather than relying on a faster but less accurate sliding-window approximation.

* **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation within `OnCalculate` to ensure maximum stability and prevent calculation errors.

## 4. Parameters

* **CCI Period (`InpCCIPeriod`):** The lookback period for the SMA and MAD calculations. Common values are 14 or 20.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard price types (e.g., `PRICE_TYPICAL_STD`) and all Heikin Ashi price types (e.g., `PRICE_HA_TYPICAL`). The classic default is `PRICE_TYPICAL`.
* **Signal Line Settings:**
  * `InpMAPeriod`: The lookback period for the signal line.
  * `InpMAMethod`: The type of moving average for the signal line.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use of the CCI is to identify extreme conditions.
  * **Overbought:** Readings above **+100**.
  * **Oversold:** Readings below **-100**.
* **Zero Line Crossovers:** A crossover of the CCI line above the zero line is a bullish signal; a crossover below zero is a bearish signal.
* **Divergence:** A powerful signal where price and the CCI move in opposite directions, often foreshadowing a reversal.
* **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the CCI and its signal line, highlighting the acceleration and deceleration of momentum.
