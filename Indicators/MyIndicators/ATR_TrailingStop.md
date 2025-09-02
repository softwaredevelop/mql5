# ATR Trailing Stop (Chandelier Exit)

## 1. Summary (Introduction)

The ATR Trailing Stop, also widely known as the Chandelier Exit, is a volatility-based indicator developed by Charles Le Beau and featured in Alexander Elder's books. It is designed to help traders stay in a trend for as long as possible while protecting profits from significant reversals.

The indicator calculates a stop-loss level by measuring the market's recent volatility (using the Average True Range - ATR) and placing the stop a certain multiple of that volatility away from the recent price extreme. Its name, "Chandelier Exit," comes from the idea of hanging the stop-loss from the "chandelier" of the highest high (for long positions) or lowest low (for short positions) of the trend.

**This implementation is fully Multi-Timeframe (MTF) capable, allowing it to display a stable, higher-timeframe stop level on any lower-timeframe chart, providing a structural, volatility-based map for trade management.**

## 2. Mathematical Foundations and Calculation Logic

The indicator uses the highest high or lowest low over a period as an anchor and then subtracts or adds a multiple of the ATR to create the trailing stop level.

### Required Components

- **ATR Period (N):** The lookback period for all calculations (ATR, Highest High, Lowest Low).
- **ATR Multiplier (M):** The factor by which the ATR is multiplied to determine the stop distance.
- **Price Data:** The `High`, `Low`, and `Close` of each bar **from the selected timeframe**.

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

Our MQL5 implementation is a self-contained, robust, and accurate representation of the Chandelier Exit, built with a modern, object-oriented, and multi-timeframe architecture.

- **Self-Contained Object-Oriented Design:** The entire calculation logic is encapsulated within a dedicated `CATR_TrailingStop_Calculator` class. This class is responsible for all aspects of the calculation, from data retrieval to the final stop value computation, completely separating the complex algorithm from the indicator's main `OnCalculate` event handler.

- **Robust MTF Implementation:** The indicator is designed from the ground up for stable Multi-Timeframe functionality.

  - The `CATR_TrailingStop_Calculator` class uses the standard `CopyHigh()`, `CopyLow()`, and `CopyClose()` functions to fetch a complete history from the user-specified `InpUpperTimeframe`.
  - The `OnCalculate` function intelligently detects when a **new bar has formed on the higher timeframe**. A full, resource-intensive recalculation of the entire stop line history is performed **only** at this moment.
  - The calculated higher-timeframe values are then "mapped" onto the current chart's timeline, creating the characteristic "stepped" appearance of an MTF indicator. This ensures maximum performance and stability.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation of the entire history on every new higher-timeframe bar. For a state-dependent, recursive indicator like this, it is the most reliable method to ensure perfect accuracy and eliminate the risk of calculation errors or visual glitches.

- **Consensus Wilder Algorithm:** The ATR calculation strictly follows our established two-step algorithm for Wilder's smoothing (manual SMA for initialization, followed by the recursive formula), ensuring consistency with our other indicators and the global standard (e.g., TradingView).

- **Heikin Ashi Variants (`..._HeikinAshi_MTF.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The `CATR_TrailingStop_HA_Calculator` class first fetches the standard OHLC data from the higher timeframe and then uses our `CHeikinAshi_Calculator` to transform it into a complete Heikin Ashi dataset.
  - The entire ATR Trailing Stop algorithm is then performed on these smoothed **Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values**.
  - This results in a smoother trailing stop that is less susceptible to being triggered by noise, making it well-suited for Heikin Ashi-based trend-following strategies, especially when viewed from a higher-timeframe perspective.

## 4. Parameters

- **`InpUpperTimeframe`**: **The timeframe on which the ATR and all calculations are performed. Setting this to a higher timeframe (e.g., `PERIOD_H1`) will display the stable H1-based stop line on any lower timeframe chart (e.g., M15). `PERIOD_CURRENT` uses the chart's own timeframe. Default is `PERIOD_H1`.**
- **`InpAtrPeriod`**: The lookback period for the ATR and the Highest High / Lowest Low calculations on the selected timeframe. A longer period results in a smoother, slower-reacting stop. Default is `22`.
- **`InpMultiplier`**: The factor to multiply the ATR by. A larger multiplier places the stop further from the price, allowing for more room for pullbacks but resulting in a larger potential loss if the stop is hit. A smaller multiplier keeps the stop tighter. Common values range from 2.5 to 3.5. Default is `3.0`.

## 5. Usage and Interpretation

- **Trailing Stop-Loss:** The primary use of the indicator is as a dynamic, volatility-adjusted trailing stop-loss. In an uptrend, the blue line represents the suggested stop level. In a downtrend, the red line represents the suggested stop level.
- **Trend Identification:** The color and position of the line provide a clear indication of the trend on the **selected timeframe**. A blue line below the price indicates an uptrend; a red line above the price indicates a downtrend.
- **Exit Signal:** The primary signal is for exiting a trade. A long position would be closed when the price closes below the blue line. A short position would be closed when the price closes above the red line.
- **Using MTF for Strategy:** By setting `InpUpperTimeframe` to a higher timeframe (e.g., H1 on an M15 chart), the stop line becomes a structural guide. It will not react to the M15 chart's "noise," only to the volatility and trend changes on the H1 timeframe. This is extremely useful for:
  - **Staying in major trends** without being stopped out by minor intraday pullbacks.
  - Identifying **strong support/resistance zones** based on higher-timeframe volatility.
- **Caution:** The Chandelier Exit is an excellent tool for letting profits run in a strong trend. However, in sideways or choppy markets, it can lead to being stopped out prematurely. It is most effective when used to manage trades within an already identified, strong trend.
