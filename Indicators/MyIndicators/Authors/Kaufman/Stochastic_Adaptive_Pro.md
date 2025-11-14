# Stochastic Adaptive Professional

## 1. Summary (Introduction)

The `Stochastic_Adaptive_Pro` is an implementation of Frank Key's innovative "Variable-Length Stochastic" concept, which was popularized by Perry Kaufman. It is an "intelligent" oscillator that solves a major drawback of the classic Stochastic: its tendency to get "stuck" in overbought or oversold zones during a strong, sustained trend.

This indicator achieves this by dynamically adjusting its own lookback period based on the market's "trendiness," which it measures using **Kaufman's Efficiency Ratio (ER)**.

* In a **strong, trending market**, the indicator automatically **lengthens its period**, becoming less sensitive and helping the trader to stay with the trend.
* In a **choppy, sideways market**, it automatically **shortens its period**, becoming more responsive to identify potential turning points at the edges of the range.

This dual-mode behavior makes it a powerful and versatile tool for both trend-following and range-bound strategies.

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
    * **Calculate Slow %K and %D:** The `Raw %K` is then smoothed using fixed-period moving averages to produce the final %K (main) and %D (signal) lines.

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`Stochastic_Adaptive_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file. The engine first calculates the ER and the adaptive period for the entire history, then calculates the Stochastic using these dynamic period values.

* **Reusable Components:** The engine leverages our universal `CalculateMA` helper function for the final %K and %D smoothing steps, ensuring consistency with our other Stochastic indicators.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

* **Stability via Full Recalculation:** The indicator performs a full recalculation on every tick. This is the most robust approach for a complex, state-dependent indicator where the lookback period itself is constantly changing.

## 4. Parameters

* **ER Period (`InpErPeriod`):** The lookback period for the Efficiency Ratio calculation. Default is `10`.
* **Min Stochastic Period (`InpMinStochPeriod`):** The shortest possible period for the Stochastic, used in choppy markets. Default is `5`.
* **Max Stochastic Period (`InpMaxStochPeriod`):** The longest possible period for the Stochastic, used in strong trends. Default is `30`.
* **Slowing Period (`InpSlowingPeriod`):** The fixed period for the first smoothing of the Raw %K. Default is `3`.
* **%D Period (`InpDPeriod`):** The fixed period for smoothing the main %K line to create the signal line. Default is `3`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.
* **%D MA Type (`InpDMAType`):** The type of moving average for the %D signal line.

## 5. Usage and Interpretation

The key to using this indicator is understanding its dual nature.

* **In Strong Trends:** When the market is moving decisively in one direction, the indicator's period will lengthen. It will stay away from the extreme overbought/oversold zones for longer than a standard Stochastic. This is a feature, not a bug. It helps you **stay in a winning trade** and avoid exiting prematurely on minor pullbacks. Do not look for reversal signals from the extremes during these phases.

* **In Sideways/Ranging Markets:** When the market is choppy, the indicator's period will shorten. Its behavior will become very similar to a fast standard Stochastic. In this mode, it is excellent for identifying potential turning points near the top (>80) and bottom (<20) of the range.

* **Crossovers:** The crossover of the %K and %D lines provides standard bullish and bearish signals, but their reliability is enhanced by the adaptive context. A bullish crossover after the indicator has been in a "slow mode" (trending) and pulls back can be a very powerful trend-continuation signal.
