# Adaptive Moving Average (AMA) Pro

## 1. Summary (Introduction)

The Adaptive Moving Average (AMA), developed by Perry J. Kaufman, is an advanced moving average designed to automatically adjust its speed based on market volatility. It addresses a core dilemma of traditional moving averages: the trade-off between lag and smoothness.

The AMA's key feature is its ability to move very slowly when the market is consolidating or moving sideways (high noise, low directional movement), and to speed up and track prices closely when the market is trending (low noise, high directional movement).

Our `AMA_Pro` implementation is a unified, professional version that integrates both **standard** and **Heikin Ashi** price sources into a single, robust indicator.

## 2. Mathematical Foundations and Calculation Logic

The AMA's adaptability is achieved through the **Efficiency Ratio (ER)**, which quantifies the amount of "noise" in the market.

### Required Components

* **AMA Period (N):** The lookback period for calculating the Efficiency Ratio.
* **Fast/Slow EMA Periods:** Used to define the fastest and slowest possible speeds for the AMA.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Efficiency Ratio (ER):** The ER is the ratio of the net price change (Direction) to the sum of all individual price changes (Volatility) over the period `N`.

    * $\text{Direction}_i = \text{Abs}(\text{Price}_i - \text{Price}_{i-N})$
    * $\text{Volatility}_i = \sum_{k=i-N+1}^{i} \text{Abs}(\text{Price}_k - \text{Price}_{k-1})$
    * $\text{ER}_i = \frac{\text{Direction}_i}{\text{Volatility}_i}$
    * An ER value close to `1` indicates an efficient, trending market. A value close to `0` indicates an inefficient, noisy market.

2. **Calculate the Scaled Smoothing Constant (SSC):** The ER is used to create a dynamic smoothing constant that varies between the constants of a fast and a slow EMA.

    * $\text{Fast SC} = \frac{2}{\text{Fast Period} + 1}$
    * $\text{Slow SC} = \frac{2}{\text{Slow Period} + 1}$
    * $\text{SSC}_i = (\text{ER}_i \times (\text{Fast SC} - \text{Slow SC})) + \text{Slow SC}$

3. **Calculate the Final AMA:** The AMA is calculated recursively. The `SSC` is squared to give more weight to the faster smoothing constant during trends.
    $\text{AMA}_i = \text{AMA}_{i-1} + (\text{SSC}_i)^2 \times (P_i - \text{AMA}_{i-1})$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`AMA_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal price buffer (`m_price`) persists its state between ticks. This allows the calculation to efficiently access historical price data for the Efficiency Ratio without re-copying the entire series.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CAMACalculator`, handles the core AMA algorithm, including the ER, SSC, and the final recursive calculation.
  * A derived class, `CAMACalculator_HA`, inherits from the base class and **overrides** only one specific function: the price series preparation. Its sole responsibility is to calculate Heikin Ashi candles and provide the selected HA price to the base class's AMA algorithm. This is a clean and efficient use of polymorphism.

## 4. Parameters (`AMA_Pro.mq5`)

* **AMA Period (`InpAmaPeriod`):** The lookback period for the Efficiency Ratio calculation. Default is `10`.
* **Fast EMA Period (`InpFastEmaPeriod`):** Defines the "fastest" speed of the AMA. Default is `2`.
* **Slow EMA Period (`InpSlowEmaPeriod`):** Defines the "slowest" speed of the AMA. Default is `30`.
* **Applied Price (`InpSourcePrice`):** The source price used for the calculation. This unified dropdown menu allows you to select from all standard price types (e.g., `PRICE_CLOSE_STD`) and all Heikin Ashi price types (e.g., `PRICE_HA_CLOSE`). Default is `PRICE_CLOSE_STD`.

## 5. Usage and Interpretation

* **Trend Identification:** The AMA is used as an adaptive trend line. When the price is above the AMA and the line is rising, the trend is bullish. When the price is below the line and it is falling, the trend is bearish.
* **Trend Filter:** The key advantage of the AMA is its ability to flatten out and move slowly during sideways markets. A flat AMA line is a clear signal to avoid trend-following strategies. When the line begins to angle up or down sharply, it indicates that the market has entered a more efficient, trending phase.
* **Crossover Signals:** Crossovers of the price and the AMA line can be used as trade signals. These signals are naturally filtered by the indicator itself, as crossovers are less likely to occur during choppy conditions when the AMA is moving slowly.
