# True Strength Index (TSI) and TSI Oscillator

## 1. Summary (Introduction)

The True Strength Index (TSI) is a momentum oscillator developed by William Blau. It was designed to provide a smoother and more reliable measure of market momentum by using a double-smoothing mechanism with Exponential Moving Averages (EMAs). The TSI fluctuates around a zero line, providing clear signals for trend direction, momentum, and overbought/oversold conditions.

The **TSI Oscillator** is a supplementary indicator that displays the difference between the TSI line and its signal line as a histogram. It provides a clearer visual representation of the accelerating and decelerating momentum, similar to the MACD histogram.

## 2. Mathematical Foundations and Calculation Logic

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum, and then computing their ratio.

### Required Components

- **Slow Period (N_slow):** The period for the first, longer-term EMA smoothing (standard is 25).
- **Fast Period (N_fast):** The period for the second, shorter-term EMA smoothing (standard is 13).
- **Signal Period:** The period for the moving average signal line (standard is 13).
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate Price Momentum (Change):** For each bar, calculate the change in price from the previous bar.
   $\text{Momentum}_i = P_i - P_{i-1}$

2. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `Momentum` and its absolute value.
   $\text{EMA}_{\text{slow}}(\text{Momentum})_i = \text{EMA}(\text{Momentum}, N_{\text{slow}})_i$
   $\text{EMA}_{\text{slow}}(\text{AbsMomentum})_i = \text{EMA}(\text{Abs}(\text{Momentum}), N_{\text{slow}})_i$

3. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Momentum}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{Momentum}), N_{\text{fast}})_i$
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsMomentum}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{AbsMomentum}), N_{\text{fast}})_i$

4. **Calculate the TSI Value:** Divide the double-smoothed momentum by the double-smoothed absolute momentum and scale the result to 100. This creates the main TSI line.
   $\text{TSI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Momentum}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsMomentum}))_i}$

5. **Calculate the Signal Line:** The signal line is a moving average of the TSI line itself.
   $\text{Signal}_i = \text{MA}(\text{TSI}, \text{Signal Period})_i$

6. **Calculate the TSI Oscillator:** The oscillator is the difference between the TSI line and its Signal Line.
   $\text{Oscillator}_i = \text{TSI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and accurate representations of the classic, double-smoothed TSI and its oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Correct Algorithm:** Our implementation strictly follows the correct, textbook definition of the TSI, ensuring its results are consistent with other professional charting platforms like TradingView.

- **Fully Manual EMA Calculations:** All EMA calculations are performed **manually**. Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)** to provide a stable starting point for the calculation chain and to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the complex, multi-stage logic easy to follow.

- **Flexible Signal Line:** The `TSI.mq5` indicator includes a user-configurable moving average signal line, with a robust `switch` block that correctly handles all MA types (SMA, EMA, SMMA, LWMA).

- **Heikin Ashi Variants:**
  - Both the `TSI.mq5` and `TSI_Oscillator.mq5` have "pure" Heikin Ashi counterparts. The calculation logic is identical, but they use the smoothed Heikin Ashi price data as their input for the initial momentum calculation. This results in exceptionally smooth oscillators.

## 4. Parameters

- **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. **Default is 25.**
- **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. **Default is 13.**
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. Default is `PRICE_CLOSE`.
- **Signal Line Settings:**
  - `InpSignalPeriod`: The lookback period for the signal line. **Default is 13.**
  - `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

- **Zero Line Crossovers:** This is a primary trend signal.
  - **Bullish:** A crossover of the TSI line above the zero line indicates that long-term momentum has turned positive.
  - **Bearish:** A crossover below the zero line indicates that long-term momentum has turned negative.
- **Signal Line Crossovers:** These provide earlier, shorter-term momentum signals.
  - **Bullish:** The TSI line crosses above its signal line.
  - **Bearish:** The TSI line crosses below its signal line.
- **Overbought/Oversold Levels:** The **+25 and -25** levels are often used to identify extreme momentum.
- **Divergence:** Due to its smoothness, the TSI is excellent for spotting divergences between price and momentum, which can foreshadow reversals.
- **TSI Oscillator:** The histogram provides a clear visual of the relationship between the TSI and its signal line.
  - **Histogram > 0:** The TSI is above its signal line (bullish momentum).
  - **Histogram < 0:** The TSI is below its signal line (bearish momentum).
  - **Growing Histogram:** Momentum is accelerating in the current direction.
  - **Shrinking Histogram:** Momentum is decelerating, which can be an early warning of a potential crossover.
