# Stochastic Adaptive Professional

## 1. Summary (Introduction)

The `Stochastic_Adaptive_Pro` is an implementation of Frank Key's innovative "Variable-Length Stochastic" concept. It is an "intelligent" oscillator that solves a major drawback of the classic Stochastic: its tendency to get "stuck" in overbought or oversold zones during a strong, sustained trend.

This indicator achieves this by dynamically adjusting its own lookback period based on the market's "trendiness," which it measures using **Kaufman's Efficiency Ratio (ER)**.

* In a **strong, trending market** (High ER), the indicator automatically **lengthens its period**. This desensitizes the oscillator, preventing it from hitting extremes too early and helping the trader stay with the trend.
* In a **choppy, sideways market** (Low ER), it automatically **shortens its period**. This makes it more responsive, allowing it to identify potential turning points at the edges of the range.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a multi-stage process that combines Kaufman's ER with the classic Slow Stochastic formula.

### Required Components

* **ER Period (N):** The lookback period for the Efficiency Ratio.
* **Min/Max Stochastic Periods (MinP, MaxP):** The range within which the Stochastic period can vary.
* **Stochastic Smoothing Periods:** Slowing Period and %D Period.

### Calculation Steps (Algorithm)

1. **Calculate the Efficiency Ratio (ER):** First, the ER is calculated over period `N` to measure the market's signal-to-noise ratio. The result is a value between 0 (pure noise) and 1 (perfect trend).
    * $\text{ER}_t = \frac{\text{Abs}(P_t - P_{t-N})}{\sum_{i=0}^{N-1} \text{Abs}(P_{t-i} - P_{t-i-1})}$

2. **Calculate the Adaptive Stochastic Period (NSP):** The ER is then used to calculate the new, dynamic lookback period for the Stochastic on each bar.
    * $\text{NSP}_t = \text{Integer}[(\text{ER}_t \times (\text{MaxP} - \text{MinP})) + \text{MinP}]$

3. **Apply the Slow Stochastic Formula with the Adaptive Period:** The standard Slow Stochastic logic is applied, but the crucial difference is that the `Raw %K` is calculated using the dynamic `NSP` for each bar.
    * **Calculate Raw %K (using NSP):**
        $\text{Highest High} = \text{Highest Price over the last NSP}_t \text{ bars}$
        $\text{Lowest Low} = \text{Lowest Price over the last NSP}_t \text{ bars}$
        $\text{Raw \%K}_t = 100 \times \frac{P_t - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K and %D:** The `Raw %K` is then smoothed using configurable moving averages to produce the final %K (main) and %D (signal) lines.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Modular Calculation Engine (`Stochastic_Adaptive_Calculator.mqh`):**
    All mathematical logic is encapsulated in a dedicated include file.
  * **Engine Integration:** The calculator internally uses two instances of our universal `MovingAverage_Engine.mqh` to handle the smoothing of the Slow %K and the %D Signal Line. This allows for advanced smoothing types (like DEMA or TEMA) beyond the standard SMA.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers (for ER, NSP, Raw %K) persist their state between ticks.
  * **Dynamic Lookback Handling:** The algorithm correctly handles the variable lookback period during incremental updates, ensuring efficiency without sacrificing accuracy.

* **Object-Oriented Design:**
  * The Heikin Ashi version (`CStochasticAdaptiveCalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the data preparation module.

## 4. Parameters

* **Adaptive Settings:**
  * `InpErPeriod`: The lookback period for the Efficiency Ratio calculation. (Default: `10`).
  * `InpMinStochPeriod`: The shortest possible period for the Stochastic. (Default: `5`).
  * `InpMaxStochPeriod`: The longest possible period for the Stochastic. (Default: `30`).
* **Stochastic & Price Settings:**
  * `InpSlowingPeriod`: The smoothing period for the main Slow %K line. (Default: `3`).
  * `InpSlowingMAType`: The MA type for the "Slowing" step. (Default: `SMA`).
  * `InpDPeriod`: The smoothing period for the final signal line (%D). (Default: `3`).
  * `InpDMAType`: The MA type for the "%D" step. (Default: `SMA`).
  * `InpSourcePrice`: The source price for the calculation. (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The key to using this indicator is understanding its dual nature.

* **In Strong Trends:** When the market is moving decisively in one direction, the indicator's period will lengthen. It will stay away from the extreme overbought/oversold zones for longer than a standard Stochastic. This helps you **stay in a winning trade** and avoid exiting prematurely on minor pullbacks.

* **In Sideways/Ranging Markets:** When the market is choppy, the indicator's period will shorten. Its behavior will become very similar to a fast standard Stochastic. In this mode, it is excellent for identifying potential turning points near the top (>80) and bottom (<20) of the range.
