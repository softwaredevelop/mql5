# Average Directional Index (ADX)

## 1. Summary (Introduction)

The Average Directional Index (ADX), developed by J. Welles Wilder, is a widely used technical indicator designed to measure the **strength of a trend**, regardless of its direction. It does not indicate whether the trend is bullish or bearish, but only quantifies its momentum.

The ADX system consists of three lines:

- **ADX Line:** The main line that indicates trend strength.
- **+DI (Positive Directional Indicator):** A line that measures the strength of the upward price movement.
- **-DI (Negative Directional Indicator):** A line that measures the strength of the downward price movement.

It is a powerful tool for traders to distinguish between trending and non-trending (ranging) market conditions.

## 2. Mathematical Foundations and Calculation Logic

The ADX calculation is a complex, multi-stage process that relies heavily on Wilder's smoothing technique (a specific type of Smoothed or Running Moving Average - SMMA/RMA).

### Required Components

- **ADX Period (N):** The lookback period for all calculations (e.g., 14).
- **Directional Movement (+DM, -DM):** Measures the portion of the current bar's range that is outside the previous bar's range.
- **True Range (TR):** The standard measure of a single bar's volatility.

### Calculation Steps (Algorithm)

1. **Calculate Directional Movement and True Range:** For each period, calculate:

   - $\text{Up Move} = \text{High}_i - \text{High}_{i-1}$
   - $\text{Down Move} = \text{Low}_{i-1} - \text{Low}_i$
   - If $\text{Up Move} > \text{Down Move}$ and $\text{Up Move} > 0$, then $\text{+DM} = \text{Up Move}$, else $\text{+DM} = 0$.
   - If $\text{Down Move} > \text{Up Move}$ and $\text{Down Move} > 0$, then $\text{-DM} = \text{Down Move}$, else $\text{-DM} = 0$.
   - $\text{True Range (TR)} = \text{Max}[(\text{High}_i - \text{Low}_i), \text{Abs}(\text{High}_i - \text{Close}_{i-1}), \text{Abs}(\text{Low}_i - \text{Close}_{i-1})]$

2. **Smooth +DM, -DM, and TR:** Apply Wilder's smoothing method over the period `N`.

   - **Initialization:** The first value is the sum of the first `N` periods.
     $\text{Smoothed +DM}_{N} = \sum_{i=1}^{N} \text{+DM}_i$
   - **Recursive Calculation:**
     $\text{Smoothed +DM}_i = \text{Smoothed +DM}_{i-1} - \frac{\text{Smoothed +DM}_{i-1}}{N} + \text{+DM}_i$
   - _(The same logic applies to -DM and TR)_

3. **Calculate Directional Indicators (+DI, -DI):**
   $\text{+DI}_i = 100 \times \frac{\text{Smoothed +DM}_i}{\text{Smoothed TR}_i}$
   $\text{-DI}_i = 100 \times \frac{\text{Smoothed -DM}_i}{\text{Smoothed TR}_i}$

4. **Calculate the Directional Index (DX):**
   $\text{DX}_i = 100 \times \frac{\text{Abs}(\text{+DI}_i - \text{-DI}_i)}{\text{+DI}_i + \text{-DI}_i}$

5. **Calculate the Final ADX:** The ADX is a Wilder-smoothed moving average of the DX.
   - **Initialization:** The first ADX value is a simple average of the first `N` DX values.
   - **Recursive Calculation:**
     $\text{ADX}_i = \frac{(\text{ADX}_{i-1} \times (N-1)) + \text{DX}_i}{N}$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be highly robust, clear, and consistent with our established "Wilder Algorithm".

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a complex, multi-stage indicator like the ADX, this is the most reliable method to prevent calculation errors.

- **Consensus Wilder Algorithm:** The implementation strictly follows our established two-step algorithm for Wilder's smoothing:

  1. **Robust Initialization:** The first smoothed value is calculated non-recursively (as a simple sum for `+DM`, `-DM`, `TR`, and as a simple average for `ADX`).
  2. **Efficient Recursive Calculation:** All subsequent values are calculated using the efficient formula: `Previous Value - (Previous Value / N) + Current Value`.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop. This improves code readability and makes the complex logic easy to follow:

  1. **Step 1:** Raw `+DM`, `-DM`, and `TR` values are calculated and stored in temporary arrays.
  2. **Step 2:** The raw values are smoothed using our Wilder algorithm.
  3. **Step 3:** The `+DI`, `-DI`, and `DX` values are calculated from the smoothed data.
  4. **Step 4:** The final `ADX` line is calculated by applying the Wilder algorithm to the `DX` values.

- **Heikin Ashi Variant (`ADX_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input.
  - This results in a smoother ADX system that reflects the momentum of the underlying Heikin Ashi trend, effectively filtering out some of the market noise that can cause the +DI and -DI lines to cross frequently.

## 4. Parameters

- **ADX Period (`InpPeriodADX`):** The lookback period used for all internal calculations (+DM, -DM, TR, and the final ADX smoothing). Wilder's original recommendation and the most common value is `14`.

## 5. Usage and Interpretation

- **Trend Strength:** The primary signal is the ADX line itself.
  - **ADX < 25:** Weak or non-existent trend (ranging market). Trend-following strategies should be avoided.
  - **ADX > 25:** Strong trend. The higher the ADX, the stronger the trend.
  - **Rising ADX:** The trend is gaining strength.
  - **Falling ADX:** The trend is losing strength.
- **Trend Direction (+DI and -DI Crossover):**
  - When the **+DI line (green) crosses above the -DI line (red)**, it suggests the start of a bullish trend.
  - When the **-DI line (red) crosses above the +DI line (green)**, it suggests the start of a bearish trend.
- **Trade Confirmation:** A common strategy is to wait for a +DI/-DI crossover and then confirm that the ADX line is above 25 (or rising) before entering a trade. This helps to filter out signals that occur in weak or non-trending markets.
