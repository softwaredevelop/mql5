# Vertical Horizontal Filter Pro (Indicator)

## 1. Summary

**VHF Pro** is a trend-intensity indicator originally developed by Adam White (1991). It answers a single, critical question: **"Is the market Trending or Ranging?"**

Unlike moving average-based filters, VHF measures the "efficiency" of price movement by comparing the distance the price has traveled (Range) against the effort it took to get there (Path Length).

## 2. Methodology & Calculation Modes

The indicator determines the trend intensity (0.0 to 1.0) using the formula:
$$VHF = \frac{\text{Numerator (Range)}}{\text{Denominator (Path Length)}}$$

We have upgraded the classic algorithm with two selectable modes:

### Mode A: Classic (Close-Only)

* **Numerator:** `Highest(Close, N) - Lowest(Close, N)`
* **Logic:** Focuses purely on the closing consensus. Ignores intraday volatility and spikes.
* **Best for:** Smoother filtering on noisy timeframes.

### Mode B: Professional (High-Low)

* **Numerator:** `Highest(High, N) - Lowest(Low, N)`
* **Logic:** Accounts for the **entire trading range**, including wicks and failed breakouts.
* **Best for:** Accurate detection of trading ranges and volatility breakouts. This mode is more sensitive to market extremes.

**Denominator (Noise):** The sum of absolute price changes from bar to bar (the total "distance walked"). This remains consistent across both modes.

## 3. Interpretation

* **VHF < 0.30 (Gray Zone):** **Congestion Phase.** The market is range-bound. Trend strategies (MA Cross) will fail. Use Oscillator/Mean Reversion strategies.
* **VHF > 0.30 (Blue Zone):** **Emerging Trend.** A directional move is gaining structure.
* **VHF > 0.40 (Gold Zone):** **Established Trend.** The movement is highly efficient. This is the "Sweet Spot" for trend-following entries.
* **Rising VHF:** The trend is strengthening.
* **Falling VHF:** The trend is weakening or the market is entering a consolidation phase.

## 4. Parameters

* `InpPeriod`: The lookback window (Default: `28`).
* `InpMode`: Calculation method (`VHF_MODE_CLOSE_ONLY` vs `VHF_MODE_HIGH_LOW`).
* `InpPrice`: The price source for the Close-based components (Default: `PRICE_CLOSE`).

## 5. Strategic Usage

* **Filter Logic:** Before entering a trade, check the VHF. If it is Gray (<0.3), **do not trade breakouts.** Wait for the VHF to turn Blue/Gold.
* **Exit Logic:** If you are in a trend trade and VHF peaks and starts falling sharply, consider tightening stops, as the trend is likely transitioning into a range.
