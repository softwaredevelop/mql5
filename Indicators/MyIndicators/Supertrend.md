# Supertrend Indicator

## 1. Summary (Introduction)

The Supertrend indicator was developed by Olivier Seban to identify the primary trend of a financial instrument. It is a popular tool among traders due to its simplicity and clear visual representation of trend direction. Plotted directly on the price chart, the Supertrend line changes color and position based on the market's trend, acting as a dynamic level of support or resistance.

## 2. Mathematical Foundations and Calculation Logic

The Supertrend indicator combines a measure of volatility (Average True Range - ATR) with a central price point (typically the median price) to construct upper and lower bands. The final Supertrend line then follows one of these bands based on the current trend direction.

### Required Components

- **ATR (Average True Range):** A measure of market volatility. A higher ATR indicates a more volatile market.
- **Factor (Multiplier):** A user-defined multiplier that adjusts the sensitivity of the bands. A larger factor creates wider bands, resulting in fewer but potentially more reliable signals.
- **Median Price (hl2):** The central point for the bands, calculated as `(High + Low) / 2`.

### Calculation Steps (Algorithm)

1. **Calculate the Average True Range (ATR)** for a given period.

2. **Calculate the Basic Upper and Lower Bands:** These are the initial, unadjusted bands around the median price.

   $$
   \text{Upper Basic Band} = \frac{\text{High} + \text{Low}}{2} + (\text{Factor} \times \text{ATR})
   $$

   $$
   \text{Lower Basic Band} = \frac{\text{High} + \text{Low}}{2} - (\text{Factor} \times \text{ATR})
   $$

3. **Calculate the Final Upper and Lower Bands:** This step creates the characteristic "stair-step" appearance of the indicator. The logic ensures that the bands never move against the trend (i.e., the upper band can only move down or stay flat, and the lower band can only move up or stay flat).

   $$
   \text{Final Upper Band}_i =
   \begin{cases}
   \text{Upper Basic Band}_i & \text{if } \text{Upper Basic Band}_i < \text{Final Upper Band}_{i-1} \text{ or } \text{Close}_{i-1} > \text{Final Upper Band}_{i-1} \\
   \text{Final Upper Band}_{i-1} & \text{otherwise}
   \end{cases}
   $$

   $$
   \text{Final Lower Band}_i =
   \begin{cases}
   \text{Lower Basic Band}_i & \text{if } \text{Lower Basic Band}_i > \text{Final Lower Band}_{i-1} \text{ or } \text{Close}_{i-1} < \text{Final Lower Band}_{i-1} \\
   \text{Final Lower Band}_{i-1} & \text{otherwise}
   \end{cases}
   $$

4. **Determine the Trend Direction:** The trend is determined by comparing the closing price to the opposite band.

   - If the previous trend was **up**, the trend flips to **down** if the current close crosses below the **Final Lower Band**.
   - If the previous trend was **down**, the trend flips to **up** if the current close crosses above the **Final Upper Band**.
   - If neither condition is met, the trend continues.

5. **Plot the Supertrend Line:**
   - If the trend is **up**, the Supertrend line is plotted at the level of the **Final Lower Band**.
   - If the trend is **down**, the Supertrend line is plotted at the level of the **Final Upper Band**.

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored based on our core principles to ensure maximum stability and code clarity.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a state-dependent indicator like Supertrend, this approach is far more robust than using `prev_calculated` logic, as it prevents calculation errors during timeframe changes or history loading.

- **State Management:** A dedicated calculation buffer, `BufferTrend[]`, is used to explicitly store the current trend direction (`1` for up, `-1` for down). This makes the trend-switching logic clean, readable, and less prone to errors.

- **Robust Initialization:** The trend is explicitly initialized on the first valid bar (`i == g_ExtAtrPeriod`). The initial direction is determined by comparing the closing price to the median price (`hl2`), providing a stable starting point for the recursive logic.

- **Visual Representation:** We opted for a "connected line" visualization for trend changes. When a trend flip occurs, the value of the previous bar's Supertrend line is overwritten to match the new bar's value. This creates a vertical line connecting the old and new trend lines, ensuring continuous visual information.

- **Heikin Ashi Variants:** Our toolkit includes two Heikin Ashi versions of the Supertrend indicator, offering different perspectives on the trend.
  - **Hybrid Version (`Supertrend_HeikinAshi.mq5`):** This version calculates the bands using the smoothed Heikin Ashi median price (`ha_hl2`) and closing price (`ha_close`) but utilizes the **standard ATR** calculated from regular candlesticks. This approach combines the smoothed trend signal of Heikin Ashi with the "true" market volatility. It may be preferred by traders looking for signals based on real volatility spikes.
  - **"Pure" Version (`Supertrend_HeikinAshi_Pure.mq5`):** This version is based entirely on Heikin Ashi data. The ATR is manually calculated from the Heikin Ashi High, Low, and Close values. The result is a fully smoothed indicator where both the trend and the volatility component are filtered. This may be preferred by trend-following traders seeking a less "noisy" signal.

## 4. Parameters

- **ATR Period (`InpAtrPeriod`):** The lookback period for the Average True Range calculation. A shorter period makes the indicator more sensitive to recent volatility, while a longer period provides a smoother, less reactive line. Default is `10`.
- **Factor (`InpFactor`):** The multiplier applied to the ATR value. A smaller factor brings the line closer to the price, resulting in more frequent signals. A larger factor moves the line further away, filtering out minor price fluctuations and producing fewer signals. Default is `3.0`.

## 5. Usage and Interpretation

- **Trend Identification:** The primary use of the Supertrend is to identify the current market trend. A green line below the price indicates an uptrend, while a red line above the price indicates a downtrend.
- **Dynamic Support and Resistance:** In an uptrend, the green line often acts as a dynamic support level. In a downtrend, the red line acts as a dynamic resistance level.
- **Trade Signals:** A change in the indicator's color can be interpreted as a trade signal. A flip from red to green suggests a potential buy signal, while a flip from green to red suggests a potential sell signal.
- **Caution:** Like all trend-following indicators, Supertrend is most effective in trending markets. In sideways or ranging markets, it can produce frequent false signals ("whipsaws"). It is highly recommended to use it in conjunction with other indicators or forms of analysis for confirmation.
