# FRAMA Professional (Fractal Adaptive Moving Average)

## 1. Summary (Introduction)

The FRAMA (Fractal Adaptive Moving Average), developed by John Ehlers, is a unique adaptive moving average that adjusts its smoothing period based on the **fractal dimension** of the market.

The core concept is that financial markets exhibit fractal properties. By measuring the "roughness" or "smoothness" of price action over a given period, the indicator can determine if the market is trending or consolidating.

* In a **trending market**, which resembles a straight line, the fractal dimension approaches 1. The FRAMA responds by becoming a **very fast** moving average to closely track the price.
* In a **congested, sideways market**, which is more "space-filling," the fractal dimension approaches 2. The FRAMA responds by becoming a **very slow**, almost flat moving average to filter out the noise of the range.

This results in a moving average that dynamically switches between fast and slow modes based on the market's fractal geometry.

## 2. Mathematical Foundations and Calculation Logic

The FRAMA is an Exponential Moving Average where the smoothing factor (`alpha`) is dynamically calculated on every bar based on the measured fractal dimension.

### Calculation Steps (Algorithm)

1. **Period Division:** The lookback period `N` is divided into two equal halves of length `N/2`.
2. **"Box Count" Estimation (N1, N2, N3):** The fractal dimension calculation requires estimating the "box count," which Ehlers approximates using the price range over different intervals.
    * `N1` = Range (High - Low) over the most recent `N/2` bars, divided by `N/2`.
    * `N2` = Range (High - Low) over the oldest `N/2` bars, divided by `N/2`.
    * `N3` = Range (High - Low) over the entire `N` bars, divided by `N`.
3. **Fractal Dimension (D) Calculation:** The fractal dimension is calculated from the logarithms of the N-values:
    $D = \frac{\ln(N1 + N2) - \ln(N3)}{\ln(2)}$
4. **Adaptive Alpha Calculation:** The calculated dimension `D` (which ranges from 1 to 2) is converted into an EMA smoothing factor `alpha`:
    $\alpha = e^{-4.6 \times (D - 1)}$
    This formula maps `D=1` to `alpha=1` (fastest) and `D=2` to `alpha≈0.01` (slowest). The result is then clamped between 0.01 and 1.
5. **FRAMA Calculation:** The final indicator value is calculated using the standard EMA formula with the adaptive `alpha`:
    $\text{FRAMA}_i = \alpha \times \text{Price}_i + (1 - \alpha) \times \text{FRAMA}_{i-1}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`FRAMA_Calculator.mqh`):** The entire multi-stage calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data, using the HA High/Low for the range calculations and the selected HA price for the final EMA.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call. This is the most robust method for this state-dependent indicator.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the fractal dimension calculation. This must be an **even number**. Ehlers' default is **16**. A longer period will result in a smoother, slower-adapting FRAMA.
* **Applied Price (`InpSourcePrice`):** The source price for the final EMA calculation. The fractal dimension is always calculated on the High/Low range of the selected candle type (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The FRAMA should be used as an adaptive trendline that provides clear signals about the market's state (trending vs. ranging).

* **Trend Identification:**
  * When the FRAMA line is **steeply angled and closely follows the price**, it indicates a strong trend (Fractal Dimension is near 1).
  * When the FRAMA line becomes **flat and slow-moving**, it indicates a consolidating or ranging market (Fractal Dimension is near 2). This is a signal to avoid trend-following strategies.
* **Dynamic Support and Resistance:** Like other moving averages, the FRAMA can act as a dynamic level of support in an uptrend and resistance in a downtrend.
* **Crossover Signals:** A crossover of the price and the FRAMA line can be used as a trade signal. However, due to the indicator's nature, these signals can be tricky.
  * A crossover during a **fast, trending phase** is a significant signal.
  * A crossover during a **flat, ranging phase** is likely to be a whipsaw and should be treated with caution.

**Practical Considerations:**
The FRAMA's rapid switching between fast and slow modes can sometimes produce a "jerky" or "angular" appearance. While this accurately reflects the change in the market's fractal dimension, it may be less visually intuitive than other adaptive moving averages like MAMA. It is best used to identify the **change in market state** from trending to ranging, and vice versa.
