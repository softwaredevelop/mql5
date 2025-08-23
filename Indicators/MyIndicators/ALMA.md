# Arnaud Legoux Moving Average (ALMA)

## 1. Summary (Introduction)

The Arnaud Legoux Moving Average (ALMA) was developed by Arnaud Legoux and Dimitrios Kouzis-Loukas. It was designed to address two common problems with traditional moving averages: lag and smoothness. The ALMA attempts to strike a better balance between responsiveness and smoothness, providing a high-fidelity trend line that reduces lag significantly while still filtering out minor price noise.

It achieves this by applying a Gaussian filter to the moving average calculation, which is shifted according to a user-defined "offset" parameter. This allows the filter to be more weighted towards recent bars, thus reducing lag.

## 2. Mathematical Foundations and Calculation Logic

The ALMA is a sophisticated weighted moving average that uses a Gaussian distribution for its weights. Unlike a simple or exponential moving average, the weights are not linear or exponentially decaying but follow a bell curve.

### Required Components

- **Window Size (N):** The lookback period for the moving average.
- **Offset (O):** A parameter between 0 and 1 that shifts the focus of the bell curve. An offset of 0.85 (the default) means the most weight is applied to bars that are 85% of the way through the lookback window, emphasizing more recent data.
- **Sigma (S):** A parameter that controls the "flatness" or "sharpness" of the bell curve. A larger sigma creates a flatter curve (more like an SMA), while a smaller sigma creates a sharper curve (more focused weights).
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

For each bar `i`, the ALMA is calculated by taking a weighted sum of the prices in the lookback window from `i - (N - 1)` to `i`.

1. **Calculate Gaussian Weight:** For each point `j` within the lookback window (where `j` goes from `0` to `N-1`), a weight is calculated based on a Gaussian function.

   - First, calculate the `m` and `s` parameters from the user inputs:
     $m = O \times (N - 1)$
     $s = \frac{N}{S}$
   - Then, calculate the weight for each point `j`:
     $\text{Weight}_j = e^{-\frac{(j - m)^2}{2s^2}}$
     Where `e` is Euler's number.

2. **Calculate the Weighted Sum:** Multiply each price in the window by its corresponding weight and sum the results.
   $\text{Weighted Sum}_i = \sum_{j=0}^{N-1} P_{i - (N - 1) + j} \times \text{Weight}_j$

3. **Normalize and Calculate Final ALMA:** Divide the weighted sum by the sum of all weights to get the final ALMA value.
   $\text{ALMA}_i = \frac{\text{Weighted Sum}_i}{\sum_{j=0}^{N-1} \text{Weight}_j}$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refocused to be a completely self-contained, robust, and accurate indicator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. As ALMA is not a recursive indicator, this is a straightforward and highly stable approach.

- **Self-Contained Price Handling:** The indicator does not use external handles like `iMA`. It directly processes the price arrays (`open`, `high`, `low`, `close`) provided by `OnCalculate`. A `for` loop and `switch` block prepare a single `price_source[]` array based on the user's `InpAppliedPrice` selection, including all standard and calculated price types (e.g., `PRICE_TYPICAL`).

- **Accurate Indexing:** The implementation uses the correct indexing logic (`price_index = i - (g_ExtAlmaPeriod - 1) + j`) within the calculation loop. This ensures that the weights are applied to the correct prices within the sliding window, perfectly matching the standard definition of the indicator.

- **Integrated Calculation Loop:** The `OnCalculate` function uses a single, efficient main `for` loop to calculate the ALMA for each bar. The complex weighting and summation logic is handled within this loop, making the code clear and easy to follow.

- **Heikin Ashi Variant (`ALMA_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data (e.g., `ha_close`) as its input.
  - This combines the advanced smoothing of the ALMA formula with the noise-filtering properties of Heikin Ashi candles, resulting in an exceptionally smooth and responsive trend line.

## 4. Parameters

- **Window Size / Period (`InpAlmaPeriod`):** The lookback period for the moving average. Default is `9`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. Default is `PRICE_CLOSE`.
- **Offset (`InpAlmaOffset`):** Controls the focus of the moving average. A value closer to `1` makes the ALMA more responsive (less lag), while a value closer to `0` makes it smoother (more lag). Default is `0.85`.
- **Sigma (`InpAlmaSigma`):** Controls the smoothness of the moving average. A larger value makes the line smoother, while a smaller value makes it follow the price more closely. Default is `6.0`.

## 5. Usage and Interpretation

- **Trend Identification:** The ALMA is primarily used as a high-fidelity trend line. When the price is above the ALMA and the ALMA is rising, the trend is considered bullish. When the price is below the ALMA and the ALMA is falling, the trend is considered bearish.
- **Dynamic Support and Resistance:** The line itself can act as a very reliable level of dynamic support in an uptrend or resistance in a downtrend.
- **Crossover Signals:** Crossovers of the price and the ALMA line can be used as trade signals. Due to its reduced lag, these signals are generally faster than those from traditional moving averages.
- **Caution:** While the ALMA is an advanced moving average, it is still a lagging indicator. It performs best in trending markets and can produce false signals in sideways or choppy conditions.
