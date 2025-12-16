# Kaufman's Adaptive Moving Average (KAMA) Pro

## 1. Summary (Introduction)

Kaufman's Adaptive Moving Average (KAMA), developed by Perry J. Kaufman, is a sophisticated "intelligent" moving average designed to be both sensitive to trends and resilient to market noise. It addresses the fundamental trade-off of traditional moving averages: a short period is responsive but prone to whipsaws, while a long period is smooth but suffers from significant lag.

KAMA solves this by dynamically adjusting its smoothing speed based on the market's directional efficiency. It automatically slows down during choppy, sideways markets and speeds up during clear, trending periods.

Our `KAMA_Pro` implementation is a definition-true version of this powerful tool, fully supporting calculations on both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The core of KAMA is the **Efficiency Ratio (ER)**, which quantifies the "trendiness" of the market by measuring its signal-to-noise ratio.

### Required Components

* **ER Period (N):** The lookback period for calculating the Efficiency Ratio.
* **Fast EMA Period (F):** The period for the fastest possible EMA (used when the trend is perfect).
* **Slow EMA Period (S):** The period for the slowest possible EMA (used when the market is pure noise).
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Efficiency Ratio (ER):** The ER is the ratio of the net directional movement ("Signal") to the total price movement ("Noise") over the period `N`.
    * **Direction (Signal):** The absolute net change in price over `N` periods.
        $\text{Direction}_t = \text{Abs}(P_t - P_{t-N})$
    * **Volatility (Noise):** The sum of the absolute price changes for each bar within the `N` period.
        $\text{Volatility}_t = \sum_{i=0}^{N-1} \text{Abs}(P_{t-i} - P_{t-i-1})$
    * **Efficiency Ratio:**
        $\text{ER}_t = \frac{\text{Direction}_t}{\text{Volatility}_t}$
        *(The value of ER ranges from 0 to 1)*

2. **Calculate the dynamic Smoothing Constant (SC):** The ER is used to create a dynamic smoothing constant that scales between the fastest and slowest possible speeds.
    * First, define the fastest and slowest smoothing constants based on the EMA formula:
        $\text{sc}_{fast} = \frac{2}{F + 1}$
        $\text{sc}_{slow} = \frac{2}{S + 1}$
    * Then, calculate the scaled smoothing constant and square it to give more weight to the slower end of the range:
        $\text{SC}_t = (\text{ER}_t \times (\text{sc}_{fast} - \text{sc}_{slow}) + \text{sc}_{slow})^2$

3. **Calculate the KAMA:** The KAMA is calculated recursively, similar to an EMA, but using the dynamic `SC` calculated in the previous step.
    $\text{KAMA}_t = \text{KAMA}_{t-1} + \text{SC}_t \times (P_t - \text{KAMA}_{t-1})$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`KAMA_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal price buffer (`m_price`) persists its state between ticks. This allows the calculation to efficiently access historical price data for the Efficiency Ratio without re-copying the entire series.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CKamaCalculator`, handles the core AMA algorithm, including the ER, SSC, and the final recursive calculation.
  * A derived class, `CKamaCalculator_HA`, inherits from the base class and **overrides** only one specific function: the price series preparation. Its sole responsibility is to calculate Heikin Ashi candles and provide the selected HA price to the base class's AMA algorithm. This is a clean and efficient use of polymorphism.

## 4. Parameters (`KAMA_Pro.mq5`)

* **ER Period (`InpErPeriod`):** The lookback period for the Efficiency Ratio calculation. Kaufman's standard value is `10`.
* **Fast EMA Period (`InpFastEmaPeriod`):** The period for the fastest EMA speed. Kaufman's standard value is `2`.
* **Slow EMA Period (`InpSlowEmaPeriod`):** The period for the slowest EMA speed. Kaufman's standard value is `30`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

KAMA is a superior, low-lag trend line that can be used in multiple ways.

* **Primary Trend Filter:** The main function of KAMA is to identify the direction and state of the trend.
  * When the price is consistently above a rising KAMA, the market is in a strong uptrend.
  * When the price is consistently below a falling KAMA, the market is in a strong downtrend.
  * When the KAMA line **flattens out**, it is a clear and early signal that the market has entered a consolidation or ranging phase, and trend-following strategies should be paused. This is KAMA's key advantage over traditional MAs.
* **Dynamic Support and Resistance:** In a trending market, the KAMA line acts as a highly responsive dynamic level of support (in an uptrend) or resistance (in a downtrend), providing potential entry points on pullbacks.
* **Crossover Signals:** Price crossing over the KAMA line can be used as a trade signal, which is often more reliable than traditional MA crossovers due to KAMA's adaptive nature.
