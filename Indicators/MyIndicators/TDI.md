# Trader's Dynamic Index (TDI)

## 1. Summary (Introduction)

The Trader's Dynamic Index (TDI), developed by Dean Malone, is a comprehensive, "all-in-one" market analysis tool presented in a single indicator window. It is designed to provide traders with a simultaneous view of the market's trend direction, momentum, and volatility, earning it the nickname "the market in one window."

The TDI is a hybrid indicator that builds upon the classic Relative Strength Index (RSI). It smooths the RSI with multiple moving averages and envelops it in volatility bands (Bollinger Bands), creating a complete, self-contained system for identifying trading opportunities. Its primary strength lies in providing context for momentum signals, helping traders to filter trades based on the underlying trend and current market volatility.

Our MQL5 suite includes both a standard version and a Heikin Ashi variant for enhanced signal clarity.

## 2. Mathematical Foundations and Calculation Logic

The TDI is constructed in a layered, sequential process, where each new component is derived from a previous one.

### Required Components

- **RSI Period:** The lookback period for the base RSI calculation.
- **Price Line Period:** The period for the first, fastest moving average applied to the RSI.
- **Signal Line Period:** The period for the second, slower moving average, which acts as a signal line.
- **Base Line Period:** The period for the third, slowest moving average, which acts as a trend filter.
- **Bands Deviation:** The standard deviation multiplier for the volatility bands.
- **Source Price:** The price series for the initial RSI calculation (typically `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Calculate the Base RSI:** First, a standard RSI is calculated over the `RSI Period`. Our implementation uses the robust Wilder's smoothing method.

2. **Calculate the RSI Price Line (Fast Line):** The base RSI line is then smoothed using a Simple Moving Average (SMA) with the `Price Line Period`. This creates the fastest, most responsive line in the TDI.
    - $\text{Price Line}_t = \text{SMA}(\text{RSI}, \text{Price Line Period})_t$

3. **Calculate the Trade Signal Line (Slow Line):** The `Price Line` is then smoothed again using an SMA with the `Signal Line Period`. This creates the main signal line.
    - $\text{Signal Line}_t = \text{SMA}(\text{Price Line}, \text{Signal Line Period})_t$

4. **Calculate the Market Base Line (Trend Line):** The `Price Line` is smoothed a third time, using a much longer `Base Line Period` SMA. This creates the slow, central trend line.
    - $\text{Base Line}_t = \text{SMA}(\text{Price Line}, \text{Base Line Period})_t$

5. **Calculate the Volatility Bands:** Finally, standard Bollinger Bands are calculated, but instead of being applied to the price, they are applied to the **Market Base Line**.
    - $\text{Upper Band}_t = \text{Base Line}_t + (\text{Bands Deviation} \times \text{StdDev}(\text{Base Line}, \text{Base Line Period})_t)$
    - $\text{Lower Band}_t = \text{Base Line}_t - (\text{Bands Deviation} \times \text{StdDev}(\text{Base Line}, \text{Base Line Period})_t)$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust and accurate representation of the TDI, built with a modular and stable architecture.

- **Modular, Reusable Calculation Engine (`TDI_Calculator.mqh`):** The entire multi-stage TDI algorithm is encapsulated within a powerful include file. This file contains a base `CTDICalculator` class and an inherited `CTDICalculator_HA` child class. This object-oriented approach separates the complex, layered calculations from the indicator's presentation, eliminates code duplication, and ensures both standard and HA versions are always in sync.

- **Stability via Full Recalculation:** The TDI's calculation is highly state-dependent. To ensure perfect accuracy and prevent any risk of calculation errors or visual glitches, our implementation employs a "brute-force" **full recalculation** on every tick. This is our core principle of prioritizing stability.

- **Clear, Staged Calculation:** Inside the calculator class, the algorithm is implemented in a clear, sequential manner that follows the steps outlined above. Each of the five TDI components is calculated in its own dedicated loop and stored in an internal buffer, making the code highly readable and easy to validate.

- **Heikin Ashi Variant (`TDI_HeikinAshi.mqh`):**
  - Our toolkit also includes a Heikin Ashi version. The `CTDICalculator_HA` class first transforms the standard OHLC prices into Heikin Ashi prices.
  - The entire TDI algorithm, starting from the base RSI calculation, is then performed on the smoothed **Heikin Ashi Close** values.
  - This results in a TDI with significantly smoother lines, which can help to filter out market noise and provide clearer, more reliable trend and momentum signals.

## 4. Parameters

- **RSI Period (`InpRsiPeriod`):** The lookback period for the base RSI. Default is `13`.
- **Price Line Period (`InpPriceLinePeriod`):** The smoothing period for the fast (green) line. Default is `2`.
- **Signal Line Period (`InpSignalLinePeriod`):** The smoothing period for the slow (red) signal line. Default is `7`.
- **Base Line Period (`InpBaseLinePeriod`):** The smoothing period for the yellow trend line and the volatility bands. Default is `34`.
- **Bands Deviation (`InpBandsDeviation`):** The standard deviation multiplier for the blue volatility bands. The standard value is `1.618`.
- **Source Price (`InpSourcePrice`):** The price data for the base RSI calculation. **Note: This is ignored by the Heikin Ashi version.** Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

The TDI is a complete system for analyzing the market. The five lines should be interpreted together to build a complete picture.

- **Trend Direction (Market Base Line - Yellow):** The yellow line indicates the overall medium-term trend. When it is angled up, the trend is bullish; when angled down, bearish. Trades are generally taken in the direction of this line's slope.
- **Momentum (Price Line - Green):** The green line shows the short-term momentum. Its steepness indicates the strength of the current move.
- **Entry Signals (Green/Red Crossover):** The primary entry signal is the crossover of the green Price Line and the red Signal Line.
  - **Buy Signal:** Green line crosses **above** the red line.
  - **Sell Signal:** Green line crosses **below** the red line.
  - **Confirmation:** The strongest signals occur when the crossover happens on the "correct" side of the yellow Base Line (e.g., a buy crossover above the yellow line).
- **Volatility (Volatility Bands - Blue):**
  - **Squeeze:** When the blue bands tighten, it indicates low volatility and warns of a potential breakout. This is often a good time to wait for a clear signal.
  - **Breakout:** When the bands widen, it confirms that volatility is increasing and a strong move is underway.
  - **Extremes:** When the green line touches or moves outside the blue bands, it signals an extreme, potentially overbought or oversold condition, often preceding a pullback.
- **Caution:** While powerful, the TDI can still produce false signals in choppy, directionless markets. It is most effective when its signals are confirmed by price action and analysis of the market structure on the main chart (e.g., support and resistance levels).
