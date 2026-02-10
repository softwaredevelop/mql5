# Squeeze Pro (Indicator)

## 1. Summary (Introduction)

The `Squeeze_Pro` is a professional-grade implementation of the popular "TTM Squeeze" concept, originally developed by John Carter. It is a volatility-based indicator designed to identify moments where the market consolidates ("Squeezes") before a significant directional move ("Fires").

The indicator visualizes the relationship between Volatility compression (Bollinger Bands vs. Keltner Channels) and Momentum, helping traders stay out of choppy markets and position themselves for explosive breakouts.

## 2. Methodology and Logic

The Squeeze principle relies on the interaction between two volatility envelopes:

1. **Bollinger Bands (BB):** Measure standard deviation volatility. They expand during high volatility and contract during low volatility.
2. **Keltner Channels (KC):** Based on Average True Range (ATR). They represent the "normal" volatility range.

### The "Squeeze" State (Logic)

* **SQUEEZE ON (Red Dot):** When the Bollinger Bands contract completely *inside* the Keltner Channels. This indicates extremely low volatility—the market is building energy.
* **SQUEEZE OFF (Green Dot):** When the Bollinger Bands expand *outside* the Keltner Channels. The energy is released, and a trend move begins.

### Momentum Histogram

To determine the *direction* of the potential breakout, the indicator calculates a momentum oscillator (Price Delta from the mean of the Donchian Channel and SMA).

* **Rising Histogram:** Increasing bullish momentum.
* **Falling Histogram:** Increasing bearish momentum.

## 3. MQL5 Implementation Details

The indicator is built on the robust "Professional Indicator Suite" framework, ensuring high performance and modularity.

* **Calculator Engine (`Squeeze_Calculator.mqh`):**
    The core logic is encapsulated in a dedicated class that orchestrates the `CBollingerBandsCalculator` and `CKeltnerChannelCalculator`. This Composition Pattern allows for clean code and O(1) incremental calculation efficiency.
* **Visual Efficiency:**
    It utilizes a `DRAW_COLOR_ARROW` plot for the Squeeze dots, allowing instant visual feedback on the Zero line without cluttering the chart.
* **Price Source:**
    This indicator strictly uses **Standard Prices** (Close, High, Low) for calculations. Heikin Ashi is intentionally avoided to preserve the statistical integrity of the volatility measurement (High/Low range).

## 4. Parameters

* **Squeeze Settings:**
  * `InpPeriod`: The lookback period for both BB and KC (Default: `20`).
  * `InpBBMult`: Standard Deviation multiplier for BB (Default: `2.0`). High values make the Squeeze harder to trigger.
  * `InpKCMult`: ATR multiplier for KC (Default: `1.5`).
* **Momentum Settings:**
  * `InpMomPeriod`: The smoothing window for the Momentum histogram (Default: `12`).

## 5. Usage and Interpretation

1. **The Setup (Red Dots):**
    Look for a series of **Red Dots** on the zero line. This is the accumulation phase. **Do not trade yet.** Wait for the expansion.
2. **The Trigger (Green Dot):**
    When the first **Green Dot** appears after a series of Red Dots, the Squeeze has "fired".
3. **Direction:**
    Look at the Momentum Histogram at the moment of the trigger:
    * **Positive (Blue) Histogram:** Buy Signal (Long).
    * **Negative (Red) Histogram:** Sell Signal (Short).
4. **Exit:**
    Consider exiting the trade when the Momentum Histogram starts to decline (changes color shade) or returns to zero.
