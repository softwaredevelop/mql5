# Fractal Dimension Index Pro (Indicator)

## 1. Summary

**FDI Pro** is an advanced quantitative indicator derived from Chaos Theory. It measures the "Roughness" or "Complexity" of the price curve.

While classical indicators assume that markets are linear, FDI assumes markets are fractal. It answers the question: *"Is the price movement organized and linear (Trend), or is it filling up the space chaotically (Chop)?"*

## 2. Methodology & Logic

The indicator uses the method developed by **Carlos Sevcik** to approximate the Fractal Dimension.

### The Concept (Box Counting)

Imagine the price chart displayed in a square box.

* If the price moves in a straight line from bottom-left to top-right, it occupies 1 dimension. **FDI = 1.0** (Linear Trend).
* If the price scribbles all over the chart, filling the entire box with noise, it occupies 2 dimensions. **FDI = 2.0** (Maximum Entropy/Noise).
* The "Random Walk" (Brownian Motion) sits exactly in the middle at **FDI = 1.5**.

### Mathematical Interpretation

* **FDI < 1.5:** The market is "Persistent". Trends are smooth and sustainable.
* **FDI > 1.5:** The market is "Anti-Persistent" or Noisy. Price returns to the mean frequently, making trend-following dangerous.

## 3. Visualization

The indicator uses a **Colored Histogram** to signal market regimes instantly.

* **Green Bars (Value < 1.5):** **Trend Mode.** The market has low complexity and high linearity. This is the "Green Light" for trend-following strategies (e.g., Breakouts, MA Crosses).
* **Gray Bars (Value > 1.5):** **Chaos Mode.** The market is complex and choppy. Prices are random. Avoid breakouts; use Mean Reversion strategies or stay out.

## 4. Parameters

* `InpPeriod`: The window of bars to analyze (Default: `30`).
  * *Shorter periods (e.g., 20)* react faster to regime changes but are noisier.
  * *Longer periods (e.g., 50)* provide a robust, long-term filter for trend quality.
* `InpPrice`: The price source (Close, High, Low, etc.). Standard `PRICE_CLOSE` is recommended.

## 5. Strategic Usage

1. **Trend Filter:**
    Combine FDI with a directional indicator (like `Trend Score` or `TSI`). Only take the trade if the FDI Histogram is **Green** (< 1.5). This filters out fake breakouts in choppy markets.
2. **Exhaustion Signal:**
    If prices are making new highs, but the FDI starts rising sharply towards 1.5 (Histogram turning Gray), it means the trend is becoming "rough" and unstable. A reversal or consolidation is likely.
3. **Hurst Confirmation:**
    FDI and Hurst are inverses. A low FDI (< 1.5) usually corresponds to a high Hurst (> 0.5). Using both provides a dual-confirmation of market memory.
