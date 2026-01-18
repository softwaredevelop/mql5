# Cyber Cycle Pro Suite

## 1. Summary (Introduction)

The **Cyber Cycle Pro Suite** is a collection of advanced cycle-detection indicators based on John Ehlers' Cyber Cycle algorithm. These tools are designed to isolate the market's underlying rhythm by filtering out trend and noise, allowing traders to time turning points with high precision.

The suite offers three distinct variations to suit different trading styles and market conditions:

1. **`Cyber_Cycle_Pro`:** The classic implementation. Best for analyzing raw market cycles with minimal filtering.
2. **`Laguerre_Cyber_Cycle_Pro`:** A hybrid version that pre-filters price data using a standard Laguerre Filter. This allows for manual tuning of the noise reduction vs. responsiveness trade-off via the `Gamma` parameter.
3. **`Laguerre_ACS_Pro` (Adaptive Cyber Cycle):** The most advanced version. It uses an **Adaptive Laguerre Filter** that automatically adjusts to the current market cycle length before calculating the Cyber Cycle. This results in the smoothest, cleanest signal, ideal for reducing false alarms.

## 2. Mathematical Foundations

All three indicators share the same core **Cyber Cycle** algorithm: a recursive, two-pole Butterworth filter designed to pass cycle frequencies while rejecting trend (DC) and high-frequency noise.

The difference lies in the **input data** fed into this algorithm:

* **Standard:** Uses a simple 4-bar weighted average of the price.
* **Laguerre:** Uses the output of a Laguerre Filter (controlled by `Gamma`).
* **Adaptive:** Uses the output of an Adaptive Laguerre Filter (controlled by market cycle measurement).

## 3. MQL5 Implementation Details

* **Modular Architecture:** The suite is built on a set of reusable calculator classes (`CCyberCycleCalculator`, `CLaguerreEngine`, `CLaguerreFilterAdaptiveCalculator`).
* **O(1) Incremental Calculation:** All indicators are optimized for real-time performance, processing only new bars to ensure zero lag.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data across all three indicators.

## 4. Parameters

### Common Settings

* **Alpha (`InpAlpha`):** The smoothing factor for the Cyber Cycle algorithm itself. Default is `0.07`.
* **Source Price:** Selects the input data (Standard or Heikin Ashi).

### Specific Settings

* **Gamma (`InpGamma`):** (Only for `Laguerre_Cyber_Cycle_Pro`) Controls the strength of the pre-filtering.
  * Lower values (e.g., 0.2) = Less filtering, faster response (closer to raw Cyber Cycle).
  * Higher values (e.g., 0.7) = More filtering, smoother line (closer to ACS).

## 5. Usage and Interpretation

### Which Indicator to Choose?

| Indicator | Characteristics | Best For |
| :--- | :--- | :--- |
| **Cyber Cycle** | Noisiest, Fastest | Scalping, analyzing raw price action structure. |
| **Laguerre Cyber Cycle** | Tunable Smoothness | General purpose trading. Adjust `Gamma` to match market volatility. |
| **Laguerre ACS** | Smoothest, Adaptive | Trend following, swing trading, filtering out "market noise". |

### Trading Signals (All Versions)

* **Signal Line Crossover:**
  * **Buy:** Cycle Line (Blue) crosses **above** Signal Line (Red).
  * **Sell:** Cycle Line crosses **below** Signal Line.
  * *Tip:* The Laguerre ACS version produces fewer, but higher probability crossover signals.

* **Divergence:**
  * Look for divergence between price peaks/troughs and the Cycle line. This is a powerful reversal signal.

* **Trend Filter:**
  * Always trade in the direction of the higher timeframe trend. The Cyber Cycle identifies the *turns* within that trend.
