# MACD Pro (with Selectable MA Types)

## 1. Summary (Introduction)

The MACD Pro is an enhanced version of the classic Moving Average Convergence/Divergence indicator. While the standard MACD, as developed by Gerald Appel, exclusively uses Exponential Moving Averages (EMAs), this "Pro" version offers traders the flexibility to choose from four different moving average types for its calculation:

- Simple Moving Average (SMA)
- Exponential Moving Average (EMA)
- Smoothed Moving Average (SMMA)
- Linear Weighted Moving Average (LWMA)

This customization allows traders to fine-tune the indicator's responsiveness and smoothness to better fit their specific trading style and market analysis. The indicator displays the three core components in the popular TradingView style: the MACD Line, the Signal Line, and the true Histogram.

## 2. Mathematical Foundations and Calculation Logic

The MACD Pro follows the classic MACD structure but generalizes the moving average calculation.

### Required Components

- **Fast Period, Slow Period, Signal Period:** The lookback periods for the three moving averages.
- **Source MA Type:** The type of MA (SMA, EMA, etc.) to be used for the Fast and Slow lines.
- **Signal MA Type:** The type of MA to be used for the Signal Line.
- **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Fast MA:** Compute a moving average of the source price using the fast period and the selected `Source MA Type`.
   $\text{FastMA} = \text{MA}(\text{Price}, \text{FastPeriod}, \text{SourceMAType})$

2. **Calculate the Slow MA:** Compute a moving average of the source price using the slow period and the selected `Source MA Type`.
   $\text{SlowMA} = \text{MA}(\text{Price}, \text{SlowPeriod}, \text{SourceMAType})$

3. **Calculate the MACD Line:** Subtract the Slow MA from the Fast MA.
   $\text{MACD Line} = \text{FastMA} - \text{SlowMA}$

4. **Calculate the Signal Line:** Compute a moving average of the **MACD Line** using the signal period and the selected `Signal MA Type`.
   $\text{Signal Line} = \text{MA}(\text{MACD Line}, \text{SignalPeriod}, \text{SignalMAType})$

5. **Calculate the Histogram:** Subtract the Signal Line from the MACD Line.
   $\text{Histogram} = \text{MACD Line} - \text{Signal Line}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a completely self-contained, robust, and highly flexible indicator built upon our established coding principles.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function to ensure maximum stability and prevent calculation errors.

- **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency across all MA types within our `non-timeseries` model, all four moving average calculations (**SMA, EMA, SMMA, LWMA**) are performed **manually**. The indicator is completely independent of the `<MovingAverages.mqh>` standard library.

  - **Robust Initialization:** All recursive MA types (EMA, SMMA) are carefully initialized with a manual Simple Moving Average (SMA) to provide a stable starting point for the calculation chain.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This makes the complex, multi-stage logic easy to follow and debug:

  1. **Step 1:** The source price array is prepared.
  2. **Step 2 & 3:** The Fast and Slow MAs are calculated using their respective `switch` blocks.
  3. **Step 4:** The MACD Line is calculated.
  4. **Step 5:** The Signal Line is calculated using its own `switch` block, and the final Histogram value is computed.

- **TradingView-Style Visualization:** Our implementation plots all three standard components: the MACD Line (blue), the Signal Line (orange/red), and the true Histogram (the difference between the two lines), providing a more informative visual than the default MetaTrader MACD.

- **Heikin Ashi Variant (`MACD_Pro_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data as its input for the initial Fast and Slow MAs. This allows for an extremely high degree of customization in creating smoothed momentum signals.

## 4. Parameters

- **Fast Period (`InpFastPeriod`):** The period for the shorter-term MA. Default is `12`.
- **Slow Period (`InpSlowPeriod`):** The period for the longer-term MA. Default is `26`.
- **Signal Period (`InpSignalPeriod`):** The period for the signal line's MA. Default is `9`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. Default is `PRICE_CLOSE`.
- **Source MA Type (`InpSourceMAType`):** The MA type for the Fast and Slow lines. Default is `MODE_EMA` (classic MACD).
- **Signal MA Type (`InpSignalMAType`):** The MA type for the Signal line. Default is `MODE_EMA` (classic MACD).

## 5. Usage and Interpretation

The interpretation of the MACD Pro is identical to the standard MACD, but the signals may be faster or slower depending on the selected MA types.

- **Signal Line Crossovers:** The primary signal. A crossover of the MACD Line above the Signal Line is bullish; a cross below is bearish.
- **Zero Line Crossovers:** A secondary signal confirming the overall trend direction.
- **Divergence:** A powerful signal where the indicator's momentum disagrees with the price action, often foreshadowing a reversal.
- **Histogram:** Visually represents the momentum's acceleration or deceleration.

**Effect of MA Types:**

- **EMA (Default):** The classic, balanced MACD.
- **SMA:** Using SMAs for all components will result in a much slower, smoother MACD with significant lag but fewer false signals.
- **LWMA:** Using LWMAs will result in a faster, more responsive MACD that is more sensitive to recent price changes than the EMA version.
