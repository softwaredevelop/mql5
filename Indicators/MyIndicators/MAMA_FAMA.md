# MESA Adaptive Moving Average (MAMA & FAMA)

## 1. Summary (Introduction)

The MESA Adaptive Moving Average (MAMA) is a highly sophisticated, adaptive moving average developed by John F. Ehlers, a pioneer in applying Digital Signal Processing (DSP) techniques to financial markets. Unlike traditional averages that have a fixed lookback period, MAMA dynamically adjusts its smoothing factor based on the market's measured cyclicality.

The indicator's core function is to measure the dominant cycle period of the price action in real-time using the Hilbert Transform. It then uses this information to create a moving average that is extremely responsive in trending markets (with fast cycles) and very smooth in sideways markets (with slow cycles), effectively filtering out market noise while minimizing lag.

MAMA is almost always plotted with its companion line, **FAMA (Following Adaptive Moving Average)**. FAMA is a slightly delayed version of MAMA, and the crossover between the two lines provides clear, responsive trading signals. Our MQL5 suite includes two distinct, professionally coded implementations of this system.

## 2. Mathematical Foundations and Calculation Logic

The MAMA algorithm is a multi-stage process rooted in digital signal processing. It translates price movements into wave-like components to measure their cyclical properties.

### Required Components

- **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).
- **Fast Limit (`alpha_fast`):** The maximum allowable value for the adaptive smoothing constant, `alpha`. This corresponds to the alpha of a fast EMA (e.g., 0.5 corresponds to a ~4-period EMA).
- **Slow Limit (`alpha_slow`):** The minimum allowable value for `alpha`, corresponding to a slow EMA (e.g., 0.05 corresponds to a ~39-period EMA).

### Calculation Steps (Algorithm)

1. **Price Pre-processing:** The source price is first lightly smoothed (typically with a 4-period WMA) to remove minor noise.

2. **Hilbert Transform:** This is the core of the cycle measurement. The algorithm applies a series of digital filters to the smoothed price to decompose it into its **In-Phase (I)** and **Quadrature (Q)** components. These two components can be thought of as representing the price wave and a version of that same wave shifted by 90 degrees.

3. **Dominant Cycle Period Measurement:** By analyzing the relationship between the I and Q components (specifically, their arctangent), the algorithm calculates the **Dominant Cycle Period** for each bar. This is a real-time measurement of the market's "rhythm" or "heartbeat". The result is then smoothed and limited to a practical range (e.g., between 6 and 50 bars).

4. **Adaptive Alpha Calculation:** The algorithm calculates the rate of change of the **phase angle** between the I and Q components. This "delta phase" is a measure of the market's instantaneous velocity. The final adaptive smoothing constant, `alpha`, is calculated based on this delta phase, constrained by the `Fast Limit` and `Slow Limit` parameters.
    - A rapid phase change (trending market) results in a larger `alpha` (faster average).
    - A slow phase change (ranging market) results in a smaller `alpha` (smoother average).

5. **Final MAMA and FAMA Calculation:**
    - The MAMA line is calculated using an EMA-like formula, but with the dynamic, adaptive `alpha` for each bar.
        $\text{MAMA}_i = \alpha_i \times \text{Price}_i + (1 - \alpha_i) \times \text{MAMA}_{i-1}$
    - The FAMA line is then calculated as a smoothed version of the MAMA line, using half of the adaptive `alpha`.
        $\text{FAMA}_i = (\alpha_i/2) \times \text{MAMA}_i + (1 - \alpha_i/2) \times \text{FAMA}_{i-1}$

## 3. MQL5 Implementation Details

Our MQL5 suite provides two distinct, high-quality implementations of the MAMA/FAMA system, both built upon a shared, robust, object-oriented framework.

- **Modular, Reusable Calculation Engine (`MESA_Calculator.mqh`):** The entire complex MAMA/FAMA algorithm for both standard and Heikin Ashi data is encapsulated within a single, powerful include file. This file contains two main classes:
  - **`CMESACalculator`**: This class implements the responsive, phase-change-based logic found in popular platforms like TradingView (popularized by LazyBear), which we have validated as being highly effective for generating timely crossover signals.
  - **`CMESACalculator_HA`**: A child class that inherits from the base class. It overrides the data preparation step to first transform the input data into Heikin Ashi values before passing it to the main MAMA algorithm. This object-oriented approach eliminates code duplication and ensures both versions are always in sync.

- **Stability via Full Recalculation:** MAMA is a highly recursive and state-dependent indicator. To ensure perfect accuracy and prevent any risk of calculation errors, all our MESA indicators employ a "brute-force" **full recalculation** on every tick. This is our core principle of prioritizing stability over premature optimization.

- **Clear, Staged Calculation:** Inside the calculator classes, the algorithm is implemented in a clear, sequential manner. Each major component (`smooth_price`, `detrender`, `period`, `alpha`, etc.) is stored in its own internal array, which makes the code highly readable and significantly easier to debug and validate against the original pseudo-code.

- **The MESA Indicator Family:** Our modular engine allows for a complete family of indicators:
  - **`MAMA_FAMA.mq5` / `MAMA_FAMA_HeikinAshi.mq5`**: The main, combined indicators that display both the MAMA and FAMA lines, intended for crossover-based strategies.
  - **`MAMA.mq5` / `FAMA.mq5`**: Separate indicators for displaying only one of the lines, for traders who wish to use them individually.

## 4. Parameters

- **Source Price (`InpSourcePrice`):** The price data used for the calculation (Close, Open, High, Low, Median, etc.). Default is `PRICE_CLOSE`.
- **Fast Limit (`InpFastLimit`):** Sets the upper bound for the adaptive smoothing constant `alpha`. Corresponds to the alpha of the fastest desired EMA. Default is `0.5`.
- **Slow Limit (`InpSlowLimit`):** Sets the lower bound for `alpha`. Corresponds to the alpha of the slowest desired EMA. Default is `0.05`.

## 5. Usage and Interpretation

- **Crossover Signals:** The primary use of the MAMA/FAMA system is for generating trading signals based on the crossover of the two lines.
  - A **Buy Signal** is generated when the MAMA (fast line, red) crosses **above** the FAMA (slow line, green).
  - A **Sell Signal** is generated when the MAMA crosses **below** the FAMA.
- **Trend Identification:** The position of the lines relative to each other indicates the trend. When MAMA is above FAMA, the trend is considered bullish. When MAMA is below FAMA, the trend is considered bearish.
- **Adaptiveness in Action:** Observe how the lines spread apart and move quickly during strong trends, providing clear direction. In sideways, choppy markets, notice how the lines converge and flatten out, indicating a lack of trend and helping to avoid false signals.
- **Heikin Ashi Variant:** The `_HeikinAshi` version uses smoothed Heikin Ashi price data as its input. This results in even smoother MAMA/FAMA lines and can help to filter out additional market noise, potentially leading to fewer, but higher-quality, crossover signals.
- **Caution:** Like all moving average systems, MAMA/FAMA is a trend-following tool. It will produce its best results in trending markets and can generate false signals during strong, range-bound periods. It is always recommended to use it in conjunction with other forms of analysis.
