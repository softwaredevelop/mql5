# Commodity Channel Index (CCI)

## 1. Summary (Introduction)

The Commodity Channel Index (CCI) is a versatile momentum oscillator developed by Donald Lambert, first introduced in "Commodities" magazine in 1980. Despite its name, it is used effectively in any market, including stocks, forex, and futures.

The CCI measures the current price level relative to an average price level over a specified period. It is designed to identify cyclical turns but is widely used to detect overbought and oversold conditions. High values indicate that the price is unusually high compared to its average, and low values indicate it is unusually low.

The **CCI Oscillator** is a supplementary indicator that displays the difference between the main CCI line and its signal line as a histogram, providing a clearer visual of accelerating and decelerating momentum.

## 2. Mathematical Foundations and Calculation Logic

The CCI is based on the relationship between the price, its moving average, and the average deviation from that moving average.

### Required Components

- **Period (N):** The lookback period for all calculations (e.g., 20).
- **Source Price (P):** The price series used for the calculation. The classic definition uses the **Typical Price** `(High + Low + Close) / 3`.
- **Constant:** A statistical constant of `0.015` used to scale the result.

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

Our MQL5 toolkit includes two distinct standard implementations of the CCI, along with their Heikin Ashi counterparts and oscillator versions, to offer a choice between performance and perfect mathematical accuracy.

- **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation within the `OnCalculate` function to ensure maximum stability.
- **Self-Contained Logic:** All versions are completely self-contained, with fully manual calculations for all components.
- **Optional Signal Line:** All line-based versions have been enhanced with an optional, user-configurable moving average signal line.

### Our Two Calculation Methodologies

1. **Efficient Version (`CCI.mq5`):**

   - **Concept:** A high-performance implementation suitable for most applications.
   - **Logic:** This version uses an efficient **sliding window sum** technique to calculate both the SMA and the Mean Absolute Deviation (MAD). This is a very close approximation of the precise formula but avoids nested loops, making it significantly faster.

2. **Precise Version (`CCI_Precise.mq5`):**
   - **Concept:** A version that adheres strictly to the mathematical definition for maximum accuracy.
   - **Logic:** This implementation uses nested `for` loops. For every single bar, it recalculates the precise SMA and then the precise MAD based on that SMA.

### Indicator Family

- **Line Versions:** `CCI.mq5` and `CCI_Precise.mq5` plot the CCI line and its signal line.
- **Oscillator Versions:** `CCI_Oscillator.mq5` and `CCI_Precise_Oscillator.mq5` plot the difference between the CCI and its signal line as a histogram.
- **Heikin Ashi Variants:** All four indicators have "pure" Heikin Ashi counterparts, which use smoothed Heikin Ashi price data as their input.

## 4. Parameters

- **CCI Period (`InpCCIPeriod`):** The lookback period for the SMA and MAD calculations. Common values are 14 or 20.
- **Applied Price (`InpAppliedPrice`):** The source price for the calculation. The classic and default is `PRICE_TYPICAL`.
- **Signal Line Settings:**
  - `InpMAPeriod`: The lookback period for the optional signal line.
  - `InpMAMethod`: The type of moving average for the signal line.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of the CCI is to identify extreme conditions.
  - **Overbought:** Readings above **+100**.
  - **Oversold:** Readings below **-100**.
- **Zero Line Crossovers:** A crossover of the CCI line above the zero line is a bullish signal; a crossover below zero is a bearish signal.
- **Divergence:** A powerful signal where price and the CCI move in opposite directions, often foreshadowing a reversal.
- **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the CCI and its signal line, highlighting the acceleration and deceleration of momentum.
