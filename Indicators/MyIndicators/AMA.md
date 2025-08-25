# Adaptive Moving Average (AMA)

## 1. Summary (Introduction)

The Adaptive Moving Average (AMA), developed by Perry J. Kaufman, is an advanced moving average designed to automatically adjust its speed based on market volatility. It addresses a core dilemma of traditional moving averages: the trade-off between lag and smoothness.

The AMA's key feature is its ability to move very slowly when the market is consolidating or moving sideways (high noise, low directional movement), and to speed up and track prices closely when the market is trending (low noise, high directional movement). This adaptability helps to filter out false signals in choppy markets while remaining responsive during strong trends.

## 2. Mathematical Foundations and Calculation Logic

The AMA's adaptability is achieved through the **Efficiency Ratio (ER)**, which quantifies the amount of "noise" in the market.

### Required Components

- **AMA Period (N):** The lookback period for calculating the Efficiency Ratio.
- **Fast/Slow EMA Periods:** Used to define the fastest and slowest possible speeds for the AMA.
- **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Efficiency Ratio (ER):** The ER is the ratio of the net price change (Direction) to the sum of all individual price changes (Volatility) over the period `N`.

   - $\text{Direction}_i = \text{Abs}(\text{Price}_i - \text{Price}_{i-N})$
   - $\text{Volatility}_i = \sum_{k=i-N+1}^{i} \text{Abs}(\text{Price}_k - \text{Price}_{k-1})$
   - $\text{ER}_i = \frac{\text{Direction}_i}{\text{Volatility}_i}$
   - An ER value close to `1` indicates an efficient, trending market. A value close to `0` indicates an inefficient, noisy market.

2. **Calculate the Scaled Smoothing Constant (SSC):** The ER is used to create a dynamic smoothing constant that varies between the constants of a fast and a slow EMA.

   - $\text{Fast SC} = \frac{2}{\text{Fast Period} + 1}$
   - $\text{Slow SC} = \frac{2}{\text{Slow Period} + 1}$
   - $\text{SSC}_i = (\text{ER}_i \times (\text{Fast SC} - \text{Slow SC})) + \text{Slow SC}$

3. **Calculate the Final AMA:** The AMA is calculated recursively. The `SSC` is squared to give more weight to the faster smoothing constant during trends.
   $\text{AMA}_i = \text{AMA}_{i-1} + (\text{SSC}_i)^2 \times (P_i - \text{AMA}_{i-1})$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and accurate representation of Kaufman's AMA.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a recursive indicator like the AMA, this is the most reliable method to ensure stability.

- **Robust Initialization:** The recursive AMA calculation is carefully initialized. The **first valid value** of the AMA line (`BufferAMA[g_ExtAmaPeriod]`) is set directly to the current source price. This provides a simple and highly stable starting point for the subsequent recursive calculations.

- **Self-Contained Logic:** The indicator is completely self-contained and does not use any external handles or libraries. The source price is prepared internally using a `switch` block that handles all `ENUM_APPLIED_PRICE` types.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps. After preparing the source price array, a single, efficient `for` loop handles the entire AMA calculation, including the ER and SSC computations.

- **Heikin Ashi Variant (`AMA_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data as its input.
  - **Behavioral Note:** This version can appear _more responsive_ than the standard version in strong trends. The smoothed Heikin Ashi data produces a very high Efficiency Ratio (close to 1), causing the AMA to switch to its fastest speed and closely track the underlying Heikin Ashi trend.

## 4. Parameters

- **AMA Period (`InpAmaPeriod`):** The lookback period for the Efficiency Ratio calculation. Default is `10`.
- **Fast EMA Period (`InpFastEmaPeriod`):** Defines the "fastest" speed of the AMA. Default is `2`.
- **Slow EMA Period (`InpSlowEmaPeriod`):** Defines the "slowest" speed of the AMA. Default is `30`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

- **Trend Identification:** The AMA is used as an adaptive trend line. When the price is above the AMA and the line is rising, the trend is bullish. When the price is below the line and it is falling, the trend is bearish.
- **Trend Filter:** The key advantage of the AMA is its ability to flatten out and move slowly during sideways markets. A flat AMA line is a clear signal to avoid trend-following strategies. When the line begins to angle up or down sharply, it indicates that the market has entered a more efficient, trending phase.
- **Crossover Signals:** Crossovers of the price and the AMA line can be used as trade signals. These signals are naturally filtered by the indicator itself, as crossovers are less likely to occur during choppy conditions when the AMA is moving slowly.
