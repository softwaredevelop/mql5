# Laguerre Filter Volatility-Adaptive Pro

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a specialized member of our Laguerre family. While the standard [Adaptive Laguerre](./Laguerre_Filter_Adaptive_Pro.md) uses complex cycle analysis to adjust its speed, this version uses a simpler, more reactive **volatility-based** approach.

The `Laguerre_Filter_Volatility_Adaptive_Pro` is an intelligent moving average that dynamically adjusts its smoothing factor (`gamma` or `alpha`) based on the market's current volatility.

* **High Volatility (Breakouts):** When price moves rapidly away from the filter, the indicator detects this "stress," increases its speed (lowers smoothing), and quickly catches up to the price.
* **Low Volatility (Consolidation):** When price is ranging or moving slowly, the indicator detects the lack of volatility, increases its smoothing, and becomes a stable, flat baseline.

This behavior makes it particularly effective for **breakout trading** and capturing sharp moves that might be lagged by cycle-based filters.

## 2. Mathematical Foundations and Calculation Logic

The algorithm is based on the concept that the "error" (difference) between the price and the filter should drive the filter's speed.

### Calculation Steps (Algorithm)

1. **Calculate Difference:** For each bar, calculate the absolute difference between the current price and the previous filter value.
    * `Diff = Abs(Price - Filter[i-1])`
2. **Normalize Difference:** Look back over `Period 1` to find the highest and lowest `Diff` values. Normalize the current `Diff` to a 0-1 range within this window.
    * `Mid = (Diff - LowestDiff) / (HighestDiff - LowestDiff)`
3. **Calculate Alpha (Gamma):** Take the median of these `Mid` values over `Period 2`. This median value becomes the `alpha` (or `gamma`) for the Laguerre filter.
    * `Alpha = Median(Mid, Period 2)`
4. **Apply Laguerre Filter:** The standard Laguerre filter formula is applied using this dynamic `Alpha`.
    * A higher `Alpha` means less smoothing (faster response).
    * A lower `Alpha` means more smoothing (slower response).

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Laguerre_Filter_Volatility_Calculator.mqh`):** The logic is encapsulated in a dedicated engine. This engine maintains persistent buffers for the `Diff` and `Mid` values, allowing for efficient, incremental calculation of the `Highest`, `Lowest`, and `Median` values without re-scanning the entire history on every tick.
* **Optimized Incremental Calculation:** The indicator runs with **O(1) complexity** per tick. It utilizes the `prev_calculated` state to update only the necessary bars.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.

## 4. Parameters

* **Volatility Settings:**
  * **`InpPeriod1`:** The lookback period for determining the range of the price difference (High/Low of Diff). A typical value is **20**.
  * **`InpPeriod2`:** The lookback period for smoothing the calculated alpha (Median of Alpha). A typical value is **5**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

This indicator shines in environments where price moves are sudden and sharp.

* **Breakout Confirmation:** Unlike standard moving averages that lag behind a breakout, this filter "wakes up" and accelerates into the move. If the price breaks a level and the filter turns sharply to follow it, the breakout is supported by strong volatility.
* **Trailing Stop:** Due to its ability to flatten out in ranges and accelerate in trends, it makes an excellent trailing stop line.
  * **Long Trade:** Hold as long as price is above the line.
  * **Short Trade:** Hold as long as price is below the line.
* **Comparison with Cycle-Adaptive Version:**
  * Use **Volatility-Adaptive (this indicator)** for crypto, forex news trading, or assets prone to sudden shocks.
  * Use **Cycle-Adaptive (Homodyne)** for stocks, indices, or markets with smoother, more rhythmic flows.
