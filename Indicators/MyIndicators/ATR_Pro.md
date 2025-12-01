# Average True Range (ATR) Pro

## 1. Summary (Introduction)

The Average True Range (ATR) is a technical analysis indicator developed by J. Welles Wilder. The ATR is not used to indicate price direction; rather, it is a measure of **volatility**.

It calculates the "true range" for each period and then smooths these values, providing a representation of the average size of the price range. High ATR values indicate high volatility, while low ATR values indicate low volatility.

Our `ATR_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** candles. Furthermore, it can display the ATR value in two modes:

* **Points:** The classic representation, showing the absolute volatility in price points.
* **Percent:** A normalized value, showing the ATR as a percentage of the closing price, which is useful for comparing volatility across different instruments.

## 2. Mathematical Foundations and Calculation Logic

The ATR is based on the concept of the "True Range" (TR), which provides a more comprehensive measure of a single period's volatility.

### Calculation Steps (Algorithm)

1. **Calculate the True Range (TR):** For each bar, the True Range is the **greatest** of the following three values:
    * The current High minus the current Low: $\text{High}_i - \text{Low}_i$
    * The absolute value of the current High minus the previous Close: $\text{Abs}(\text{High}_i - \text{Close}_{i-1})$
    * The absolute value of the current Low minus the previous Close: $\text{Abs}(\text{Low}_i - \text{Close}_{i-1})$

2. **Calculate the Average True Range (ATR):** The ATR is a smoothed moving average of the TR values, calculated using Wilder's specific smoothing method (RMA/SMMA).
    * **Initialization:** The first ATR value is a simple average of the first `N` TR values.
    * **Recursive Calculation:** All subsequent values are calculated using the following formula:
        $\text{ATR}_i = \frac{(\text{ATR}_{i-1} \times (N-1)) + \text{TR}_i}{N}$

3. **Normalize to Percentage (Optional):** If the user selects the "Percent" display mode, the final ATR value is converted to a percentage of the closing price.
    * $\text{ATR\%}_i = \frac{\text{ATR}_i}{\text{Close}_i} \times 100$

*Note: Our smoothing method is the globally accepted standard for ATR. The built-in `iATR` in MetaTrader uses a different, non-standard algorithm.*

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`ATR_Calculator.mqh`):** All core calculation logic is encapsulated within a reusable include file. The engine now includes a final, optional step to convert the result to a percentage based on a user-selected mode.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_tr` and `m_atr_raw`) persist their state between ticks. This allows the recursive Wilder's Smoothing algorithm to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Object-Oriented Design (Inheritance):** A base class, `CATRCalculator`, handles the shared Wilder's smoothing algorithm. A derived class, `CATRCalculator_HA`, overrides only the initial calculation of the raw True Range values to use Heikin Ashi candles.

## 4. Parameters (`ATR_Pro.mq5`)

* **ATR Period (`InpAtrPeriod`):** The lookback and smoothing period for the indicator. Wilder's original recommendation is `14`.
* **Display Mode (`InpDisplayMode`):** Allows the user to select the output format.
  * `ATR_POINTS`: Displays the ATR in absolute price points (default).
  * `ATR_PERCENT`: Displays the ATR as a percentage of the closing price.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the True Range calculation (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

## 5. Usage and Interpretation

* **Volatility Gauge:** A rising ATR indicates that volatility is increasing. A falling ATR indicates that volatility is decreasing.
* **Stop-Loss Placement:** ATR is a cornerstone of risk management. A common technique is to place a stop-loss at a multiple of the ATR (e.g., 2 x ATR) from an entry price.
* **Position Sizing:** ATR can be used to normalize position sizes across different instruments.
* **Cross-Market Volatility Comparison (Percent Mode):** The "Percent" mode is exceptionally useful for comparing the relative volatility of different instruments. For example, you can objectively determine if `EURUSD` (with a 0.5% ATR) is currently more or less volatile than `Gold` (with a 1.2% ATR), regardless of their different price levels.
* **Caution:** ATR does not provide any information about trend direction.
