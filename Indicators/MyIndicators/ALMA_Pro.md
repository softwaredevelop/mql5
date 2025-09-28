# Arnaud Legoux Moving Average (ALMA) Professional

## 1. Summary (Introduction)

The Arnaud Legoux Moving Average (ALMA) was developed by Arnaud Legoux and Dimitrios Kouzis-Loukas. It was designed to address two common problems with traditional moving averages: lag and smoothness. The ALMA attempts to strike a better balance between responsiveness and smoothness, providing a high-fidelity trend line that reduces lag significantly while still filtering out minor price noise.

It achieves this by applying a Gaussian filter to the moving average calculation, which is shifted according to a user-defined "offset" parameter. This allows the filter to be more weighted towards recent bars, thus reducing lag.

Our `ALMA_Pro` implementation is a unified, professional version that integrates both standard and **Heikin Ashi** price sources into a single, robust indicator.

## 2. Mathematical Foundations and Calculation Logic

The ALMA is a sophisticated weighted moving average that uses a Gaussian distribution for its weights. Unlike a simple or exponential moving average, the weights are not linear or exponentially decaying but follow a bell curve.

### Required Components

* **Window Size (N):** The lookback period for the moving average.
* **Offset (O):** A parameter between 0 and 1 that shifts the focus of the bell curve. An offset of 0.85 (the default) means the most weight is applied to bars that are 85% of the way through the lookback window, emphasizing more recent data.
* **Sigma (S):** A parameter that controls the "flatness" or "sharpness" of the bell curve. A larger sigma creates a flatter curve (more like an SMA), while a smaller sigma creates a sharper curve (more focused weights).
* **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

For each bar `i`, the ALMA is calculated by taking a weighted sum of the prices in the lookback window from `i - (N - 1)` to `i`.

1. **Calculate Gaussian Weight:** For each point `j` within the lookback window (where `j` goes from `0` to `N-1`), a weight is calculated based on a Gaussian function.

    * First, calculate the `m` and `s` parameters from the user inputs:
        $m = O \times (N - 1)$
        $s = \frac{N}{S}$
    * Then, calculate the weight for each point `j`:
        $\text{Weight}_j = e^{-\frac{(j - m)^2}{2s^2}}$
        Where `e` is Euler's number.

2. **Calculate the Weighted Sum:** Multiply each price in the window by its corresponding weight and sum the results.
    $\text{Weighted Sum}_i = \sum_{j=0}^{N-1} P_{i - (N - 1) + j} \times \text{Weight}_j$

3. **Normalize and Calculate Final ALMA:** Divide the weighted sum by the sum of all weights to get the final ALMA value.
    $\text{ALMA}_i = \frac{\text{Weighted Sum}_i}{\sum_{j=0}^{N-1} \text{Weight}_j}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`ALMA_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CALMACalculator`, handles the core ALMA algorithm and the preparation of all **standard price types** (Close, Open, Median, etc.).
  * A derived class, `CALMACalculator_HA`, inherits from the base class and **overrides** only one specific function: the price preparation. Its sole responsibility is to calculate Heikin Ashi candles and provide the selected HA price to the base class's ALMA algorithm. This is a clean and efficient use of polymorphism.

* **Simplified Main Indicator (`ALMA_Pro.mq5`):**
    The main indicator file is now extremely clean. Its primary roles are:
    1. Handling user inputs (`input` variables).
    2. Instantiating the correct calculator object (`CALMACalculator` or `CALMACalculator_HA`) in `OnInit()` based on the user's choice.
    3. Delegating the entire calculation process to the calculator object with a single call in `OnCalculate()`.

* **Stability via Full Recalculation:** We continue to use a full recalculation on every tick. This "brute-force" approach is the most robust method for state-dependent or multi-stage calculations, eliminating potential errors from `prev_calculated` logic during history loading or timeframe changes.

## 4. Parameters (`ALMA_Pro.mq5`)

* **Window Size / Period (`InpAlmaPeriod`):** The lookback period for the moving average. Default is `9`.
* **Applied Price (`InpSourcePrice`):** The source price used for the calculation. This unified dropdown menu allows you to select from all standard price types (e.g., `PRICE_CLOSE_STD`) and all Heikin Ashi price types (e.g., `PRICE_HA_CLOSE`). Default is `PRICE_CLOSE_STD`.
* **Offset (`InpAlmaOffset`):** Controls the focus of the moving average. A value closer to `1` makes the ALMA more responsive (less lag), while a value closer to `0` makes it smoother (more lag). Default is `0.85`.
* **Sigma (`InpAlmaSigma`):** Controls the smoothness of the moving average. A larger value makes the line smoother, while a smaller value makes it follow the price more closely. Default is `6.0`.

## 5. Usage and Interpretation

* **Trend Identification:** The ALMA is primarily used as a high-fidelity trend line. When the price is above the ALMA and the ALMA is rising, the trend is considered bullish. When the price is below the ALMA and the ALMA is falling, the trend is considered bearish.
* **Dynamic Support and Resistance:** The line itself can act as a very reliable level of dynamic support in an uptrend or resistance in a downtrend.
* **Crossover Signals:** Crossovers of the price and the ALMA line can be used as trade signals. Due to its reduced lag, these signals are generally faster than those from traditional moving averages.
* **Caution:** While the ALMA is an advanced moving average, it is still a lagging indicator. It performs best in trending markets and can produce false signals in sideways or choppy conditions.
