# MESA Adaptive Moving Average (MAMA & FAMA) Professional

## 1. Summary (Introduction)

The MESA Adaptive Moving Average (MAMA), developed by John F. Ehlers, is a highly sophisticated, adaptive moving average that dynamically adjusts its speed based on the market's measured cyclicality. It is almost always plotted with its companion line, **FAMA (Following Adaptive Moving Average)**, to provide clear crossover signals.

Our `MAMA_FAMA_Pro` implementation is a unified, professional indicator that offers a choice between two distinct, popular algorithms:

1. **Ehlers Official:** The original, complex algorithm based on the Hilbert Transform for precise cycle measurement.
2. **LazyBear Simple:** A simplified, highly responsive version popularized on platforms like TradingView.

Both algorithms can be calculated using either **standard** or **Heikin Ashi** price data, providing maximum flexibility in a single tool.

## 2. Mathematical Foundations and Calculation Logic

The MAMA algorithm translates price movements into wave-like components to measure their cyclical properties and adapt its smoothing factor (`alpha`) accordingly.

### Required Components

* **Source Price:** The price series used for calculation.
* **Fast Limit (`alpha_fast`):** The maximum allowable value for `alpha`.
* **Slow Limit (`alpha_slow`):** The minimum allowable value for `alpha`.

### Calculation Steps (Algorithm)

1. **Price Pre-processing:** The source price is first lightly smoothed.
2. **Cycle Measurement:** The algorithm analyzes the price wave to measure its cyclical properties.
    * The **Ehlers Official** version uses a full Hilbert Transform to decompose the price into In-Phase (I) and Quadrature (Q) components to precisely measure the dominant cycle period.
    * The **LazyBear Simple** version uses a simplified approximation of this process.
3. **Adaptive Alpha Calculation:** The rate of change of the phase angle is used to calculate a dynamic `alpha`, constrained by the `Fast Limit` and `Slow Limit`. A rapid phase change (trending market) results in a larger `alpha` (faster average).
4. **Final MAMA and FAMA Calculation:**
    * $\text{MAMA}_i = \alpha_i \cdot \text{Price}_i + (1 - \alpha_i) \cdot \text{MAMA}_{i-1}$
    * $\text{FAMA}_i = (\alpha_i/2) \cdot \text{MAMA}_i + (1 - \alpha_i/2) \cdot \text{FAMA}_{i-1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is built upon a clean, robust, and reusable object-oriented framework.

* **Modular Engine Architecture (`MAMA_Engines.mqh`):**
    The entire logic is encapsulated within a single, powerful include file. This file contains an abstract base class (`CMAMACalculatorBase`) and two separate, concrete engine classes that inherit from it: `CMAMA_Ehlers_Engine` and `CMAMA_LazyBear_Engine`. This ensures both algorithms are available through a common interface but are maintained as distinct, definition-true implementations.

* **Object-Oriented Inheritance for HA:** Each engine class has a corresponding `_HA` child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices. This eliminates code duplication and ensures all four variations (Ehlers Std, Ehlers HA, LB Std, LB HA) are robust and consistent.

* **Stability via Full Recalculation:** MAMA is a highly recursive and state-dependent indicator. To ensure perfect accuracy and prevent calculation errors, our implementation employs a "brute-force" **full recalculation** on every tick.

## 4. Parameters

* **Algorithm (`InpAlgorithm`):** Allows the user to select between the two calculation methods:
  * `ALGO_EHLERS_OFFICIAL`: The complex, original algorithm.
  * `ALGO_LAZYBEAR_SIMPLE`: The simplified, more responsive version.
* **Source Price (`InpSourcePrice`):** The price data used for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Fast Limit (`InpFastLimit`):** Sets the upper bound for the adaptive smoothing constant `alpha`. Default is `0.5`.
* **Slow Limit (`InpSlowLimit`):** Sets the lower bound for `alpha`. Default is `0.05`.

## 5. Usage and Interpretation

* **Crossover Signals:** The primary use is for generating trading signals based on the crossover of the two lines.
  * A **Buy Signal** is generated when MAMA (fast line, red) crosses **above** FAMA (slow line, green).
  * A **Sell Signal** is generated when MAMA crosses **below** FAMA.
* **Trend Identification:** When MAMA is above FAMA, the trend is considered bullish. When MAMA is below FAMA, the trend is considered bearish.
* **Choosing an Algorithm:**
  * **Ehlers Official:** Tends to be smoother and more robust in its cycle analysis. It may produce fewer signals but can be more reliable in filtering out noise.
  * **LazyBear Simple:** Tends to be faster and more responsive to immediate price changes. It may produce more signals, which can be beneficial in fast-moving markets but may also lead to more whipsaws.
* **Heikin Ashi Variant:** Using a Heikin Ashi price source results in even smoother MAMA/FAMA lines and can help to filter out additional market noise, potentially leading to fewer, but higher-quality, crossover signals.
