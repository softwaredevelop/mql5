# Jurik Moving Average Pro (JMA Pro)

## 1. Summary (Introduction)

The **Jurik Moving Average Pro (JMA Pro)** is a high-performance, adaptive moving average developed for the Professional MQL5 Indicator Suite. It is widely regarded as one of the most advanced and effective smoothing filters available to traders. Unlike traditional moving averages that suffer from a trade-off between smoothness and lag, the JMA is designed to be extremely smooth in ranging markets while reacting almost instantly to emerging trends with minimal delay.

This implementation is based on a detailed algorithm revealed by Alexander Smirnov but has been **completely re-engineered for professional use**. Key improvements include:

* **O(1) Incremental Calculation:** Optimized to process only new bars, ensuring zero lag and minimal CPU usage even on heavy charts.
* **Unified Heikin Ashi Support:** Built-in support for all Heikin Ashi price types (Close, Open, High, Low, Median, Typical, Weighted) without needing separate indicators.
* **Modular Architecture:** Powered by a robust, reusable calculation engine (`Jurik_Calculator.mqh`).

## 2. Mathematical Foundations and Calculation Logic

The JMA is not a simple average; it is a sophisticated, three-stage adaptive filter. Its core strength lies in its ability to dynamically adjust its smoothing factor (`alpha`) based on the market's volatility and cyclical nature.

### Required Components

* **Length (L):** The primary lookback period. It influences the overall smoothness and character of the JMA.
* **Phase (P):** A fine-tuning parameter (-100 to +100) that controls the JMA's tendency to overshoot or undershoot the price during trend changes.
* **Price Data:** The source price series, selectable from Standard (Close, Open, etc.) or Heikin Ashi (HA Close, HA Median, etc.) sources.

### Calculation Steps (Algorithm)

1. **Calculate Jurik Volatility (`Volty`):** This is the cornerstone of the JMA. It's a unique volatility metric derived from a recursive process involving "Jurik Bands". These bands adapt to price movement, and the `Volty` is calculated as the maximum distance of the current price from the previous bar's upper or lower band.

2. **Calculate the Dynamic Factor (`alpha`):**
    a. The `Volty` is smoothed over the `Length` period to get an average volatility (`AvgVolty`).
    b. The ratio of the current `Volty` to the `AvgVolty` gives the Relative Volatility (`rVolty`).
    c. This `rVolty` is then used in a series of logarithmic and power functions to calculate the final dynamic smoothing constant, `alpha`. A high `rVolty` (trending market) results in a low `alpha` (fast, responsive average), while a low `rVolty` (ranging market) results in a high `alpha` (slow, smooth average).

3. **Calculate the Phase Ratio (`PR`):** The `Phase` input parameter is transformed into a Phase Ratio (`PR`) that controls the magnitude of the second filtering stage.

4. **Perform the Three-Stage Filtering:**
    a. **Stage 1 (Adaptive EMA):** The price is first smoothed using an EMA-like formula, but with the dynamic `alpha` as its smoothing constant.
    b. **Stage 2 (Kalman Filter-like Correction):** A "detrended" series is calculated and multiplied by the `PR` to create a phase-corrected average. This step helps the JMA to "lead" the price slightly at turning points.
    c. **Stage 3 (Final Jurik Adaptive Filter):** A final, unique filtering stage is applied, which uses `alpha` in a squared form to achieve extreme smoothness while retaining responsiveness. The final result is the JMA line.
       $\text{JMA}_i = \text{JMA}_{i-1} + \text{Det1}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed for maximum performance, stability, and modularity, adhering to the **2026 Professional Suite Standards**.

* **Incremental Calculation (O(1)):** Unlike basic implementations that recalculate the entire history on every tick, this version uses `prev_calculated` to process only the newest bars. This is critical for performance when running on multiple charts or during optimization.

* **Stateful Calculation Engine (`Jurik_Calculator.mqh`):** The logic is encapsulated in a stateful class that persists intermediate values (`m_ma1`, `m_det0`, etc.) between ticks.
  * **`CJurik_Calculator`**: The base engine for standard price calculations.
  * **`CJurik_Calculator_HA`**: An optimized subclass that handles Heikin Ashi transformation internally before passing the data to the JMA algorithm.

* **Unified Indicator Wrapper (`Jurik_MA_Pro.mq5`):** A single file handles all user interactions. It automatically instantiates the correct calculator (Standard or HA) based on the user's input.

* **Robust Initialization:** Constants like `beta`, `kv`, and `pow1` are pre-calculated in the `Init` phase to save CPU cycles during runtime.

## 4. Parameters

* **Length (`InpLength`):** The main lookback period for the JMA. It controls the overall smoothness. Longer lengths result in a smoother, slower JMA, while shorter lengths make it more responsive. Default is `14`.
* **Phase (`InpPhase`):** A fine-tuning parameter that controls the JMA's behavior at turning points. The valid range is from -100 to +100. Default is `0`.
  * `Phase > 0`: Makes the JMA more aggressive (overshoots price).
  * `Phase < 0`: Makes the JMA more conservative (undershoots price).
  * `Phase = 0`: A neutral, balanced setting.
* **Applied Price (`InpPrice`):** Selects the price source.
  * **Standard:** Close, Open, High, Low, Median, Typical, Weighted.
  * **Heikin Ashi:** HA Close, HA Open, HA High, HA Low, HA Median, HA Typical, HA Weighted.

## 5. Usage and Interpretation

* **Trend Filter:** The JMA's primary use is as a superior, low-lag trend filter. The direction of the JMA's slope indicates the current trend.
* **Dynamic Support and Resistance:** In trending markets, the JMA line itself often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend).
* **Crossover Signals:** The crossover of the price and the JMA line provides entry and exit signals that are typically much earlier than those from traditional moving averages.

**Recommended Parameter Usage (Standard Practice):**

* **Start with `Phase = 0`**: For most applications, the neutral phase setting provides the best balance. Only adjust this parameter if you have a specific strategic reason to make the indicator more aggressive or conservative.
* **Adjust `Length` based on your trading style and timeframe:**
  * **Scalping (M1-M5):** Use a short `Length` (e.g., **7-20**) to capture very short-term momentum.
  * **Day Trading (M15-H1):** Use a medium `Length` (e.g., **21-50**). A value of **50** is a widely used and robust starting point for identifying significant intraday trends.
  * **Swing Trading (H4-D1):** Use a long `Length` (e.g., **60-100+**) to filter out daily noise and focus on the primary, multi-day trend.

* **Heikin Ashi Variant:** Selecting a Heikin Ashi price source (e.g., `PRICE_HA_CLOSE`) is recommended for traders who want an even smoother signal. The HA data pre-filters some of the price noise before it even reaches the JMA algorithm, resulting in an exceptionally clean trend line.

* **Caution:** While the JMA is a powerful tool, no indicator is perfect. Its adaptiveness can sometimes be a weakness in extremely volatile, "whipsaw" markets. It is most effective when combined with other forms of analysis.
