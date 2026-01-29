# SuperSmoother Adaptive Moving Average (SSAMA)

## 1. Summary (Introduction)

The **SSAMA** is a unique hybrid indicator that combines the adaptive logic of Perry Kaufman's KAMA with the superior filtering characteristics of John Ehlers' SuperSmoother.

While the classic KAMA uses an Efficiency Ratio (ER) to adjust the speed of an Exponential Moving Average (EMA), the SSAMA uses the same ER to dynamically adjust the cutoff frequency (period) of a **2-Pole SuperSmoother Filter**.

This results in a moving average that offers the best of both worlds:

* **Responsiveness:** Like KAMA, it speeds up during strong trends to reduce lag.
* **Smoothness:** Unlike KAMA (which can be angular), the SuperSmoother core ensures that the line remains exceptionally smooth and curvilinear, avoiding the jagged "stair-step" effect often seen in other adaptive averages.

## 2. Mathematical Foundations

The calculation is a multi-step process performed on every bar:

1. **Calculate Efficiency Ratio (ER):**
    * Measures the "noise" vs. "trend" content of the price over the `ER Period`.
    * $ER = \frac{\text{Net Change}}{\text{Sum of Absolute Changes}}$
    * ER approaches 1.0 in a clean trend and 0.0 in pure noise.

2. **Determine Dynamic Period:**
    * The ER is mapped to a period range between `Fast Period` and `Slow Period`.
    * $\text{Current Period} = \text{Fast} + (1 - ER) \times (\text{Slow} - \text{Fast})$
    * *High ER (Trend) -> Fast Period.*
    * *Low ER (Noise) -> Slow Period.*

3. **Calculate SuperSmoother:**
    * The coefficients of the SuperSmoother filter ($c1, c2, c3$) are recalculated for the `Current Period`.
    * The filter is then applied to the price data using these dynamic coefficients.

## 3. MQL5 Implementation Details

* **Dynamic Coefficient Engine:** The `SSAMA_Calculator.mqh` engine is optimized to recalculate the complex trigonometric coefficients of the SuperSmoother filter on-the-fly for every bar without significant performance penalty.
* **O(1) Incremental Calculation:** The indicator processes only new bars, ensuring efficiency.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data.

## 4. Parameters

* **ER Period:** The lookback period for measuring market efficiency (volatility). Default is `10`.
* **Fast Period:** The minimum period the filter can drop to during strong trends. Default is `5`. (Lower values = faster response).
* **Slow Period:** The maximum period the filter can extend to during choppy markets. Default is `50`. (Higher values = smoother line in ranges).
* **Price Source:** Selects the input data (Standard or Heikin Ashi).

## 5. Usage and Interpretation

### Trend Identification

* **Direction:** The slope of the SSAMA line indicates the trend direction. Due to its curvilinear nature, changes in slope are smooth and gradual.
* **Support/Resistance:** In a strong trend, price often pulls back to the SSAMA line before resuming.

### The "Curve" vs. "Angle"

* Traders used to KAMA might notice that SSAMA turns in an **arc** rather than a sharp angle. This is intentional. The SuperSmoother filter is designed to eliminate aliasing noise, which naturally results in a smoother, wave-like path. This can help filter out "whipsaw" breakouts that quickly reverse.

### Range Filtering

* When the market enters a consolidation (low ER), the SSAMA period extends towards the `Slow Period` (e.g., 50). This causes the line to ignore minor fluctuations and stay relatively flat (or gently curved) through the center of the range.
