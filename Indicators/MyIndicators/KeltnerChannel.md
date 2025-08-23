# Keltner Channel

## 1. Summary (Introduction)

The Keltner Channel is a volatility-based technical indicator developed by Chester W. Keltner in his 1960 book "How to Make Money in Commodities." The modern version was later updated by Linda Bradford Raschke, who introduced the use of an Exponential Moving Average (EMA) for the centerline and the Average True Range (ATR) for calculating the channel width.

The indicator consists of three lines: a central moving average line, an upper band, and a lower band. It is primarily used to identify trend direction, spot potential trend reversals or continuations through breakouts, and gauge volatility.

## 2. Mathematical Foundations and Calculation Logic

The Keltner Channel is constructed by creating a channel around a central moving average, with the width of the channel determined by the market's volatility.

### Required Components

- **Middle Line (Basis):** A moving average of a selected price. The most common version uses an Exponential Moving Average (EMA) of the Typical Price `(High + Low + Close) / 3`.
- **ATR (Average True Range):** A measure of market volatility.
- **Factor (Multiplier):** A user-defined multiplier that adjusts the width of the channel.

### Calculation Steps (Algorithm)

1. **Calculate the Middle Line:** Compute the moving average (e.g., 20-period EMA) of the selected source price.
   $\text{Middle Line}_i = \text{MA}(\text{Source Price}, \text{MA Period})_i$

2. **Calculate the Average True Range (ATR):** Compute the ATR for a given period (e.g., 10).

3. **Calculate the Upper and Lower Bands:** Add and subtract a multiple of the ATR from the middle line.
   $\text{Upper Band}_i = \text{Middle Line}_i + (\text{Factor} \times \text{ATR}_i)$
   $\text{Lower Band}_i = \text{Middle Line}_i - (\text{Factor} \times \text{ATR}_i)$

## 3. MQL5 Implementation Details

Our MQL5 implementations were refactored based on our core principles to create three distinct, robust, and stable versions of the Keltner Channel.

- **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice to ensure maximum stability and prevent calculation errors, especially with the recursive calculations involved in EMA and ATR.

- **Robust Manual Calculations:** To ensure 100% accuracy and stability within our `non-timeseries` calculation model, we use fully manual implementations for all moving average types (SMA, EMA, SMMA, LWMA) and for the Wilder's smoothing used in the ATR calculation. Each recursive calculation (EMA, SMMA, ATR) is carefully initialized with a simple average to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function in each version is structured into clear, sequential steps (e.g., Price Preparation, TR Calculation, Integrated MA/ATR/Band Calculation), which improves code readability and maintainability.

### Our Three Keltner Channel Versions

1. **Standard Version (`KeltnerChannel.mq5`):**

   - **Concept:** The classic, industry-standard implementation.
   - **Logic:** The middle line is a moving average of **standard prices** (e.g., Typical Price). The channel width is determined by the ATR of **standard candlesticks**.
   - **Implementation:** To guarantee perfect accuracy with the MetaTrader platform's built-in indicators, this version uses an `iMA` handle for the middle line while calculating the standard ATR manually for consistency.

2. **Hybrid Heikin Ashi Version (`KeltnerChannel_HeikinAshi.mq5`):**

   - **Concept:** Combines a smoothed Heikin Ashi trend line with real market volatility.
   - **Logic:** The middle line is a moving average of **Heikin Ashi prices**. The channel width is determined by the ATR of **standard candlesticks**.
   - **Implementation:** Fully self-contained. It uses our `CHeikinAshi_Calculator` for the price data and calculates both the HA-based MA and the standard ATR manually.

3. **"Pure" Heikin Ashi Version (`KeltnerChannel_HeikinAshi_Pure.mq5`):**
   - **Concept:** A fully smoothed channel that reflects the volatility of the underlying Heikin Ashi trend.
   - **Logic:** The middle line is a moving average of **Heikin Ashi prices**. The channel width is determined by the ATR calculated from the **Heikin Ashi candlesticks**.
   - **Implementation:** Fully self-contained and manual. This version results in narrower, smoother channels compared to the other two.

## 4. Parameters

- **MA Period (`InpMaPeriod`):** The lookback period for the middle line moving average. Default is `20`.
- **MA Method (`InpMaMethod`):** The type of moving average for the middle line. Default is `MODE_EMA`.
- **Applied Price (`InpAppliedPrice`):** The source price for the middle line. Default is `PRICE_TYPICAL`.
- **ATR Period (`InpAtrPeriod`):** The lookback period for the ATR calculation. Default is `10`.
- **Multiplier (`InpMultiplier`):** The factor to multiply the ATR by. Default is `2.0`.

## 5. Usage and Interpretation

- **Trend Identification:** The slope of the channel helps identify the trend. An upward-sloping channel suggests an uptrend, while a downward-sloping one suggests a downtrend. The middle line acts as the mean of the trend.
- **Breakouts:** A strong close above the upper band can signal the start or continuation of an uptrend. A strong close below the lower band can signal the start or continuation of a downtrend.
- **Overbought/Oversold (in Ranges):** In a sideways market, moves to the upper band can be seen as overbought, and moves to the lower band can be seen as oversold, presenting potential reversal opportunities.
- **Caution:** Like all channel indicators, Keltner Channels can give false breakout signals. It is often used in conjunction with momentum oscillators (like RSI or Stochastics) to confirm the strength of a move.
