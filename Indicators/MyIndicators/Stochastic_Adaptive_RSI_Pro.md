# Stochastic Adaptive RSI Professional

## 1. Summary (Introduction)

The `Stochastic_Adaptive_RSI_Pro` is a highly advanced, experimental oscillator that combines two powerful adaptive concepts into a single indicator. It takes the logic of the **Stochastic RSI** and merges it with the **variable-length period** mechanism from Frank Key's Adaptive Stochastic.

The result is a "doubly adaptive" oscillator that measures where the RSI is relative to its own highs and lows over a **dynamically changing lookback period**. The period itself adapts to the market's trendiness, which is measured by Kaufman's Efficiency Ratio (ER).

* In a **strong, trending market**, the indicator's lookback period on the RSI lengthens, aiming to reduce premature signals.
* In a **choppy, sideways market**, the period shortens, aiming to increase sensitivity to turns within the range.

This indicator explores the concept of applying adaptive techniques to an already smoothed data series (the RSI), resulting in a unique, hybrid momentum profile.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a complex, four-stage sequential process.

### Required Components

* **RSI Period (N_rsi):** The lookback period for the base RSI.
* **ER Period (N_er):** The lookback period for the Efficiency Ratio.
* **Min/Max Stochastic Periods (MinP, MaxP):** The range for the adaptive period.
* **Stochastic Smoothing Periods:** Slowing Period and %D Period.

### Calculation Steps (Algorithm)

1. **Calculate the Base RSI:** First, a standard Wilder's RSI is calculated on the source price over the period `N_rsi`. This creates the primary data series for the oscillator.

2. **Calculate the Efficiency Ratio (ER):** Separately, the ER is calculated on the **source price** over the period `N_er` to measure the market's trendiness.
    * $\text{ER}_t = \frac{\text{Abs}(P_t - P_{t-N_{er}})}{\sum_{i=0}^{N_{er}-1} \text{Abs}(P_{t-i} - P_{t-i-1})}$

3. **Calculate the Adaptive Stochastic Period (NSP):** The ER is used to calculate the new, dynamic lookback period for the Stochastic on each bar.
    * $\text{NSP}_t = \text{Integer}[(\text{ER}_t \times (\text{MaxP} - \text{MinP})) + \text{MinP}]$

4. **Apply the Slow Stochastic Formula to the RSI with the Adaptive Period:** The standard Slow Stochastic logic is applied to the **RSI series**, but the `Raw %K` is calculated using the dynamic `NSP` for each bar.
    * **Calculate Raw %K (using NSP on RSI):**
        $\text{Highest High} = \text{Highest value of RSI over the last NSP}_t \text{ bars}$
        $\text{Lowest Low} = \text{Lowest value of RSI over the last NSP}_t \text{ bars}$
        $\text{Raw \%K}_t = 100 \times \frac{\text{RSI}_t - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K and %D:** The `Raw %K` is then smoothed using fixed-period moving averages.

## 3. MQL5 Implementation Details

* **Modular and Composite Design:** The `Stochastic_Adaptive_RSI_Calculator.mqh` uses a composition-based design. It **contains an instance** of our robust `CRSIProCalculator` to generate the base RSI data, and it reuses the ER calculation logic from our KAMA implementation.

* **Reusable Components:** The calculator leverages our universal `CalculateMA` helper function for the final %K and %D smoothing steps.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **RSI Period (`InpRSIPeriod`):** The lookback period for the base RSI calculation.
* **ER Period (`InpErPeriod`):** The lookback period for the Efficiency Ratio calculation.
* **Min Stochastic Period (`InpMinStochPeriod`):** The shortest possible period for the Stochastic on the RSI.
* **Max Stochastic Period (`InpMaxStochPeriod`):** The longest possible period for the Stochastic on the RSI.
* **Slowing/D Periods:** The fixed periods for the final smoothing steps.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.
* **%D MA Type (`InpDMAType`):** The type of moving average for the %D signal line.

## 5. Usage and Interpretation

The Stochastic Adaptive RSI is a hybrid oscillator with a unique character. Its behavior is a blend of the `Stochastic RSI` and the `Stochastic Adaptive` indicators.

* **Comparison to its "Parents":**
  * It is **smoother** than the standard `Stochastic Adaptive` (which is based on raw price) because its input is the already-smoothed RSI line.
  * It is **more responsive and "jagged"** than the standard `Stochastic RSI` (which uses a fixed period) because its lookback period is constantly changing.

* **Interpreting the Behavior:** This indicator attempts to find a middle ground. It aims to provide the "trend-following" benefit of the adaptive period while working on a less noisy data series (RSI). However, this "double processing" (smoothing from RSI + adaptive period) can sometimes lead to a "hyper-refined" signal that may lose some of the raw power of its simpler counterparts.

* **Strategy:** It should be used like other Stochastic oscillators, looking for:
  * **Overbought (>80) and Oversold (<20)** conditions.
  * **Crossovers** of the %K and %D lines for entry/exit signals.
  * **Divergences** with price.

It is best used by traders who find the standard `Stochastic RSI` too slow but the standard `Stochastic Adaptive` too noisy for their particular strategy or timeframe.
