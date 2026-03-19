# Volume Pressure Pro Suite (Indicators)

## 1. Summary

The **Volume Pressure Pro Suite** is an institutional-grade Order Flow and Tick Delta proxy toolset. Unlike standard volume indicators that merely count the number of transactions or ticks, this suite measures the **internal buying and selling pressure** within each individual candle.

By analyzing where the price closes relative to its High-Low range, it acts as a "poor man's Footprint chart." It reveals whether buyers or sellers were truly in control by the end of the period, allowing you to spot hidden institutional absorption without needing expensive Level 2 or order-book data feeds.

## 2. Methodology & Logic

The core engine (`VolumePressure_Calculator.mqh`) calculates the **Money Flow Multiplier (MFM)** for every bar.

### The Formula

$$MFM = \frac{(Close - Low) - (High - Close)}{High - Low}$$
*(Simplified mathematically to: `(2 * Close - High - Low) / (High - Low)`)*

### The Scale (-1.0 to +1.0)

* **+1.0 (Maximum Buying Pressure):** The candle closed exactly on its absolute High. Buyers dominated the entire session and maintained control until the last tick.
* **0.0 (Neutral/Equilibrium):** The candle closed exactly in the middle of its High-Low range (e.g., a perfect Doji).
* **-1.0 (Maximum Selling Pressure):** The candle closed exactly on its absolute Low. Sellers completely dominated.

## 3. The Suite Components

The suite provides two different visual representations of the same mathematical data, tailored to different trading styles:

### A. VolumePressure_Pro (The Oscillator)

* **Display:** A sub-window histogram.
* **Visuals:** Strict 2-color logic. **Lime** for positive pressure (> 0), **Red** for negative pressure (< 0).
* **Best For:** Spotting macro-divergences across multiple candles, filtering directional bias, and applying EMA smoothing (`InpSmoothPeriod > 1`) to see the broader flow of money.

### B. VolumePressure_Candles_Pro (The Overlay)

* **Display:** Main chart overlay that recolors standard Japanese candlesticks.
* **Visuals:** Advanced 4-Zone Thermal Heatmap indicating intensity:
  * **Lime (Strong Bull):** Pressure $\ge$ +0.5. Close is in the top 25% of the candle. Total buyer control.
  * **ForestGreen (Weak Bull):** Pressure between 0.0 and +0.5. Buyers won, but lost significant ground from the highs.
  * **FireBrick (Weak Bear):** Pressure between -0.5 and 0.0. Sellers won, but buyers defended the lows.
  * **Red (Strong Bear):** Pressure $\le$ -0.5. Close is in the bottom 25% of the candle. Total seller control.
* **Best For:** Laser-focused Price Action reading, immediate reversal identification, and zero-latency decision making directly on the price chart.

## 4. MQL5 Implementation Details

* **Shared Engine Architecture:** Both indicators share the same highly optimized, strictly O(1) incremental calculation engine. It calculates instantly on tick data without recalculating history, making it completely CPU-light even on M1 charts.
* **Native Overlays (`DRAW_COLOR_CANDLES`):** The Candle version uses advanced MQL5 buffer mapping to perfectly wrap over existing OHLC data, allowing you to hide native MT5 candle colors and trade purely on pressure logic.

## 5. Parameters

* `InpSmoothPeriod` (Default: `1`): Determines the EMA smoothing applied to the pressure calculation.
  * Set to `1` for **Raw Pressure** (Instantaneous feedback per candle - Highly recommended for the Candle Overlay).
  * Set to `3` or `5` to smooth out algorithmic noise and see the true intraday "Money Flow" trend (Recommended for the Oscillator).

## 6. Strategic Usage

1. **Spotting Absorption (The Hidden Reversal):**
   * *Scenario:* Price pushes into a major Resistance zone (e.g., a VWAP History Level or V-Score +2.5 Wall). The candle visually looks bullish (it moved up).
   * *The Signal:* The `VolumePressure_Candles` paints the candle **ForestGreen** or even **FireBrick**.
   * *Meaning:* Despite the upward move, institutional sellers aggressively absorbed the buying pressure at the highs, forcing a weak close. A violent bearish reversal is imminent.
2. **Breakout Confirmation:**
   * If price breaks out of a `Squeeze_Pro` consolidation, the breakout candle *must* be painted **Lime** (for Longs) or **Red** (for Shorts). If a breakout candle is weakly colored, it is highly likely to be a fake-out / liquidity grab.
3. **Oscillator Divergence:**
   * Using the sub-window `VolumePressure_Pro`, look for scenarios where Price makes a *Higher High*, but the Histogram prints a *Lower High*. This indicates that the upward momentum is running out of true buying volume (Money Flow Divergence), signaling an excellent short opportunity.
