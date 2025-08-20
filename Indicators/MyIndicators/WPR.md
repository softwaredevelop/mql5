# Williams' Percent Range (%R)

## 1. Summary (Introduction)

Williams' Percent Range, or %R, is a momentum oscillator developed by Larry Williams. It is very similar to the Stochastic Oscillator, but it is plotted on an inverted scale from 0 to -100. Its primary purpose is to identify overbought and oversold conditions in the market.

The indicator measures the current closing price in relation to the highest high and lowest low over a specified lookback period. It shows where the current price is relative to the recent trading range, helping traders to spot potential exhaustion points in a trend.

## 2. Mathematical Foundations and Calculation Logic

The %R formula is straightforward and compares the current close to the recent high-low range.

### Required Components

- **Period (N):** The lookback period for the calculation (e.g., 14).
- **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Find the Highest High and Lowest Low:** For each bar, determine the highest high and lowest low over the last `N` periods.
   $\text{Highest High}_N = \text{Max}(\text{High}, N)_i$
   $\text{Lowest Low}_N = \text{Min}(\text{Low}, N)_i$

2. **Calculate the Williams %R:** Apply the main formula.
   $\text{\%R}_i = -100 \times \frac{\text{Highest High}_N - \text{Close}_i}{\text{Highest High}_N - \text{Lowest Low}_N}$

The result is a value between 0 and -100. A reading close to 0 means the price is closing near the top of its recent range (overbought), while a reading close to -100 means the price is closing near the bottom of its range (oversold).

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and clear representation of the Williams %R indicator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. As a non-recursive indicator, this is a simple and highly stable approach.

- **Self-Contained Logic:** The indicator is completely self-contained. It does not use any external indicator handles (like `iWPR`). All calculations are performed manually within the `OnCalculate` function using the price data provided.

- **Reusable Helper Functions:** The calculation of the highest high and lowest low is performed by our standard, reusable `Highest()` and `Lowest()` helper functions, ensuring consistency across our entire indicator toolkit.

- **Clear, Staged Calculation:** The `OnCalculate` function uses a single, efficient `for` loop to calculate the %R for each bar. The logic is clear and directly follows the mathematical definition of the indicator.

- **Heikin Ashi Variants:**
  - **`WPR_HeikinAshi.mq5`:** Our toolkit includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input. This results in a smoother oscillator that reflects the momentum of the underlying Heikin Ashi trend.
  - **`WPRMA_HeikinAshi.mq5`:** We also have a version that adds a moving average signal line to the Heikin Ashi WPR, providing an additional layer of smoothing and potential crossover signals.

## 4. Parameters

- **WPR Period (`InpWPRPeriod`):** The lookback period for the indicator. Larry Williams' original recommendation and the most common value is `14`.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of %R is to identify overbought and oversold conditions.
  - **Overbought:** Readings between **0 and -20** are considered overbought. This suggests that the price is near the top of its recent range and may be due for a pullback.
  - **Oversold:** Readings between **-80 and -100** are considered oversold. This suggests that the price is near the bottom of its recent range and may be due for a bounce.
- **Divergence:** Look for divergences between the %R and the price action. A bearish divergence (higher price highs, lower %R highs) can signal weakening bullish momentum. A bullish divergence (lower price lows, higher %R lows) can signal weakening bearish momentum.
- **Momentum Failure:** A common signal is when the %R enters the overbought zone, pulls back, and then fails to re-enter the overbought zone on a subsequent price rally. This "momentum failure" can be an early sign of a trend reversal.
- **Caution:** Like all oscillators, %R can remain in overbought or oversold territory for extended periods during a strong trend. It is not a standalone signal for buying or selling but a tool to gauge momentum within a broader market context.
