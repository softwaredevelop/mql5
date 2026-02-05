# RVOL Pro (Indicator)

## 1. Summary (Introduction)

The `RVOL_Pro` (Relative Volume) is a critical volume analysis tool designed to contextualize trading activity. Raw volume bars can be misleading because volume naturally varies by time of day (e.g., London Open vs. Asian Lunch). RVOL solves this by displaying the **ratio** between the current volume and the average volume of the past $N$ periods.

This normalization allows traders to instantly spot **Institutional Activity** (Smart Money) regardless of the asset or timeframe. It answers the question: *"Is this price move supported by real participation?"*

## 2. Methodology and Logic

The formula is straightforward but powerful:

$$RVOL = \frac{\text{Current Volume}}{\text{Average Volume}(N)}$$

* **Average Volume:** Calculated as a Simple Moving Average (SMA) of the volume over the lookback period (Default: 20).
* **Result:**
  * `1.0`: Volume is exactly average.
  * `2.0`: Volume is double the average (200%).
  * `0.5`: Volume is half the average (50%).

## 3. MQL5 Implementation Details

The indicator is built using the "Professional Suite" modular architecture.

* **Calculator Engine (`RelativeVolume_Calculator.mqh`):**
  * **Logic:** A dedicated class handles the rolling average calculation.
  * **Consistency:** This is the exact same engine used by `Market_Scanner_Pro`, ensuring that the "VOL_QUAL" metric in your CSV export perfectly matches what you see on the chart.
* **Visuals:**
  * Uses `DRAW_COLOR_HISTOGRAM` for immediate visual decoding.
  * **Tick Volume:** By default, it uses Tick Volume (standard in Forex). For Futures/Stocks, it can be adapted to Real Volume if available.

## 4. Parameters

* `InpPeriod`: The lookback window for the average volume calculation (Default: `20`).
* `InpThreshold`: The level at which volume is considered "High/Institutional" (Default: `2.0`). This controls when the histogram turns Orange/Red.

## 5. Usage and Interpretation

1. **Breakout Confirmation (The "Fuel"):**
    * A breakout from a consolidation (Squeeze) is only valid if accompanied by **High RVOL (Orange Bar)**.
    * If price breaks a support/resistance level on **Low RVOL (Gray Bar)**, it is likely a "Fakeout" or a trap.

2. **Trend Continuation:**
    * In a healthy trend, impulse moves (legs) should have higher RVOL than pullbacks.
    * If a pullback starts having higher volume than the trend leg, the trend is losing control.

3. **Climax and Reversal (Absorption):**
    * Look for specific candle shapes combined with High RVOL.
    * **Example:** A huge spike in volume (`RVOL > 3.0`) on a Doji or a "Pin Bar" often marks the exact top or bottom (Exhaustion Volume).

4. **No-Trade Zone:**
    * If the histogram is consistently Gray/Low, the market lacks liquidity and interest. Stay aside.
