# Cutler's RSI Professional

## 1. Summary (Introduction)

Cutler's RSI is a variation of the classic Relative Strength Index (RSI). While the standard RSI uses Wilder's smoothing (an RMA/SMMA), Cutler's version uses a **Simple Moving Average (SMA)** to average the positive and negative price changes.

Our professional toolkit provides a unified implementation of this indicator family:

- **`CutlerRSI_Pro.mq5`**: Plots the main Cutler's RSI line and an **optional, configurable moving average signal line**.
- **`CutlerRSI_Oscillator_Pro.mq5`**: Displays the difference between the RSI and its signal line as a histogram.

Both indicators can be calculated using either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The core difference lies in the smoothing method applied to the price changes.

### Calculation Steps (Algorithm)

1. **Calculate Price Changes:** $\text{Change}_i = P_i - P_{i-1}$
2. **Separate Positive and Negative Changes.**
3. **Calculate the Simple Moving Average of Changes:**
    $\text{Avg Positive}_i = \text{SMA}(\text{Positive Change}, N)_i$
    $\text{Avg Negative}_i = \text{SMA}(\text{Negative Change}, N)_i$
4. **Calculate the Relative Strength (RS) and Final RSI:**
    $\text{RS}_i = \frac{\text{Avg Positive}_i}{\text{Avg Negative}_i}$
    $\text{Cutler's RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$
5. **Calculate the Signal Line & Oscillator:** The signal line is a moving average of the Cutler's RSI line, and the oscillator is the difference between the two.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a highly modular, object-oriented design.

- **Centralized Calculation Engine (`CutlerRSI_Engine.mqh`):**
    The core of our implementation is a single, powerful calculation engine that contains the complete logic for calculating both the Cutler's RSI and its signal line.

- **Specialized Wrappers (`CutlerRSI_Calculator.mqh`, `CutlerRSI_Oscillator_Calculator.mqh`):**
    The final indicators use thin "wrapper" classes that utilize the central engine to produce the desired output (line or histogram).

- **Selectable Display Mode:** The `CutlerRSI_Pro` indicator includes a `Display Mode` input that allows the user to show either the RSI line by itself or the RSI line together with its moving average signal line.

- **Efficient RSI Calculation:** The engine calculates the Cutler's RSI using an efficient **sliding window sum** technique.

- **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation for maximum stability.

## 4. Parameters

- **RSI Period (`InpPeriodRSI`):** The lookback period for the SMA of price changes. Default is `14`.
- **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
- **Signal Line Settings:**
  - `InpDisplayMode`: Toggles the visibility of the signal line.
  - `InpPeriodMA`: The lookback period for the signal line.
  - `InpMethodMA`: The type of moving average for the signal line.

## 5. Usage and Interpretation

The interpretation of Cutler's RSI is identical to the standard RSI.

- **Overbought/Oversold Levels:** Identify overbought (typically above 70) and oversold (typically below 30) conditions.
- **Crossovers:**
  - **Signal Line Crossover:** When the Cutler's RSI line crosses above its moving average, it can be seen as a bullish signal.
  - **Centerline Crossover:** A crossover of the RSI line above the 50 level indicates bullish momentum.
- **Divergence:** Look for divergences between the RSI and the price action.
- **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the Cutler's RSI and its signal line.
