# Stochastic Adaptive RSI Professional

## 1. Summary (Introduction)

The `Stochastic_Adaptive_RSI_Pro` is a highly advanced, experimental oscillator that combines two powerful adaptive concepts into a single indicator. It takes the logic of the **Stochastic RSI** and merges it with the **variable-length period** mechanism from Frank Key's Adaptive Stochastic.

The result is a "doubly adaptive" oscillator that measures where the RSI is relative to its own highs and lows over a **dynamically changing lookback period**. The period itself adapts to the market's trendiness, which is measured by Kaufman's Efficiency Ratio (ER).

* In a **strong, trending market**, the indicator's lookback period on the RSI lengthens, aiming to reduce premature signals.
* In a **choppy, sideways market**, the period shortens, aiming to increase sensitivity to turns within the range.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a complex, four-stage sequential process.

### Required Components

* **RSI Period (N_rsi):** The lookback period for the base RSI.
* **ER Period (N_er):** The lookback period for the Efficiency Ratio.
* **Min/Max Stochastic Periods (MinP, MaxP):** The range for the adaptive period.
* **Stochastic Smoothing Periods:** Slowing Period and %D Period.

### Calculation Steps (Algorithm)

1. **Calculate the Base RSI:** First, a standard Wilder's RSI is calculated on the source price over the period `N_rsi`.

2. **Calculate the Efficiency Ratio (ER):** Separately, the ER is calculated on the **source price** over the period `N_er`.
    * $\text{ER}_t = \frac{\text{Abs}(P_t - P_{t-N_{er}})}{\sum_{i=0}^{N_{er}-1} \text{Abs}(P_{t-i} - P_{t-i-1})}$

3. **Calculate the Adaptive Stochastic Period (NSP):** The ER is used to calculate the new, dynamic lookback period for the Stochastic on each bar.
    * $\text{NSP}_t = \text{Integer}[(\text{ER}_t \times (\text{MaxP} - \text{MinP})) + \text{MinP}]$

4. **Apply the Slow Stochastic Formula to the RSI with the Adaptive Period:** The standard Slow Stochastic logic is applied to the **RSI series**, but the `Raw %K` is calculated using the dynamic `NSP` for each bar.
    * **Calculate Raw %K (using NSP on RSI):**
        $\text{Highest High} = \text{Highest value of RSI over the last NSP}_t \text{ bars}$
        $\text{Lowest Low} = \text{Lowest value of RSI over the last NSP}_t \text{ bars}$
        $\text{Raw \%K}_t = 100 \times \frac{\text{RSI}_t - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K and %D:** The `Raw %K` is then smoothed using configurable moving averages.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The calculator (`Stochastic_Adaptive_RSI_Calculator.mqh`) orchestrates three powerful engines:
    1. **RSI Engine:** Calculates the base RSI using the shared `RSI_Engine.mqh`.
    2. **Slowing Engine:** Smooths the Raw %K using `MovingAverage_Engine.mqh`.
    3. **Signal Engine:** Calculates the %D line using `MovingAverage_Engine.mqh`.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers (RSI, ER, NSP, Raw %K) persist their state between ticks.

* **Hybrid Heikin Ashi Logic:**
    When using Heikin Ashi prices, the indicator offers a unique "Hybrid" mode via the `Adaptive Source` parameter.
  * **Standard (Recommended):** Calculates RSI on Heikin Ashi, but measures ER (market noise) on Standard prices. This prevents the HA smoothing from artificially inflating the ER.
  * **Heikin Ashi:** Calculates both RSI and ER on Heikin Ashi prices (Pure HA).

## 4. Parameters

* **Adaptive Settings:**
  * `InpRSIPeriod`: RSI Period. (Default: `14`).
  * `InpErPeriod`: ER Period. (Default: `10`).
  * `InpMinStochPeriod`: Min Stochastic Period. (Default: `5`).
  * `InpMaxStochPeriod`: Max Stochastic Period. (Default: `30`).
  * `InpAdaptiveSource`: Selects the source for ER calculation in HA mode (`Standard` or `Heikin Ashi`).
* **Stochastic & Price Settings:**
  * `InpSlowingPeriod`: Smoothing period for Slow %K. (Default: `3`).
  * `InpSlowingMAType`: Smoothing type for Slow %K. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
  * `InpDPeriod`: Smoothing period for %D. (Default: `3`).
  * `InpDMAType`: Smoothing type for %D. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
  * `InpSourcePrice`: Source price for the calculation.

## 5. Usage and Interpretation

The Stochastic Adaptive RSI is a hybrid oscillator with a unique character.

* **Comparison:** It is **smoother** than the standard `Stochastic Adaptive` (because it uses RSI) but **more responsive** than the standard `Stochastic RSI` (because of the adaptive period).
* **Strategy:** Use it to identify overbought/oversold conditions and crossovers, especially in markets that alternate between trending and ranging phases.
