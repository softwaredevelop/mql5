# Jurik Moving Average (JMA)

## 1. Summary (Introduction)

The Jurik Moving Average (JMA) is a high-performance, adaptive moving average developed by Mark Jurik. It is widely regarded as one of the most advanced and effective smoothing filters available to traders. Unlike traditional moving averages that suffer from a trade-off between smoothness and lag, the JMA is designed to be extremely smooth in ranging markets while reacting almost instantly to emerging trends with minimal delay.

This MQL5 implementation is based on a detailed algorithm revealed by Alexander Smirnov, which reverse-engineers the JMA's complex, multi-stage filtering process. The result is an indicator that provides a significantly cleaner and more responsive view of price action compared to classic averages like SMA or EMA. Our implementation is organized into a modular, reusable calculation engine, allowing for the creation of a **complete family of Jurik-based indicators, including standard and Heikin Ashi variants.**

## 2. Mathematical Foundations and Calculation Logic

The JMA is not a simple average; it is a sophisticated, three-stage adaptive filter. Its core strength lies in its ability to dynamically adjust its smoothing factor (`alpha`) based on the market's volatility and cyclical nature.

### Required Components

- **Length (L):** The primary lookback period. It influences the overall smoothness and character of the JMA.
- **Phase (P):** A fine-tuning parameter (-100 to +100) that controls the JMA's tendency to overshoot or undershoot the price during trend changes.
- **Price Data:** The source price series (typically the `Close` **or the Heikin Ashi Close**).

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

Our MQL5 implementation is designed for maximum stability, clarity, and reusability, adhering to our established development principles.

- **Modular, Reusable Calculation Engine (`Jurik_Calculators.mqh`):** The entire complex JMA algorithm, for both standard and Heikin Ashi data, is encapsulated within a single, powerful include file.
  - **`CJurikMACalculator`**: The base class that performs the calculation on standard OHLC data.
  - **`CJurikMACalculator_HA`**: A child class that **inherits** from the base class. It overrides only one method (`PreparePriceSeries`) to first transform the input data into Heikin Ashi values before passing it to the main JMA algorithm. This elegant, object-oriented approach eliminates code duplication and ensures both versions are always in sync.

- **Stability via Full Recalculation:** The JMA is a highly recursive and state-dependent indicator. To ensure perfect accuracy and prevent any risk of calculation errors, all our Jurik indicators employ a "brute-force" **full recalculation** on every tick. This is our core principle of prioritizing stability over premature optimization.

- **Clear, Staged Calculation:** Inside the calculator classes, the algorithm is implemented in a clear, sequential manner. Each major component (`Volty`, `alpha`, `MA1`, `JMA`, etc.) is stored in its own internal array, which makes the code highly readable and significantly easier to debug.

- **Robust Initialization:** All recursive calculations are carefully initialized. The loops start from the second bar (`i = 1`), and the values for the first bar (`i = 0`) are explicitly set to stable, logical starting points.

- **The Jurik Indicator Family:** Our modular engine allows for a complete family of indicators:
  - **`Jurik_MA.mq5` / `Jurik_MA_HeikinAshi.mq5`**: The main indicators that display the final JMA line.
  - **`Jurik_Bands.mq5` / `Jurik_Bands_HeikinAshi.mq5`**: Diagnostic tools that display the Jurik Bands.
  - **`Jurik_Volatility.mq5` / `Jurik_Volatility_HeikinAshi.mq5`**: Diagnostic tools that display the calculated `Volty`.

## 4. Parameters

- **Length (`InpLength`):** The main lookback period for the JMA. It controls the overall smoothness. Longer lengths result in a smoother, slower JMA, while shorter lengths make it more responsive. Default is `14`.
- **Phase (`InpPhase`):** A fine-tuning parameter that controls the JMA's behavior at turning points. The valid range is from -100 to +100. Default is `0`.
  - `Phase > 0`: Makes the JMA more aggressive (overshoots price).
  - `Phase < 0`: Makes the JMA more conservative (undershoots price).
  - `Phase = 0`: A neutral, balanced setting.

## 5. Usage and Interpretation

- **Trend Filter:** The JMA's primary use is as a superior, low-lag trend filter. The direction of the JMA's slope indicates the current trend.
- **Dynamic Support and Resistance:** In trending markets, the JMA line itself often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend).
- **Crossover Signals:** The crossover of the price and the JMA line provides entry and exit signals that are typically much earlier than those from traditional moving averages.

**Recommended Parameter Usage (Standard Practice):**

- **Start with `Phase = 0`**: For most applications, the neutral phase setting provides the best balance. Only adjust this parameter if you have a specific strategic reason to make the indicator more aggressive or conservative.
- **Adjust `Length` based on your trading style and timeframe:**
  - **Scalping (M1-M5):** Use a short `Length` (e.g., **7-20**) to capture very short-term momentum.
  - **Day Trading (M15-H1):** Use a medium `Length` (e.g., **21-50**). A value of **50** is a widely used and robust starting point for identifying significant intraday trends.
  - **Swing Trading (H4-D1):** Use a long `Length` (e.g., **60-100+**) to filter out daily noise and focus on the primary, multi-day trend.

- **Heikin Ashi Variant:** The `_HeikinAshi` version is recommended for traders who want an even smoother signal. The HA data pre-filters some of the price noise before it even reaches the JMA algorithm, resulting in an exceptionally clean trend line, which can be particularly useful in volatile markets.

- **Caution:** While the JMA is a powerful tool, no indicator is perfect. Its adaptiveness can sometimes be a weakness in extremely volatile, "whipsaw" markets. It is most effective when combined with other forms of analysis.
