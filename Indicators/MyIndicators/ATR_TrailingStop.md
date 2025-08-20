# ATR Trailing Stop (Chandelier Exit)

## 1. Summary (Introduction)

The ATR Trailing Stop, also widely known as the Chandelier Exit, is a volatility-based indicator developed by Charles Le Beau and featured in Alexander Elder's books. It is designed to help traders stay in a trend for as long as possible while protecting profits from significant reversals.

The indicator calculates a stop-loss level by measuring the market's recent volatility (using the Average True Range - ATR) and placing the stop a certain multiple of that volatility away from the recent price extreme. Its name, "Chandelier Exit," comes from the idea of hanging the stop-loss from the "chandelier" of the highest high (for long positions) or lowest low (for short positions) of the trend.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses the highest high or lowest low over a period as an anchor and then subtracts or adds a multiple of the ATR to create the trailing stop level.

### Required Components

- **ATR Period (N):** The lookback period for all calculations (ATR, Highest High, Lowest Low).
- **ATR Multiplier (M):** The factor by which the ATR is multiplied to determine the stop distance.
- **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Average True Range (ATR):** Compute the ATR for the period `N` using Wilder's smoothing method.

2. **Calculate the Raw Stop Levels:** For each bar, determine the two potential stop levels:

   - **Long Stop (for uptrends):** Find the highest high over the last `N` bars and subtract the ATR value multiplied by the factor `M`.
     $\text{Long Stop}_i = \text{Highest High}_{N} - (M \times \text{ATR}_i)$
   - **Short Stop (for downtrends):** Find the lowest low over the last `N` bars and add the ATR value multiplied by the factor `M`.
     $\text{Short Stop}_i = \text{Lowest Low}_{N} + (M \times \text{ATR}_i)$

3. **Determine the Trend Direction:** The trend is determined by comparing the closing price to the _previous_ bar's stop levels.

   - The trend flips to **up** if the current `Close` crosses **above** the previous bar's `Short Stop`.
   - The trend flips to **down** if the current `Close` crosses **below** the previous bar's `Long Stop`.
   - If neither condition is met, the trend continues from the previous bar.

4. **Plot the Final Trailing Stop Line:** The final plotted line incorporates the "trailing" logic, meaning it can only move in the direction of the trend (up for a long stop, down for a short stop).
   - If the trend is **up**:
     $\text{Final Stop}_i = \text{Max}(\text{Long Stop}_i, \text{Final Stop}_{i-1})$
   - If the trend is **down**:
     $\text{Final Stop}_i = \text{Min}(\text{Short Stop}_i, \text{Final Stop}_{i-1})$
   - _(Note: On a trend flip, the new stop is taken directly from the calculated `Long Stop` or `Short Stop` without comparison to the previous value.)_

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and accurate representation of the Chandelier Exit.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a state-dependent indicator like this, it is the most reliable method to ensure stability.

- **Consensus Wilder Algorithm:** The ATR calculation strictly follows our established two-step algorithm for Wilder's smoothing (manual SMA for initialization, followed by the recursive formula), ensuring consistency with our other indicators and the global standard (e.g., TradingView).

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the complex logic easy to follow:

  1. **Step 1:** The True Range is calculated.
  2. **Step 2:** The ATR is calculated from the True Range values.
  3. **Step 3:** The raw `Long Stop` and `Short Stop` levels are calculated.
  4. **Step 4:** The final loop determines the trend and applies the "trailing" logic to plot the final stop line.

- **Visual Representation:** The implementation ensures that trend changes are represented by a clean, vertical line connecting the old and new trend lines, providing continuous visual information.

- **Heikin Ashi Variant (`ATR_TrailingStop_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values for all its inputs (ATR, Highest/Lowest price, and trend-flip condition).
  - This results in a smoother trailing stop that is less susceptible to being triggered by the "noise" of standard candlesticks, making it well-suited for Heikin Ashi-based trend-following strategies.

## 4. Parameters

- **ATR Period (`InpAtrPeriod`):** The lookback period for the ATR and the Highest High / Lowest Low calculations. A longer period results in a smoother, slower-reacting stop. Default is `22`.
- **Multiplier (`InpMultiplier`):** The factor to multiply the ATR by. A larger multiplier places the stop further from the price, allowing for more room for pullbacks but resulting in a larger potential loss if the stop is hit. A smaller multiplier keeps the stop tighter. Common values range from 2.5 to 3.5. Default is `3.0`.

## 5. Usage and Interpretation

- **Trailing Stop-Loss:** The primary use of the indicator is as a dynamic, volatility-adjusted trailing stop-loss. In an uptrend, the blue line represents the suggested stop level. In a downtrend, the red line represents the suggested stop level.
- **Trend Identification:** The color and position of the line provide a clear indication of the trend. A blue line below the price indicates an uptrend; a red line above the price indicates a downtrend.
- **Exit Signal:** The primary signal is for exiting a trade. A long position would be closed when the price closes below the blue line. A short position would be closed when the price closes above the red line.
- **Caution:** The Chandelier Exit is an excellent tool for letting profits run in a strong trend. However, in sideways or choppy markets, it can lead to being stopped out prematurely. It is most effective when used to manage trades within an already identified, strong trend.
