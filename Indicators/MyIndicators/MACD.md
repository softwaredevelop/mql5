# Moving Average Convergence/Divergence (MACD)

## 1. Summary (Introduction)

The Moving Average Convergence/Divergence (MACD), developed by Gerald Appel in the late 1970s, is one of the most popular and versatile technical indicators. It is a trend-following momentum indicator that shows the relationship between two exponential moving averages (EMAs) of a security’s price.

The MACD is composed of three main components, which together provide a comprehensive view of trend direction, momentum, and potential reversal points:

- **The MACD Line:** The core of the indicator.
- **The Signal Line:** A moving average of the MACD Line, used to generate trade signals.
- **The Histogram:** Represents the difference between the MACD Line and the Signal Line.

## 2. Mathematical Foundations and Calculation Logic

The MACD is calculated through a series of subtractions and exponential smoothing steps.

### Required Components

- **Fast EMA Period:** The period for the shorter-term EMA (standard is 12).
- **Slow EMA Period:** The period for the longer-term EMA (standard is 26).
- **Signal EMA Period:** The period for the EMA that smooths the MACD Line (standard is 9).
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate the Fast EMA:** Compute an EMA of the source price using the fast period.
   $\text{FastEMA} = \text{EMA}(P, \text{FastPeriod})$

2. **Calculate the Slow EMA:** Compute an EMA of the source price using the slow period.
   $\text{SlowEMA} = \text{EMA}(P, \text{SlowPeriod})$

3. **Calculate the MACD Line:** Subtract the Slow EMA from the Fast EMA. This is the main momentum line.
   $\text{MACD Line} = \text{FastEMA} - \text{SlowEMA}$

4. **Calculate the Signal Line:** Compute an EMA of the MACD Line using the signal period.
   $\text{Signal Line} = \text{EMA}(\text{MACD Line}, \text{SignalPeriod})$

5. **Calculate the Histogram:** Subtract the Signal Line from the MACD Line.
   $\text{Histogram} = \text{MACD Line} - \text{Signal Line}$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be a completely self-contained, robust, and accurate representation of the classic, TradingView-style MACD.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice for indicators with multiple recursive calculations to ensure maximum stability.

- **Fully Manual EMA Calculations:** To guarantee 100% accuracy and consistency, all three Exponential Moving Averages (Fast, Slow, and Signal) are calculated **manually**. The indicator is completely independent of external handles or libraries.

  - **Robust Initialization:** Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)**. This provides a stable starting point for the recursive calculations and completely eliminates the risk of floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the complex logic easy to follow:

  1. **Step 1:** The source price array is prepared.
  2. **Step 2 & 3:** The Fast and Slow EMAs are calculated and stored in calculation buffers.
  3. **Step 4:** The MACD Line is calculated from the two EMAs.
  4. **Step 5:** The Signal Line (EMA of the MACD Line) and the final Histogram value are calculated.

- **TradingView-Style Visualization:** Our implementation plots all three standard components: the MACD Line (blue), the Signal Line (orange/red), and the true Histogram (the difference between the two lines), providing a more informative visual than the default MetaTrader MACD.

- **Heikin Ashi Variant (`MACD_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data as its input for the initial Fast and Slow EMAs.
  - This results in a "doubly smoothed" MACD, which is excellent for filtering out market noise and identifying the most significant, underlying momentum shifts.

## 4. Parameters

- **Fast EMA Period (`InpFastEMA`):** The period for the shorter-term EMA. Default is `12`.
- **Slow EMA Period (`InpSlowEMA`):** The period for the longer-term EMA. Default is `26`.
- **Signal EMA Period (`InpSignalEMA`):** The period for the signal line's EMA. Default is `9`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

- **Signal Line Crossovers:** This is the most common MACD signal.
  - **Bullish Crossover:** When the MACD Line (blue) crosses above the Signal Line (red).
  - **Bearish Crossover:** When the MACD Line crosses below the Signal Line.
- **Zero Line Crossovers:** These indicate a potential change in the overall trend direction.
  - **Bullish Crossover:** When the MACD Line crosses above the zero line.
  - **Bearish Crossover:** When the MACD Line crosses below the zero line.
- **Divergence:** This is one of the most powerful MACD signals.
  - **Bullish Divergence:** Price makes a lower low, but the MACD makes a higher low, suggesting weakening bearish momentum.
  - **Bearish Divergence:** Price makes a higher high, but the MACD makes a lower high, suggesting weakening bullish momentum.
- **Histogram:** The histogram visually represents the distance between the MACD and Signal lines. When the bars grow taller, momentum is increasing. When they shrink, momentum is decreasing, which can be an early warning of a potential crossover.
