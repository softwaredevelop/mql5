# Average Directional Index (ADX) Pro

## 1. Summary (Introduction)

The Average Directional Index (ADX), developed by J. Welles Wilder, is a widely used technical indicator designed to measure the **strength of a trend**, regardless of its direction. It does not indicate whether the trend is bullish or bearish, but only quantifies its momentum.

The ADX system consists of three lines:

* **ADX Line:** The main line that indicates trend strength.
* **+DI (Positive Directional Indicator):** A line that measures the strength of the upward price movement.
* **-DI (Negative Directional Indicator):** A line that measures the strength of the downward price movement.

Our `ADX_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** candles.

## 2. Mathematical Foundations and Calculation Logic

The ADX calculation is a complex, multi-stage process that relies heavily on Wilder's smoothing technique (a specific type of Smoothed or Running Moving Average - SMMA/RMA).

### Required Components

* **ADX Period (N):** The lookback period for all calculations (e.g., 14).
* **Directional Movement (+DM, -DM):** Measures the portion of the current bar's range that is outside the previous bar's range.
* **True Range (TR):** The standard measure of a single bar's volatility.

### Calculation Steps (Algorithm)

1. **Calculate Directional Movement and True Range:** For each period, calculate:

    * $\text{Up Move} = \text{High}_i - \text{High}_{i-1}$
    * $\text{Down Move} = \text{Low}_{i-1} - \text{Low}_i$
    * If $\text{Up Move} > \text{Down Move}$ and $\text{Up Move} > 0$, then $\text{+DM} = \text{Up Move}$, else $\text{+DM} = 0$.
    * If $\text{Down Move} > \text{Up Move}$ and $\text{Down Move} > 0$, then $\text{-DM} = \text{Down Move}$, else $\text{-DM} = 0$.
    * $\text{True Range (TR)} = \text{Max}[(\text{High}_i - \text{Low}_i), \text{Abs}(\text{High}_i - \text{Close}_{i-1}), \text{Abs}(\text{Low}_i - \text{Close}_{i-1})]$

2. **Smooth +DM, -DM, and TR:** Apply Wilder's smoothing method over the period `N`.

    * **Initialization:** The first value is the sum of the first `N` periods.
        $\text{Smoothed +DM}_{N} = \sum_{i=1}^{N} \text{+DM}_i$
    * **Recursive Calculation:**
        $\text{Smoothed +DM}_i = \text{Smoothed +DM}_{i-1} - \frac{\text{Smoothed +DM}_{i-1}}{N} + \text{+DM}_i$
    * *(The same logic applies to -DM and TR)*

3. **Calculate Directional Indicators (+DI, -DI):**
    $\text{+DI}_i = 100 \times \frac{\text{Smoothed +DM}_i}{\text{Smoothed TR}_i}$
    $\text{-DI}_i = 100 \times \frac{\text{Smoothed -DM}_i}{\text{Smoothed TR}_i}$

4. **Calculate the Directional Index (DX):**
    $\text{DX}_i = 100 \times \frac{\text{Abs}(\text{+DI}_i - \text{-DI}_i)}{\text{+DI}_i + \text{-DI}_i}$

5. **Calculate the Final ADX:** The ADX is a Wilder-smoothed moving average of the DX.
    * **Initialization:** The first ADX value is a simple average of the first `N` DX values.
    * **Recursive Calculation:**
        $\text{ADX}_i = \frac{(\text{ADX}_{i-1} \times (N-1)) + \text{DX}_i}{N}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file, a dedicated calculator engine, and a shared core engine.

* **Shared Core Engine (`DMI_Engine.mqh`):**
    The fundamental calculation of Directional Movement (+DI, -DI) is outsourced to a shared engine. This ensures that both the ADX and the DMI Stochastic indicators use the exact same, validated mathematical core, eliminating code duplication and potential inconsistencies.

* **Modular Calculator Engine (`ADX_Calculator.mqh`):**
    The ADX-specific logic (calculating the DX and smoothing it to get the ADX) is encapsulated here. This calculator orchestrates the `DMI_Engine` to get the raw data and then performs the final steps.

* **Object-Oriented Design (Composition & Inheritance):**
  * The `CADXCalculator` uses **Composition** to include the `CDMIEngine`.
  * The Heikin Ashi support is implemented via a **Factory Pattern** in the `CADXCalculator_HA` subclass, which instantiates a specialized `CDMIEngine_HA`. This keeps the main logic clean and agnostic of the data source.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * The internal buffers persist their state between ticks, allowing the recursive Wilder's Smoothing algorithm to continue seamlessly from the last known value.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag.

## 4. Parameters (`ADX_Pro.mq5`)

* **ADX Period (`InpPeriodADX`):** The lookback period used for all internal calculations. Wilder's original recommendation and the most common value is `14`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the initial calculation of directional movement.
  * `CANDLE_STANDARD`: Uses the standard chart's OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data.

## 5. Usage and Interpretation

* **Trend Strength:** The primary signal is the ADX line itself.
  * **ADX < 25:** Weak or non-existent trend (ranging market). Trend-following strategies should be avoided.
  * **ADX > 25:** Strong trend. The higher the ADX, the stronger the trend.
  * **Rising ADX:** The trend is gaining strength.
  * **Falling ADX:** The trend is losing strength.
* **Trend Direction (+DI and -DI Crossover):**
  * When the **+DI line (green) crosses above the -DI line (red)**, it suggests the start of a bullish trend.
  * When the **-DI line (red) crosses above the +DI line (green)**, it suggests the start of a bearish trend.
* **Trade Confirmation:** A common strategy is to wait for a +DI/-DI crossover and then confirm that the ADX line is above 25 (or rising) before entering a trade. This helps to filter out signals that occur in weak or non-trending markets.
