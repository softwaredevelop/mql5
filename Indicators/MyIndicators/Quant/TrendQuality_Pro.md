# Trend Quality Pro (Indicator)

## 1. Summary (Introduction)

The `TrendQuality_Pro` is a sophisticated market filter designed to distinguish between **"Clean Trends"** and **"Market Noise"**. It is based on Perry Kaufman's **Efficiency Ratio (ER)** concept.

While most indicators (like MA or MACD) only tell you the *direction* of the trend, this indicator tells you the *quality* or *efficiency* of that movement. It answers the critical question: *"Is the market moving with conviction, or is it just chopping around?"*

## 2. Methodology and Logic

The indicator calculates how efficient price movement is over a specific period.

### The Formula

$$ER = \frac{\text{Net Change}}{\text{Sum of Changes}}$$

* **Net Change:** The absolute difference between the current price and the price $N$ bars ago. (The "distance traveled").
* **Sum of Changes:** The sum of absolute bar-to-bar price changes over the same period. (The "effort" or "path length").

### Interpretation

The value always oscillates between **0.0** and **1.0**.

* **ER = 1.0 (Maximum Efficiency):** Price moved in a straight vertical line. Every tick was in the trend direction.
* **ER ≈ 0.0 (Maximum Noise):** Price moved up and down violently but ended up exactly where it started. Maximum volatility with zero progress.

## 3. MQL5 Implementation Details

The indicator utilizes the "Professional Suite" modular architecture for maximum performance.

* **Calculator Engine (`EfficiencyRatio_Calculator.mqh`):**
  * **Logic:** Encapsulates the Kaufman formula in a reusable class.
  * **Optimization:** Uses standard arrays and incremental loops. While a theoretical O(1) sliding window sum is possible, the generic loop implementation is extremely fast for standard periods (<100) and ensures numerical stability.
* **Visuals:**
  * Uses `DRAW_COLOR_HISTOGRAM` for clear visual feedback.
  * **Dynamic Coloring:** The histogram bars change color based on the ER value, allowing traders to instantly recognize market regimes (Noise vs. Trend) without reading the specific numbers.

## 4. Parameters

* **Timeframe & Price:**
  * `InpPeriod`: The lookback window for the calculation (Default: `10`). Lower values make it more sensitive; higher values smooth out short-term fluctuations.
  * `InpPrice`: The price source (Close, Median, etc.).

* **Thresholds (Color Logic):**
  * `InpThreshold`: The level above which a market is considered "Trending" (Default: `0.30`).
  * `InpStrongLevel`: The level above which a trend is considered "Strong/Parabolic" (Default: `0.60`).

## 5. Usage and Workflow

1. **The "No-Trade" Filter (Gray Bars):**
    If the histogram is **Gray** (Value < 0.30), the market is in a "Choppy" or "Noise" regime. Trend-following strategies (like Moving Average crossovers) will likely fail here. **Stay sideline or use Mean Reversion.**
2. **Trend Confirmation (Blue Bars):**
    If the histogram turns **Blue** (Value > 0.30), a clean trend is establishing. This is the green light for trend-following entries (e.g., Pullbacks to EMA).
3. **Super-Trend Warning (Gold Bars):**
    If the histogram turns **Gold** (Value > 0.60), the trend is extremely efficient/strong.
    * *Pros:* Profits accumulate fast.
    * *Cons:* Such efficiency is unsustainable long-term. Be prepared for a snap-back or consolidation (check `Z-Score` for confirmation of exhaustion).
