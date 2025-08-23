# Cutler's RSI

## 1. Summary (Introduction)

Cutler's RSI is a variation of the classic Relative Strength Index (RSI) developed by J. Welles Wilder. While the standard RSI uses Wilder's own smoothing method (a type of Smoothed/Running Moving Average), Cutler's version simplifies the formula by using a **Simple Moving Average (SMA)** to average the positive and negative price changes.

This modification results in an oscillator that can react slightly differently to price movements compared to the standard RSI. It is still a momentum oscillator used to identify overbought and oversold conditions, but its SMA-based calculation gives it a unique character.

## 2. Mathematical Foundations and Calculation Logic

The core difference between Cutler's RSI and the standard RSI lies in the smoothing method applied to the price changes.

### Required Components

- **RSI Period (N):** The lookback period for the calculation.
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate Price Changes:** For each period, determine the change in price from the previous period.
   $\text{Change}_i = P_i - P_{i-1}$

2. **Separate Positive and Negative Changes:**

   - If $\text{Change}_i > 0$, then $\text{Positive Change}_i = \text{Change}_i$ and $\text{Negative Change}_i = 0$.
   - If $\text{Change}_i < 0$, then $\text{Positive Change}_i = 0$ and $\text{Negative Change}_i = \text{Abs}(\text{Change}_i)$.
   - If $\text{Change}_i = 0$, then both are 0.

3. **Calculate the Simple Moving Average of Changes:** This is the defining step. Apply an SMA with period `N` to both the positive and negative change series.
   $\text{Avg Positive}_i = \text{SMA}(\text{Positive Change}, N)_i$
   $\text{Avg Negative}_i = \text{SMA}(\text{Negative Change}, N)_i$

4. **Calculate the Relative Strength (RS) and Final RSI:**
   $\text{RS}_i = \frac{\text{Avg Positive}_i}{\text{Avg Negative}_i}$
   $\text{Cutler's RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored for maximum stability, clarity, and computational efficiency.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice for all indicators, especially those with a signal line involving recursive calculations (EMA/SMMA), to ensure stability.

- **Efficient RSI Calculation:** Instead of using multiple loops or inefficient `SimpleMA` calls on every bar, we calculate the Cutler's RSI in a single `for` loop using an efficient **sliding window sum** technique. We maintain a running sum of positive and negative changes, adding the newest value and subtracting the oldest value in each iteration. This is mathematically equivalent to an SMA but significantly faster.

- **Self-Contained Price Handling:** The indicator does not use external handles like `iMA`. It directly processes the price arrays (`open`, `high`, `low`, `close`) provided by `OnCalculate` and includes logic to handle all standard and calculated `ENUM_APPLIED_PRICE` types.

- **Robust Signal Line:** The optional signal line (a moving average of the Cutler's RSI line) is calculated using our standard, robust `switch` block.

  - For recursive types (**EMA, SMMA**), the first value is initialized with a **manual SMA** calculation at the correct starting index to prevent the floating-point overflows that plague less robust implementations.
  - For non-recursive types (**SMA, LWMA**), we safely use the functions from the `<MovingAverages.mqh>` library.

- **Heikin Ashi Variant (`CutlerRSI_MA_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_close` values as its input.
  - This results in a doubly-smoothed oscillator, ideal for traders who want to focus only on the most significant, sustained momentum shifts.

## 4. Parameters

- **RSI Period (`InpPeriodRSI`):** The lookback period for the SMA of price changes. Default is `14`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation (e.g., `PRICE_CLOSE`).
- **MA Period (`InpPeriodMA`):** The lookback period for the optional signal line.
- **MA Method (`InpMethodMA`):** The type of moving average for the signal line.

## 5. Usage and Interpretation

The interpretation of Cutler's RSI is identical to the standard RSI.

- **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 70) and oversold (typically below 30) conditions.
- **Crossovers:**
  - **Signal Line Crossover:** When the Cutler's RSI line crosses above its moving average, it can be seen as a bullish signal. A cross below is a bearish signal.
  - **Centerline Crossover:** A crossover of the RSI line above the 50 level indicates that momentum is shifting to bullish. A crossover below 50 indicates bearish momentum.
- **Divergence:** Look for divergences between the RSI and the price action. A bearish divergence (higher price highs, lower RSI highs) can signal a potential top, while a bullish divergence (lower price lows, higher RSI highs) can signal a potential bottom.
- **Caution:** As a momentum oscillator, it is most effective in ranging or moderately trending markets. In a very strong trend, it can remain in overbought or oversold territory for extended periods.
