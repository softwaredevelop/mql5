# Ultimate Oscillator (UO)

## 1. Summary (Introduction)

The Ultimate Oscillator (UO) is a momentum oscillator developed by Larry Williams in 1976. It was designed to address a common problem with other oscillators: their tendency to generate false divergence signals in strong trends or choppy markets due to using a single, fixed timeframe.

The UO overcomes this by incorporating three different timeframes (short, medium, and long) into a single, weighted oscillator value. This multi-timeframe approach provides a smoother and more reliable measure of momentum, making its divergence signals less prone to failure.

## 2. Mathematical Foundations and Calculation Logic

The UO's calculation is a multi-step process that combines buying pressure over three distinct periods.

### Required Components

- **Three Periods (N1, N2, N3):** The three lookback periods, typically short (7), medium (14), and long (28).
- **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Buying Pressure (BP):** For each bar, determine the amount of "buying pressure."

   - First, find the **True Low (TL)**: $\text{TL}_i = \text{Min}(\text{Low}_i, \text{Close}_{i-1})$
   - Then, calculate Buying Pressure: $\text{BP}_i = \text{Close}_i - \text{TL}_i$

2. **Calculate True Range (TR):** For each bar, calculate the True Range.

   - $\text{TR}_i = \text{Max}(\text{High}_i, \text{Close}_{i-1}) - \text{TL}_i$

3. **Sum BP and TR over Three Periods:** Calculate the sum of Buying Pressure and the sum of True Range over each of the three lookback periods (e.g., 7, 14, and 28).

   - $\text{Sum BP}_7 = \sum_{k=i-6}^{i} \text{BP}_k$ and $\text{Sum TR}_7 = \sum_{k=i-6}^{i} \text{TR}_k$
   - _(Repeat for periods 14 and 28)_

4. **Calculate Three Averages:** For each period, divide the sum of BP by the sum of TR.

   - $\text{Avg}_7 = \frac{\text{Sum BP}_7}{\text{Sum TR}_7}$
   - _(Repeat for periods 14 and 28)_

5. **Calculate the Final UO:** Combine the three averages using a weighted formula and scale the result to 100. The standard weights are 4 for the short-term average, 2 for the medium-term, and 1 for the long-term.
   $\text{UO}_i = 100 \times \frac{(4 \times \text{Avg}_7) + (2 \times \text{Avg}_{14}) + (1 \times \text{Avg}_{28})}{4 + 2 + 1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and accurate representation of Larry Williams' Ultimate Oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the multi-stage calculation remains stable and accurate.

- **Correct Algorithm:** Unlike the flawed example code provided with MetaTrader, our implementation strictly follows the correct, textbook definition of the UO, ensuring its results are consistent with other professional charting platforms like TradingView.

- **Efficient Calculation:** The summation of Buying Pressure and True Range over the three lookback periods is handled by an efficient **sliding window sum** technique. We maintain running sums for each period, adding the newest value and subtracting the oldest value in each iteration. This is mathematically equivalent to summing the values in every bar but is significantly faster.

- **Heikin Ashi Variant (`Ultimate_Oscillator_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values to calculate the Buying Pressure and True Range.
  - This results in a much smoother oscillator that reflects the multi-timeframe momentum of the underlying Heikin Ashi trend, making it excellent for filtering out market noise.

## 4. Parameters

- **Period 1 (`InpPeriod1`):** The short-term lookback period. Default is `7`.
- **Period 2 (`InpPeriod2`):** The medium-term lookback period. Default is `14`.
- **Period 3 (`InpPeriod3`):** The long-term lookback period. Default is `28`.

## 5. Usage and Interpretation

The Ultimate Oscillator is primarily used to identify divergences, which are its most reliable signals.

- **Bullish Divergence (Primary Buy Signal):** This is the classic signal.
  1. The price makes a **lower low**, but the UO makes a **higher low**.
  2. The low of the UO during the divergence should be **below 30**.
  3. A buy signal is triggered when the UO subsequently breaks **above the high** it made during the divergence.
- **Bearish Divergence (Primary Sell Signal):**
  1. The price makes a **higher high**, but the UO makes a **lower high**.
  2. The high of the UO during the divergence should be **above 70**.
  3. A sell signal is triggered when the UO subsequently breaks **below the low** it made during the divergence.
- **Overbought/Oversold:** While not its primary function, readings above 70 can be considered overbought and readings below 30 can be considered oversold.
- **Caution:** Larry Williams specifically designed the indicator so that its divergence signals would be the most reliable. Simple overbought/oversold readings or centerline crossovers are generally not recommended as primary signals for the UO.
