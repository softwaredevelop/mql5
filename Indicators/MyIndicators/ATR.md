# Average True Range (ATR)

## 1. Summary (Introduction)

The Average True Range (ATR) is a technical analysis indicator developed by J. Welles Wilder, introduced in his 1978 book "New Concepts in Technical Trading Systems." The ATR is not used to indicate price direction; rather, it is a measure of **volatility**.

It calculates the "true range" for each period and then smooths these values, providing a representation of the average size of the price range over a given time. High ATR values indicate high volatility, while low ATR values indicate low volatility or a period of consolidation. It is a foundational tool for many other indicators (like Supertrend, Keltner Channels) and for risk management strategies, such as setting stop-loss levels.

## 2. Mathematical Foundations and Calculation Logic

The ATR is based on the concept of the "True Range" (TR), which provides a more comprehensive measure of a single period's volatility than the simple High-Low range.

### Required Components

- **Period (N):** The lookback period for the smoothing calculation (e.g., 14).
- **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the True Range (TR):** For each bar, the True Range is the **greatest** of the following three values:

   - The current High minus the current Low: $\text{High}_i - \text{Low}_i$
   - The absolute value of the current High minus the previous Close: $\text{Abs}(\text{High}_i - \text{Close}_{i-1})$
   - The absolute value of the current Low minus the previous Close: $\text{Abs}(\text{Low}_i - \text{Close}_{i-1})$
     $\text{TR}_i = \text{Max}[(\text{High}_i - \text{Low}_i), \text{Abs}(\text{High}_i - \text{Close}_{i-1}), \text{Abs}(\text{Low}_i - \text{Close}_{i-1})]$

2. **Calculate the Average True Range (ATR):** The ATR is a smoothed moving average of the True Range values, calculated using Wilder's specific smoothing method (also known as a Running Moving Average - RMA, or a specific type of Smoothed Moving Average - SMMA).
   - **Initialization:** The first ATR value is a simple average of the first `N` TR values.
     $\text{ATR}_{N} = \frac{1}{N} \sum_{i=1}^{N} \text{TR}_i$
   - **Recursive Calculation:** All subsequent values are calculated using the following formula:
     $\text{ATR}_i = \frac{(\text{ATR}_{i-1} \times (N-1)) + \text{TR}_i}{N}$

_Note: This smoothing method is the globally accepted standard for ATR, as used by platforms like TradingView. The built-in `iATR` in MetaTrader uses a different, non-standard smoothing algorithm._

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and accurate representation of the classic Wilder's ATR.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the recursive ATR calculation remains stable and accurate, especially during timeframe changes or history loading.

- **Consensus Wilder Algorithm:** The implementation strictly follows our established two-step algorithm for Wilder's smoothing:

  1. **Robust Initialization:** The first ATR value (`BufferATR[g_ExtAtrPeriod]`) is calculated as a simple average of the first `N` True Range values. This provides a stable starting point for the recursive calculation.
  2. **Efficient Recursive Calculation:** All subsequent values are calculated using the efficient recursive formula, which is mathematically identical to Wilder's original method.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into two clear, sequential steps:

  1. **Step 1:** A `for` loop calculates the True Range for every bar and stores the results in a temporary `tr[]` array.
  2. **Step 2:** A second `for` loop iterates through the `tr[]` array and applies our robust Wilder's smoothing algorithm to calculate the final `BufferATR` values.

- **Heikin Ashi Variant (`ATR_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values to calculate the True Range.
  - This results in a "smoothed volatility" measure, which reflects the volatility of the underlying Heikin Ashi trend rather than the raw market price. This can be useful for setting stop-losses in a Heikin Ashi-based trading system.

## 4. Parameters

- **ATR Period (`InpAtrPeriod`):** The lookback and smoothing period for the indicator. Wilder's original recommendation and the most common value is `14`.

## 5. Usage and Interpretation

- **Volatility Gauge:** The ATR's primary function is to measure volatility. A rising ATR indicates that volatility is increasing, meaning daily trading ranges are widening. A falling ATR indicates that volatility is decreasing and the market is entering a period of consolidation.
- **Stop-Loss Placement:** ATR is a cornerstone of modern risk management. A common technique is to place a stop-loss at a multiple of the ATR (e.g., 2 x ATR) below a long entry price or above a short entry price. This adapts the stop-loss distance to the current market conditions.
- **Position Sizing:** ATR can be used to normalize position sizes across different instruments. By calculating a position size based on a fixed risk amount (e.g., 1% of account equity) and the instrument's ATR, a trader can take on similar levels of risk regardless of whether they are trading a volatile or a quiet instrument.
- **Caution:** ATR does not provide any information about trend direction. A high ATR could be present in a strong uptrend, a strong downtrend, or a volatile ranging market. It should always be used in conjunction with other trend or momentum indicators.
