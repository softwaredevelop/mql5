# Slow Stochastic Oscillator

## 1. Summary (Introduction)

The Stochastic Oscillator, developed by George C. Lane in the late 1950s, is a momentum indicator that compares a particular closing price of a security to a range of its prices over a certain period of time. The "Slow" version is the most commonly used variant, as it includes an internal smoothing mechanism that filters out the "noise" of the more volatile "Fast" Stochastic, providing clearer signals.

Its primary purpose is to identify overbought and oversold conditions and to spot potential trend reversals through divergences and line crossovers.

## 2. Mathematical Foundations and Calculation Logic

The Slow Stochastic is derived from the Fast Stochastic by adding an extra layer of smoothing.

### Required Components

- **%K Period:** The main lookback period for the Stochastic calculation.
- **Slowing Period:** The period for the first smoothing step, which transforms the "Fast %K" into the "Slow %K".
- **%D Period:** The period for the second smoothing step, which creates the signal line (%D) from the Slow %K.

### Calculation Steps (Algorithm)

1. **Calculate the Raw %K (Fast %K):** This is the core of the Stochastic calculation. It measures where the current close is relative to the highest high and lowest low over the `%K Period`.
   $\text{Raw \%K}_i = \frac{\text{Close}_i - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}} \times 100$
   Where:

   - $\text{Lowest Low}$ is the minimum low price over the `%K Period`.
   - $\text{Highest High}$ is the maximum high price over the `%K Period`.

2. **Calculate the Slow %K (Main Line):** This is the key step that creates the "Slow" Stochastic. The Raw %K line is smoothed, typically with a Simple Moving Average (SMA), using the `Slowing Period`. This smoothed line becomes the main `%K` line of the Slow Stochastic.
   $\text{Slow \%K}_i = \text{SMA}(\text{Raw \%K}, \text{Slowing Period})_i$

3. **Calculate the %D (Signal Line):** The signal line is a moving average of the Slow %K line, providing an additional layer of smoothing.
   $\text{Slow \%D}_i = \text{SMA}(\text{Slow \%K}, \text{\%D Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed for stability, clarity, and consistency with our existing indicator toolkit.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the multi-stage calculation (Price -> Raw %K -> Slow %K -> %D) remains stable and accurate, especially during timeframe changes or history loading.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the logic easy to follow:

  1. **Step 1:** The Raw %K (Fast %K) is calculated from the standard `high`, `low`, and `close` price arrays and stored in the `BufferRawK` calculation buffer.
  2. **Step 2:** The Slow %K (the main plot line) is calculated by applying a simple moving average with the `Slowing` period to `BufferRawK`. The result is stored in the `BufferK` plot buffer.
  3. **Step 3:** The %D signal line is calculated by applying a simple moving average with the `%D Period` to the already smoothed `BufferK`. The result is stored in the `BufferD` plot buffer.

- **Heikin Ashi Variant (`StochasticSlow_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input instead of the standard price data.
  - This results in a significantly smoother oscillator, as the input data itself is already filtered. This can be useful for traders who want to focus on the primary momentum shifts and filter out market noise.

## 4. Parameters

- **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation (finding the highest high and lowest low). Default is `5`.
- **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). Default is `3`.
- **Slowing (`InpSlowing`):** The smoothing period applied to the Raw %K to create the main Slow %K line. A value of `1` would effectively result in a Fast Stochastic. Default is `3`.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of the Stochastic is to identify overbought (typically above 80) and oversold (typically below 20) conditions. A move into these zones does not necessarily mean a reversal is imminent, but it indicates that the price is near the top or bottom of its recent trading range.
- **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. A crossover of %K above %D is considered bullish, especially in oversold territory. A crossover of %K below %D is considered bearish, especially in overbought territory.
- **Divergence:** Look for divergences between the Stochastic and the price action. If the price is making a new high but the Stochastic is failing to do so (bearish divergence), it could signal weakening momentum and a potential reversal. Conversely, if the price makes a new low but the Stochastic makes a higher low (bullish divergence), it could signal a potential bottom.
- **Caution:** The Stochastic is a range-bound oscillator and performs best in sideways or choppy markets. In a strong trend, it can remain in overbought or oversold territory for extended periods, giving premature or false reversal signals.
