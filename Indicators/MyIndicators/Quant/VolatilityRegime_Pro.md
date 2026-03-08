# Volatility Regime Pro (Indicator)

## 1. Summary

**Volatility Regime Pro** is a macro-filter designed to identify the "Breathing Cycle" of the market: **Expansion vs Contraction.**

While traditional volatility indicators (like standard ATR) simply tell you how much the price is moving, this indicator tells you whether the market is waking up or going to sleep. It helps traders switch between **Trend Following** (Expansion) and **Range Trading** (Contraction) strategies.

## 2. Methodology & Logic

The indicator calculates a ratio between short-term and long-term volatility.

### The Formula

$$Ratio = \frac{\text{Fast ATR (5)}}{\text{Slow ATR (50)}}$$

* **Fast ATR (5):** Captures the immediate "pulse" and impulse moves.
* **Slow ATR (50):** Establishes the baseline "noise level" of the market.

### Interpretation

* **Expansion (Ratio > 1.0):** The short-term movement is larger than the long-term average. The market is accelerating.
* **Contraction (Ratio < 1.0):** The short-term movement is smaller than usual. The market is compressing, often preparing for a "Squeeze".

## 3. Visualization

The indicator uses a **Colored Step-Histogram** centered around the 1.0 level.

* **Lime Green (Ratio > 1.0):** **Active Regime.** The market has energy. This is the time to look for breakouts and trend continuation.
* **Gray (Ratio < 1.0):** **Quiet Regime.** The market is dormant or consolidating. Avoid breakouts; expect chops and false signals.
* **Level 1.0:** The equilibrium point. Crossing this line often signals a regime shift.

## 4. Parameters

* `InpPeriodFast`: Lookback period for the short-term ATR (Default: `5`).
* `InpPeriodSlow`: Lookback period for the long-term baseline ATR (Default: `50`).
* `InpThreshold`: The level where the color changes (Default: `1.0`).

## 5. Strategic Usage

1. **Breakout Confirmation:**
    Never trade a breakout unless the Volatility Regime bar is **Green** (or just turned Green). A breakout attempts in a "Gray" regime often fail due to lack of follow-through.
2. **Squeeze Pre-Signal:**
    If the histogram drops very low (e.g., < 0.7), it indicates extreme compression. This is the setup phase for a `TTM Squeeze`. Watch for the histogram to turn up and cross 1.0 for the trigger.
3. **Exhaustion:**
    If the ratio reaches extreme highs (e.g., > 1.5 - 2.0), the volatility is unsustainable ("Overheated"). Consider tightening stops or taking profits.
