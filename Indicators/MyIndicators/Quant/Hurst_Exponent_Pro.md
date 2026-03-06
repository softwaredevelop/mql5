# Hurst Exponent Pro (Indicator)

## 1. Summary

**Hurst Exponent Pro** is an advanced quantitative indicator derived from Fractal Geometry and Chaos Theory. It measures the **Long-Term Memory** of a time series.

Unlike standard technical indicators that measure price or momentum, the Hurst Exponent measures the **predictability** and **persistence** of the market structure itself. It answers the fundamental question: *"Is the current price movement trending (persistent), mean-reverting (anti-persistent), or completely random?"*

## 2. Methodology

The indicator offers two distinct calculation engines:

### A. Detrended Fluctuation Analysis (DFA) - *Recommended*

* **Method:** A robust algorithm that removes local polynomial trends from the data before analyzing the fluctuations.
* **Strength:** It is highly resistant to "non-stationary" noise (e.g., sudden volatility spikes or drifts), making it the preferred choice for modern financial markets (Forex, Crypto).
* **Output:** Provides a smoother, more reliable estimate of the fractal dimension.

### B. Rescaled Range Analysis (R/S) - *Classic*

* **Method:** The original method developed by H.E. Hurst. It scales the range of price deviations by their standard deviation.
* **Use Case:** Useful for historical comparison or analyzing simpler datasets, but tends to overestimate trend strength in noisy markets.

**Calculation Core:** Both methods utilize **Log-Log Regression** over multiple time scales (e.g., 8, 16, 32, ..., 128 bars) to determine the slope ($H$), ensuring statistical validity.

## 3. Interpretation (The Hurst Values)

The indicator oscillates between **0.0** and **1.0**.

| Hurst Value ($H$) | Market Regime | Interpretation & Strategy |
| :--- | :--- | :--- |
| **$0.5$** | **Random Walk** (Brownian Motion) | The market is unpredictable (50/50). Price changes are independent. **Avoid trading.** |
| **$> 0.5$** (0.6 - 1.0) | **Persistent** (Trending) | The market has "memory". A positive move is likely to be followed by another positive move. **Trend Following strategies work best here.** |
| **$< 0.5$** (0.0 - 0.4) | **Anti-Persistent** (Mean Reverting) | The market "fights" the move. A positive move is likely to be followed by a reversal. **Oscillator/Reversion strategies work best here.** |

## 4. Parameters

* `InpPeriod`: The lookback window for the analysis (Default: `256`).
  * *Note:* The Hurst Exponent is a statistical measure that requires a large sample size. Values below 100 are statistically unstable. We recommend using 256 or 512 bars for reliable results.
* `InpMethod`: Switch between `METHOD_DFA` (default) and `METHOD_RS_CLASSIC`.
* `InpPrice`: The price source (Close, High, Low, etc.).

## 5. Usage in Trading

1. **Trend Filter:**
    Only enter trend-following trades (e.g., MA crossovers) when **Hurst > 0.6**. This filters out "whipsaw" losses in random markets.
2. **Mean Reversion Filter:**
    Only look for tops/bottoms (e.g., Bollinger Band bounces) when **Hurst < 0.4**.
3. **Regime Change:**
    Watch for the Hurst line crossing the **0.5** level. This signals a fundamental shift in market structure (e.g., from a trending state into a random consolidation).
