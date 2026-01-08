# Stochastic Adaptive RSI Professional

## 1. Summary (Introduction)

The `StochRSI_Adaptive_Pro` is a cutting-edge momentum oscillator that fuses two powerful concepts: the **Adaptive RSI** (Dynamic Momentum Index) and the **Stochastic Oscillator**.

While a standard Stochastic RSI applies the Stochastic formula to a fixed-period RSI, this indicator applies it to an **Adaptive RSI**. This means the underlying RSI's lookback period is constantly changing based on market volatility (measured by Kaufman's Efficiency Ratio).

* In **high volatility (trends)**, the base RSI speeds up, and the Stochastic reacts faster to momentum shifts.
* In **low volatility (ranges)**, the base RSI slows down, and the Stochastic becomes smoother, filtering out noise.

The result is a highly responsive yet robust oscillator that adapts its sensitivity to the current market regime.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a sophisticated, multi-stage chain.

### Required Components

* **Adaptive RSI Parameters:** Pivotal Period, Volatility Periods (Short/Long).
* **Stochastic Parameters:** %K Period, Slowing Period, %D Period.

### Calculation Steps (Algorithm)

1. **Calculate Efficiency Ratio (ER):** Measure the market's signal-to-noise ratio.
2. **Determine Adaptive Period (NSP):** Adjust the RSI's lookback period based on the ER.
    * High Volatility -> Short Period.
    * Low Volatility -> Long Period.
3. **Calculate Adaptive RSI:** Compute the RSI using the dynamic `NSP` for each bar.
4. **Apply Stochastic Formula:**
    * **Raw %K:** Normalize the Adaptive RSI value within its recent range (over `%K Period`).
        $\text{Raw \%K}_t = 100 \times \frac{\text{AdaptiveRSI}_t - \text{LowestRSI}}{\text{HighestRSI} - \text{LowestRSI}}$
    * **Slow %K:** Smooth the Raw %K using the selected Moving Average (e.g., SMA).
    * **%D (Signal Line):** Smooth the Slow %K using the selected Moving Average.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based design.

* **Triple Engine Architecture:** The calculator (`StochRSI_Adaptive_Calculator.mqh`) orchestrates three powerful engines:
    1. **Adaptive RSI Engine:** Calculates the base volatility-adjusted RSI.
    2. **Slowing Engine:** Smooths the Raw %K using `MovingAverage_Engine.mqh`.
    3. **Signal Engine:** Calculates the %D line using `MovingAverage_Engine.mqh`.

* **Optimized Incremental Calculation (O(1)):**
    Despite the complexity, the indicator calculates incrementally.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers (ER, NSP, RSI, Raw %K) persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Hybrid Heikin Ashi Logic:**
    When using Heikin Ashi prices, the indicator offers a unique "Hybrid" mode via the `Adaptive Source` parameter.
  * **Standard (Recommended):** Calculates RSI on Heikin Ashi, but measures Volatility (market noise) on Standard prices.
  * **Heikin Ashi:** Calculates both RSI and Volatility on Heikin Ashi prices.

## 4. Parameters

* **Adaptive RSI Settings:**
  * `InpPivotalPeriod`: The central RSI period. (Default: `14`).
  * `InpVolaShort`: Short-term volatility lookback. (Default: `5`).
  * `InpVolaLong`: Long-term volatility lookback. (Default: `10`).
  * `InpAdaptiveSource`: Selects the source for Volatility calculation in HA mode (`Standard` or `Heikin Ashi`).
* **Stochastic Settings:**
  * `InpKPeriod`: Lookback for finding Highest/Lowest RSI. (Default: `14`).
  * `InpSlowingPeriod`: Smoothing period for Slow %K. (Default: `3`).
  * `InpSlowingMAType`: Smoothing type for Slow %K. (Default: `SMA`).
  * `InpDPeriod`: Smoothing period for %D. (Default: `3`).
  * `InpDMAType`: Smoothing type for %D. (Default: `SMA`).
* **Price Source:**
  * `InpSourcePrice`: Source price for the calculation.

## 5. Usage and Interpretation

* **Overbought/Oversold:** Use the 20/80 levels. The adaptive nature helps the indicator reach these levels more accurately during trends without getting "stuck" as easily as a standard StochRSI.
* **Crossovers:** The %K crossing the %D is a standard signal.
* **Divergence:** Look for divergences between the indicator and price, especially when the indicator is in extreme zones.
