# Fast Stochastic Oscillator

## 1. Summary (Introduction)

The Stochastic Oscillator, developed by George C. Lane in the late 1950s, is a momentum indicator that compares a particular closing price of a security to a range of its prices over a certain period of time. The "Fast" version is the original, unsmoothed calculation of the oscillator.

It is designed to identify overbought and oversold conditions by measuring the speed and momentum of price changes. Due to its high sensitivity, it reacts very quickly to price movements, making it a tool for traders who need to identify short-term momentum shifts.

## 2. Mathematical Foundations and Calculation Logic

The Fast Stochastic is the foundational calculation from which the "Slow" and "Full" versions are derived.

### Required Components

- **%K Period:** The main lookback period for the Stochastic calculation.
- **%D Period:** The period for the smoothing of the %K line to create the signal line.

### Calculation Steps (Algorithm)

1. **Calculate the Fast %K (Main Line):** This is the core of the Stochastic calculation. It measures where the current close is relative to the highest high and lowest low over the `%K Period`. This raw calculation produces the main line of the Fast Stochastic.
   $\text{Fast \%K}_i = \frac{\text{Close}_i - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}} \times 100$
   Where:

   - $\text{Lowest Low}$ is the minimum low price over the `%K Period`.
   - $\text{Highest High}$ is the maximum high price over the `%K Period`.

2. **Calculate the %D (Signal Line):** The signal line is a moving average (typically a Simple Moving Average) of the Fast %K line.
   $\text{\%D}_i = \text{SMA}(\text{Fast \%K}, \text{\%D Period})_i$

_Note: In the "Slow" Stochastic, the Fast %K line is smoothed an additional time before the %D line is calculated. In the "Fast" Stochastic, this intermediate smoothing step is omitted._

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed for stability, clarity, and consistency with our existing indicator toolkit.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the two-stage calculation (Price -> %K -> %D) remains stable and accurate, especially during timeframe changes or history loading.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the logic easy to follow:

  1. **Step 1:** The Fast %K line is calculated from the standard `high`, `low`, and `close` price arrays and stored in the `BufferK` plot buffer.
  2. **Step 2:** The %D signal line is calculated by applying a simple moving average with the `%D Period` to the `BufferK`. The result is stored in the `BufferD` plot buffer.

- **Heikin Ashi Variant (`StochasticFast_HeikinAshi.mqmq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input instead of the standard price data.
  - This results in a smoother oscillator, as the input data itself is already filtered, effectively creating a hybrid between the Fast and Slow Stochastics.

## 4. Parameters

- **%K Period (`InpKPeriod`):** The lookback period for the Stochastic calculation (finding the highest high and lowest low). Default is `14`.
- **%D Period (`InpDPeriod`):** The smoothing period for the signal line (%D). Default is `3`.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of the Stochastic is to identify overbought (typically above 80) and oversold (typically below 20) conditions. The Fast version will enter and exit these zones very rapidly.
- **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. A crossover of %K above %D is considered bullish, especially in oversold territory. A crossover of %K below %D is considered bearish, especially in overbought territory.
- **Divergence:** Look for divergences between the Stochastic and the price action. If the price is making a new high but the Stochastic is failing to do so (bearish divergence), it could signal weakening momentum and a potential reversal.
- **Caution:** The Fast Stochastic is highly sensitive and can produce many false signals ("whipsaws"), especially in choppy markets. It is often used by short-term traders or as a fast-reacting component in a larger trading system. For most applications, the "Slow" Stochastic is preferred due to its superior filtering of market noise.
