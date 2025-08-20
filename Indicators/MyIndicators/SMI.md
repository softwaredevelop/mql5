# Stochastic Momentum Index (SMI)

## 1. Summary (Introduction)

The Stochastic Momentum Index (SMI) was developed by William Blau. Unlike the standard Stochastic Oscillator which measures the relationship between the closing price and its high-low range, the SMI measures the relationship between the closing price and the _midpoint_ of that range.

The result is a smoother oscillator that fluctuates around a zero line, providing clearer signals and minimizing the erratic behavior often seen in the standard Stochastic. It is designed to be a more reliable indicator of momentum, less prone to false signals from minor price volatility.

## 2. Mathematical Foundations and Calculation Logic

The SMI is a complex indicator involving multiple layers of smoothing, typically using Exponential Moving Averages (EMAs).

### Required Components

- **%K Period:** The lookback period for finding the highest high and lowest low.
- **%D Period:** The period for the double EMA smoothing.
- **Signal Period:** The period for the final EMA smoothing that creates the signal line.

### Calculation Steps (Algorithm)

1. **Find the Price Range:** For each bar, determine the highest high and lowest low over the `%K Period`.
   $\text{Highest High}_i = \text{Max}(\text{High}, \text{\%K Period})_i$
   $\text{Lowest Low}_i = \text{Min}(\text{Low}, \text{\%K Period})_i$

2. **Calculate the Relative Distance:** Determine the distance of the current close from the midpoint of the high-low range.
   $\text{Range}_i = \text{Highest High}_i - \text{Lowest Low}_i$
   $\text{Relative Distance}_i = \text{Close}_i - \frac{\text{Highest High}_i + \text{Lowest Low}_i}{2}$

3. **First EMA Smoothing:** Apply an EMA with the `%D Period` to both the `Relative Distance` and the `Range`.
   $\text{EMA(Relative)}_i = \text{EMA}(\text{Relative Distance}, \text{\%D Period})_i$
   $\text{EMA(Range)}_i = \text{EMA}(\text{Range}, \text{\%D Period})_i$

4. **Second EMA Smoothing:** Apply another EMA with the `%D Period` to the results of the first smoothing. This double-smoothing is a key feature of the SMI.
   $\text{EMA2(Relative)}_i = \text{EMA}(\text{EMA(Relative)}, \text{\%D Period})_i$
   $\text{EMA2(Range)}_i = \text{EMA}(\text{EMA(Range)}, \text{\%D Period})_i$

5. **Calculate the SMI Value:** The final SMI is calculated as a percentage. The division by `Range / 2` scales the result to oscillate primarily between +100 and -100.
   $\text{SMI}_i = 100 \times \frac{\text{EMA2(Relative)}_i}{\text{EMA2(Range)}_i / 2}$

6. **Calculate the Signal Line:** The signal line is an EMA of the SMI line itself, using the `Signal Period`.
   $\text{Signal}_i = \text{EMA}(\text{SMI}, \text{Signal Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be highly robust, clear, and efficient, especially considering the multiple layers of recursive EMA calculations.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a complex, multi-stage indicator like the SMI, this is the most reliable method to prevent calculation errors and ensure stability.

- **Robust EMA Initialization:** Each recursive EMA calculation step is carefully initialized to prevent floating-point overflows. For the second EMA pass and the final signal line, the first value is calculated using a **manual Simple Moving Average (SMA)** on the preceding data. This provides a stable starting point for the subsequent recursive calculations.

- **Optimized Calculation Flow:** The `OnCalculate` function is structured into clear, sequential steps. After an initial loop to calculate the raw price ranges, a single, efficient `for` loop handles all subsequent smoothing and final calculations. This integrated approach is more efficient than using multiple separate loops that would iterate over the entire dataset repeatedly.

- **Heikin Ashi Variant (`SMI_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input.
  - This results in an even smoother oscillator, as the input data itself is already filtered. This version is ideal for traders who want to focus on the most significant momentum shifts and filter out market noise.

## 4. Parameters

- **%K Length (`InpLengthK`):** The lookback period for finding the highest high and lowest low. Default is `10`.
- **%D Length (`InpLengthD`):** The period used for the double EMA smoothing of the price ranges. Default is `3`.
- **EMA Length (`InpLengthEMA`):** The smoothing period for the final signal line. Default is `3`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation (e.g., `PRICE_CLOSE`).

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The SMI typically uses +40 as the overbought level and -40 as the oversold level. A move above +40 suggests strong bullish momentum that may be nearing exhaustion, while a move below -40 suggests strong bearish momentum.
- **Crossovers:**
  - **SMI / Signal Line Crossover:** When the SMI line (blue) crosses above its signal line (orange), it can be considered a bullish signal. When it crosses below, it's a bearish signal.
  - **Zero Line Crossover:** A crossover of the SMI line above the zero line indicates that bullish momentum is taking control. A crossover below zero indicates bearish momentum is dominant.
- **Divergence:** Look for divergences between the SMI and the price. A bearish divergence (higher price highs, lower SMI highs) can signal a potential top, while a bullish divergence (lower price lows, higher SMI lows) can signal a potential bottom.
- **Caution:** While smoother than a standard Stochastic, the SMI is still a momentum oscillator and can give false signals in choppy markets. It is best used for confirmation with other forms of analysis.
