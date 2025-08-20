# Fast Stochastic RSI (StochRSI) Indicator

## 1. Summary (Introduction)

The Stochastic RSI, or StochRSI, is a technical analysis indicator developed by Tushar Chande and Stanley Kroll. It is an "indicator of an indicator," applying the Stochastic Oscillator formula to a set of Relative Strength Index (RSI) values instead of standard price data. The primary goal of the StochRSI is to identify overbought and oversold conditions with greater sensitivity and speed than the RSI alone.

The "Fast" version of the StochRSI represents the raw, unsmoothed calculation of the Stochastic on the RSI. It is more responsive to momentum changes than its "Slow" counterpart but can also be more prone to generating false signals.

## 2. Mathematical Foundations and Calculation Logic

The Fast StochRSI calculation is a direct application of the Stochastic formula to an RSI data series.

### Required Components

- **RSI (Relative Strength Index):** The underlying data series for the calculation.
- **Stochastic %K Period:** The lookback period used to find the highest and lowest RSI values.
- **%D Period:** The period for the smoothing of the %K line to create the signal line.

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, calculate the standard RSI for a given period (e.g., 14) on the source price (e.g., Close). Let's denote this as $\text{RSI}_i$.

2. **Calculate the Fast %K:** Apply the Stochastic formula to the RSI data series. This finds where the current RSI value lies in relation to its highest and lowest values over the Stochastic period. This line is the main line of the Fast StochRSI.
   $\text{Fast \%K}_i = \frac{\text{RSI}_i - \text{Lowest Low RSI}_{\text{Stoch Period}}}{\text{Highest High RSI}_{\text{Stoch Period}} - \text{Lowest Low RSI}_{\text{Stoch Period}}} \times 100$
   Where:

   - $\text{Lowest Low RSI}$ is the minimum RSI value over the Stochastic lookback period.
   - $\text{Highest High RSI}$ is the maximum RSI value over the Stochastic lookback period.

3. **Calculate the %D (Signal Line):** The signal line is a moving average (typically a Simple Moving Average) of the Fast %K line.
   $\text{\%D}_i = \text{SMA}(\text{Fast \%K}, \text{\%D Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed for stability, clarity, and consistency with our existing indicator toolkit.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the multi-stage calculation (Price -> RSI -> %K -> %D) remains stable and accurate, especially during timeframe changes or history loading.

- **Leveraging Standard Indicators:** For the initial RSI calculation, we use a handle to MQL5's built-in `iRSI` indicator. This is a robust and efficient method for obtaining the underlying RSI data series. The handle's resources are properly managed and released in the `OnDeinit` function.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the logic easy to follow:

  1. **Step 1:** RSI data is retrieved into the `BufferRSI` calculation buffer.
  2. **Step 2:** The Fast %K line is calculated from `BufferRSI` and stored in the `BufferK` plot buffer.
  3. **Step 3:** The %D signal line is calculated by applying a simple moving average to `BufferK` and storing the result in the `BufferD` plot buffer.

- **Heikin Ashi Variant (`StochRSI_Fast_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version of this indicator. Instead of using the standard `iRSI`, it utilizes our custom `CHeikinAshi_RSI_Calculator` from the `HeikinAshi_Tools.mqh` library.
  - This ensures that the entire calculation, from the very first RSI value to the final %D line, is based on the smoothed Heikin Ashi price data, providing a consistent, filtered view of momentum.

## 4. Parameters

- **RSI Length (`InpLengthRSI`):** The lookback period for the underlying RSI calculation. Default is `14`.
- **Stochastic Length (`InpLengthStoch`):** The lookback period for finding the highest and lowest RSI values (%K calculation). Default is `14`.
- **%D Smoothing (`InpSmoothD`):** The smoothing period for the signal line (%D). Default is `3`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the initial RSI calculation (e.g., `PRICE_CLOSE`).

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of StochRSI is to identify overbought (typically above 80) and oversold (typically below 20) conditions. The Fast version will reach these levels more quickly and frequently than the Slow version or the standard RSI.
- **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals. A crossover of %K above %D can be a bullish signal, especially when occurring in oversold territory. A crossover of %K below %D can be a bearish signal, especially in overbought territory.
- **Divergence:** Look for divergences between the StochRSI and the price action. For example, if the price is making a new high but the StochRSI is failing to do so (bearish divergence), it could signal a potential trend reversal.
- **Caution:** The Fast StochRSI is extremely sensitive and can produce a significant number of false signals ("whipsaws"), especially in choppy or strongly trending markets. It is often used as a component in a larger trading system or confirmed with other, less sensitive indicators.
