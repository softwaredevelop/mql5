# Sine Weighted Moving Average (Sine WMA)

## 1. Summary (Introduction)

The Sine Weighted Moving Average (Sine WMA) is a specialized type of weighted moving average that uses a sine wave function to assign weights to price data. It was developed as an advanced smoothing filter, designed to reduce lag and provide a cleaner representation of the market's underlying trend.

Unlike traditional moving averages that are inherently lagging, the Sine WMA is a **symmetrical, zero-lag filter**. It achieves this by assigning the heaviest weights to the price data in the middle of the lookback period, with weights tapering off towards the beginning and end of the period, mirroring the shape of a sine wave.

The result is an exceptionally smooth line that acts as the "center of gravity" for the price action. It is not a trend-following tool in the classic sense but rather a superior smoothing mechanism for identifying the true equilibrium price and filtering out market noise.

## 2. Mathematical Foundations and Calculation Logic

The Sine WMA calculates a weighted average where the weights are derived from a sine function, creating a smooth, bell-shaped weighting curve.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Generate Sine Weights:** For a given period `N`, the weight for each bar `i` (where `i` ranges from 0 to N-1) is calculated using the sine function.
    * $Weight_i = \sin\left(\frac{\pi \cdot (i+1)}{N+1}\right)$

2. **Calculate the Weighted Sum:** For each bar `t`, multiply the last `N` prices by the corresponding sine-based weights.
    * $\text{Weighted Sum}_t = \sum_{i=0}^{N-1} (\text{Price}_{t-i} \cdot Weight_i)$

3. **Calculate the Sum of Weights:** Sum all the generated sine weights.
    * $\text{Sum of Weights} = \sum_{i=0}^{N-1} Weight_i$

4. **Calculate the Final WMA Value:** Divide the weighted sum of prices by the sum of the weights.
    * $\text{Sine WMA}_t = \frac{\text{Weighted Sum}_t}{\text{Sum of Weights}}$

This process results in a symmetrically weighted average that is centered on the data.

## 3. MQL5 Implementation Details

Our MQL5 implementation is a clean and robust indicator that accurately reflects the mathematical definition of a symmetrical, centered filter.

* **Modular, Reusable Calculation Engine (`Sine_WMA_Calculator.mqh`):** The entire calculation logic for both standard and Heikin Ashi versions is encapsulated within a single, powerful include file. This file contains a base `CSineWMACalculator` class and an inherited `CSineWMACalculator_HA` child class, eliminating code duplication and ensuring both versions are always in sync.

* **Efficient Weight Generation:** The sine-based weights are calculated only once during the indicator's initialization in the `Init()` method of the calculator class. The weights and their sum are stored in internal class members for efficient reuse.

* **Stability via Full Recalculation:** In line with our core principles, the indicator employs a "brute-force" full recalculation within the `OnCalculate` function. This is the most reliable method to ensure stability and prevent any potential glitches.

* **Correct Symmetrical Application:** The `Calculate` method applies the pre-calculated symmetrical weights directly to the price data. The weights are **not reversed**. This correctly implements the smoothing, centered nature of the filter. The inherent lag of `(Period-1)/2` bars is a mathematical property of the filter, not an implementation error.

* **Heikin Ashi Variant (`Sine_WMA_HeikinAshi.mq5`):**
  * **As an experiment, a Heikin Ashi version of this indicator was also developed. However, testing revealed that the practical benefit is minimal.**
  * **The "Double Smoothing" Effect:** The Heikin Ashi transformation is, in itself, a powerful smoothing algorithm. Applying a second, strong smoothing filter (the Sine WMA) to an already smoothed data series (HA Close) results in an extremely smooth line, but one that shows negligible difference from the standard version while potentially increasing lag.
  * **Conclusion:** For symmetrical, smoothing-type filters like the Sine WMA, the standard version is recommended as it already provides excellent noise reduction. The Heikin Ashi variant remains in the toolkit as a technical demonstration of our modular calculation engine.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average. A longer period results in a smoother line that is less sensitive to short-term price fluctuations. Default is `21`.
* **Source Price (`InpSourcePrice`):** The price data used for the calculation. **Note: This parameter is ignored by the Heikin Ashi version**, which always uses the HA Close price. Default is `PRICE_CLOSE`.

## 5. Usage and Interpretation

The Sine WMA should be interpreted as a **smoothing filter and a "mean" or "center of gravity" line**, not as a traditional trend-following moving average.

* **Noise Reduction and Trend Clarity:** The primary use of the Sine WMA is to filter out market noise and provide a much clearer picture of the underlying price movement.
* **Mean Reversion Signals:** The line acts as a "magnet" for the price. When the price moves significantly away from the Sine WMA, it can be considered over-extended, increasing the probability of a reversion back towards the line.
* **Confirmation of Trend Direction:** The slope of the Sine WMA provides a very stable, albeit lagging, confirmation of the main trend direction. A change in the slope's direction is a significant event.
* **Caution:** Due to its inherent nature as a centered, smoothing filter, the Sine WMA will always lag the price. It should **not** be used for fast crossover signals. Its strength lies in its smoothness and its ability to define the market's equilibrium point.
