# Cutler's RSI

## 1. Summary (Introduction)

Cutler's RSI is a variation of the classic Relative Strength Index (RSI) developed by J. Welles Wilder. While the standard RSI uses Wilder's own smoothing method (a type of Smoothed/Running Moving Average), Cutler's version simplifies the formula by using a **Simple Moving Average (SMA)** to average the positive and negative price changes.

This modification results in an oscillator that can react slightly differently to price movements compared to the standard RSI. It is still a momentum oscillator used to identify overbought and oversold conditions, but its SMA-based calculation gives it a unique character.

The **Cutler's RSI Oscillator** is a supplementary indicator that displays the difference between the main RSI line and its signal line as a histogram, providing a clearer visual of accelerating and decelerating momentum.

## 2. Mathematical Foundations and Calculation Logic

The core difference between Cutler's RSI and the standard RSI lies in the smoothing method applied to the price changes.

### Required Components

- **RSI Period (N):** The lookback period for the calculation.
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate Price Changes:** For each period, determine the change in price from the previous period.
   $\text{Change}_i = P_i - P_{i-1}$

2. **Separate Positive and Negative Changes:**

   - If $\text{Change}_i > 0$, then $\text{Positive Change}_i = \text{Change}_i$ and $\text{Negative Change}_i = 0$.
   - If $\text{Change}_i < 0$, then $\text{Positive Change}_i = 0$ and $\text{Negative Change}_i = \text{Abs}(\text{Change}_i)$.

3. **Calculate the Simple Moving Average of Changes:** This is the defining step. Apply an SMA with period `N` to both the positive and negative change series.
   $\text{Avg Positive}_i = \text{SMA}(\text{Positive Change}, N)_i$
   $\text{Avg Negative}_i = \text{SMA}(\text{Negative Change}, N)_i$

4. **Calculate the Relative Strength (RS) and Final RSI:**
   $\text{RS}_i = \frac{\text{Avg Positive}_i}{\text{Avg Negative}_i}$
   $\text{Cutler's RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$

5. **Calculate the Signal Line & Oscillator:** The signal line is a moving average of the Cutler's RSI line, and the oscillator is the difference between the two.

## 3. MQL5 Implementation Details

Our MQL5 implementations were refactored for maximum stability, clarity, and computational efficiency.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Efficient RSI Calculation:** Instead of using multiple loops or inefficient `SimpleMA` calls on every bar, we calculate the Cutler's RSI in a single `for` loop using an efficient **sliding window sum** technique. This is mathematically equivalent to an SMA but significantly faster.

- **Self-Contained Logic:** The indicators are completely self-contained. They do not use external handles and directly process the price arrays provided by `OnCalculate`.

- **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency, all moving average calculations for the signal line (**SMA, EMA, SMMA, LWMA**) are performed **manually**. This makes the indicators independent of the `<MovingAverages.mqh>` library and ensures robust behavior on `non-timeseries` arrays.

- **Indicator Family:**
  - **Line Versions:** `CutlerRSI_MA.mq5` plots the RSI line and its signal line.
  - **Oscillator Versions:** `CutlerRSI_Oscillator.mq5` plots the difference between the two lines as a histogram.
  - **Heikin Ashi Variants:** Both indicators have "pure" Heikin Ashi counterparts, which use the smoothed Heikin Ashi `ha_close` values as their input.

## 4. Parameters

- **RSI Period (`InpPeriodRSI`):** The lookback period for the SMA of price changes. Default is `14`.
- **Applied Price (`InpAppliedPrice`):** The source price for the calculation. Default is `PRICE_CLOSE`.
- **Signal Line Settings:**
  - `InpPeriodMA`: The lookback period for the optional signal line.
  - `InpMethodMA`: The type of moving average for the signal line.

## 5. Usage and Interpretation

The interpretation of Cutler's RSI is identical to the standard RSI.

- **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 70) and oversold (typically below 30) conditions.
- **Crossovers:**
  - **Signal Line Crossover:** When the Cutler's RSI line crosses above its moving average, it can be seen as a bullish signal. A cross below is a bearish signal.
  - **Centerline Crossover:** A crossover of the RSI line above the 50 level indicates that momentum is shifting to bullish. A crossover below 50 indicates bearish momentum.
- **Divergence:** Look for divergences between the RSI and the price action.
- **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the Cutler's RSI and its signal line, highlighting the acceleration and deceleration of momentum.
