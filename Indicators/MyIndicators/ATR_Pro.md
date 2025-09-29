# Average True Range (ATR) Professional

## 1. Summary (Introduction)

The Average True Range (ATR) is a technical analysis indicator developed by J. Welles Wilder. The ATR is not used to indicate price direction; rather, it is a measure of **volatility**.

It calculates the "true range" for each period and then smooths these values, providing a representation of the average size of the price range over a given time. High ATR values indicate high volatility, while low ATR values indicate low volatility.

Our `ATR_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** candles.

## 2. Mathematical Foundations and Calculation Logic

The ATR is based on the concept of the "True Range" (TR), which provides a more comprehensive measure of a single period's volatility than the simple High-Low range.

### Required Components

* **Period (N):** The lookback period for the smoothing calculation (e.g., 14).
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the True Range (TR):** For each bar, the True Range is the **greatest** of the following three values:

    * The current High minus the current Low: $\text{High}_i - \text{Low}_i$
    * The absolute value of the current High minus the previous Close: $\text{Abs}(\text{High}_i - \text{Close}_{i-1})$
    * The absolute value of the current Low minus the previous Close: $\text{Abs}(\text{Low}_i - \text{Close}_{i-1})$
        $\text{TR}_i = \text{Max}[(\text{High}_i - \text{Low}_i), \text{Abs}(\text{High}_i - \text{Close}_{i-1}), \text{Abs}(\text{Low}_i - \text{Close}_{i-1})]$

2. **Calculate the Average True Range (ATR):** The ATR is a smoothed moving average of the True Range values, calculated using Wilder's specific smoothing method (RMA/SMMA).
    * **Initialization:** The first ATR value is a simple average of the first `N` TR values.
        $\text{ATR}_{N} = \frac{1}{N} \sum_{i=1}^{N} \text{TR}_i$
    * **Recursive Calculation:** All subsequent values are calculated using the following formula:
        $\text{ATR}_i = \frac{(\text{ATR}_{i-1} \times (N-1)) + \text{TR}_i}{N}$

*Note: This smoothing method is the globally accepted standard for ATR. The built-in `iATR` in MetaTrader uses a different, non-standard smoothing algorithm.*

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`ATR_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CATRCalculator`, handles the **shared Wilder's smoothing algorithm**.
  * A derived class, `CATRCalculator_HA`, inherits from the base class and **overrides** only one specific function: the initial calculation of the raw True Range values. Its sole responsibility is to use Heikin Ashi candles for this first step and pass the results to the base class's shared smoothing algorithm. This is a clean and efficient use of polymorphism.

* **Simplified Main Indicator (`ATR_Pro.mqh`):**
    The main indicator file is now extremely clean. Its primary roles are:
    1. Handling user inputs (`input` variables).
    2. Instantiating the correct calculator object (`CATRCalculator` or `CATRCalculator_HA`) in `OnInit()` based on the user's choice.
    3. Delegating the entire calculation process to the calculator object with a single call in `OnCalculate()`.

* **Stability via Full Recalculation:** We use a full recalculation on every tick. For a recursive indicator like ATR, this "brute-force" approach is the most robust method, eliminating potential errors from `prev_calculated` logic.

## 4. Parameters (`ATR_Pro.mq5`)

* **ATR Period (`InpAtrPeriod`):** The lookback and smoothing period for the indicator. Wilder's original recommendation and the most common value is `14`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the True Range calculation.
  * `CANDLE_STANDARD`: Uses the standard chart's OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data.

## 5. Usage and Interpretation

* **Volatility Gauge:** The ATR's primary function is to measure volatility. A rising ATR indicates that volatility is increasing, meaning daily trading ranges are widening. A falling ATR indicates that volatility is decreasing.
* **Stop-Loss Placement:** ATR is a cornerstone of modern risk management. A common technique is to place a stop-loss at a multiple of the ATR (e.g., 2 x ATR) below a long entry price or above a short entry price.
* **Position Sizing:** ATR can be used to normalize position sizes across different instruments. By calculating a position size based on a fixed risk amount and the instrument's ATR, a trader can take on similar levels of risk.
* **Caution:** ATR does not provide any information about trend direction. It should always be used in conjunction with other trend or momentum indicators.
