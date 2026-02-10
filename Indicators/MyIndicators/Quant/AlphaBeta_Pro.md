# AlphaBeta Pro (Indicator)

## 1. Summary

**AlphaBeta Pro** is an institutional-grade analytical tool that measures an asset's performance relative to a Benchmark (Global Market). It separates the price movement into two distinct components: **Market Risk (Beta)** and **Intrinsic Strength (Alpha)**.

This indicator helps traders filter out "Market Noise" and find assets that are moving due to their own specific catalysts, rather than just following the herd.

## 2. Methodology & Modes

The indicator operates in two selectable modes, visualizing different aspects of the Relative Strength concept.

### Mode A: Alpha (Excess Return)

* **Formula:** `Asset_Return - (Beta * Benchmark_Return)`.
* **Visual:** Colored Histogram.
* **Interpretation:**
  * **Green (>0):** The asset is outperforming the market expectation. It is showing true strength. Ideal for **Long** positions.
  * **Red (<0):** The asset is underperforming. Ideal for **Short** positions.
  * *Note:* Unlike simple Relative Strength (which just compares % change), Alpha adjusts for volatility.

### Mode B: Beta (Sensitivity)

* **Formula:** `Covariance(Asset, Bench) / Variance(Bench)`.
* **Visual:** Gold Line.
* **Interpretation:**
  * **Beta = 1.0:** The asset moves identically to the market.
  * **Beta > 1.5:** "High Beta". The asset is aggressive and amplifies market moves. Good for volatility scalping.
  * **Beta < 0.5:** "Low Beta". The asset is defensive or uncorrelated. Safe haven behavior.

## 3. MQL5 Implementation Details

* **Engine:** Powered by `MathStatistics_Calculator.mqh`.
* **Smart Synchronization:** The indicator automatically synchronizes the historical data of the current chart with the Benchmark symbol using precise time-matching (`iBarShift`).
* **Auto-Detection:** Automatically selects the correct Benchmark:
  * **Indices/Crypto/Stocks:** Compares against `US500`.
  * **Forex Pairs:** Compares against the Dollar Index (`DX` or `USDX`).

## 4. Parameters

* `InpMode`: Select between **MODE_ALPHA** (Histogram) or **MODE_BETA** (Line).
* `InpLookback`: The rolling window for the statistical calculation (Default: `60` bars).
* `InpBenchmark` / `InpForexBench`: Symbols used as the market baseline.

## 5. Relationship with QuantScan Script

* **QuantScan Script:** Displays a snapshot of `REL_STR` (Simple Relative Strength) for quick filtering.
* **AlphaBeta Indicator:** Displays the historical evolution of `Alpha` (Risk-Adjusted Strength) for deep analysis.
  * *Pro Tip:* Use the Script to find assets with high `REL_STR`, then use this Indicator to confirm if that strength is consistent (Green Alpha Histogram) or just a lucky spike.
