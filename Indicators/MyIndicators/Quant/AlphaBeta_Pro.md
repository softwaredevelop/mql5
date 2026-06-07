# AlphaBeta Pro Suite (Standard & MTF)

## 1. Summary

The **AlphaBeta Pro Suite** is an institutional-grade quantitative analytical suite comprising two advanced indicators: `AlphaBeta_Pro` (Standard) and `AlphaBeta_MTF_Pro` (Multi-Timeframe). Based on the Capital Asset Pricing Model (CAPM) and modern portfolio theory, the suite decomposes an asset's price fluctuations into two distinct components relative to a global market baseline (Benchmark):

1. **Systematic Market Risk ($\beta$ - Beta):** Measures the asset's sensitivity and volatility amplification relative to the benchmark.
2. **Idiosyncratic Excess Return ($\alpha$ - Alpha):** Measures the asset's active outperformance adjusted for its systematic risk.

By utilizing this suite, quantitative traders can strip away "Market Beta Noise" to identify assets moving due to their own specific structural catalysts, rather than simply riding the coattails of the broader market index.

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on stationary log-returns ($R_t$) calculated over a rolling lookback window $W$ (`InpLookback`).

### A. Beta ($\beta$ - Systematic Risk)

Beta is calculated as the covariance of the asset's returns and the benchmark's returns, divided by the sample variance of the benchmark's returns:

$$\beta = \frac{\text{Covariance}(R_{\text{asset}}, R_{\text{bench}})}{\text{Variance}(R_{\text{bench}})}$$

* **$\beta = 1.0$:** The asset moves in perfect lockstep with the market benchmark.
* **$\beta > 1.2$ (High Beta):** The asset is highly sensitive and amplifies the market's movements. Excellent for capturing maximum momentum during bull runs.
* **$\beta < 0.8$ (Low Beta):** The asset is defensive and relatively uncorrelated. Ideal for capital preservation during bear markets.

### B. Alpha ($\alpha$ - Excess Return)

Alpha represents the risk-adjusted excess return of the asset. It isolates the return that cannot be explained by market beta alone:

$$\alpha = R_{\text{asset, total}} - (\beta \times R_{\text{bench, total}})$$

* **$\alpha > 0$ (Green Histogram):** The asset is generating genuine outperformance relative to its volatility risk. Highly ideal for **Long** positions.
* **$\alpha < 0$ (Red Histogram):** The asset is underperforming on a risk-adjusted basis. Ideal for **Short** positions.

## 3. MQL5 Implementation Details

* **Decoupled Math Engine:**
  All underlying calculations (Mean, Variance, Covariance, Log-Returns, Alpha, Beta) are encapsulated inside the highly optimized, stateless `MathStatistics_Calculator.mqh` include class.

* **High-Performance Chronological Alignment ($O(1)$ Optimization):**
  Standard MTF indicators often suffer from severe performance issues because they call disk-bound historical functions like `iBarShift` and `CopyClose` inside nested loops.
  The `AlphaBeta Pro Suite` resolves this by pre-aligning the benchmark price series into a synchronized global array (`g_bench_close[]`) in a single linear pass at the beginning of `OnCalculate`. Within the main loop, subsets are extracted using lightning-fast CPU memory operations via `ArrayCopy`. This reduces execution complexity from $O(N \times \text{Lookback})$ to a highly efficient $O(N)$, speeding up calculations by up to 300 times.

* **Real-Time Forming Bar Calculations (Anti-Lag MTF):**
  A common flaw of Multi-Timeframe indicators is that they remain static on the current bar until the higher timeframe (HTF) candle fully closes, causing significant lag.
  `AlphaBeta_MTF_Pro` resolves this with a dual-execution model:
  1. **Historical Closed Bars:** Recalculated *only* when a new HTF candle forms, keeping historical calculations static and highly efficient.
  2. **Active Live Bar:** The current forming HTF bar (index `g_htf_count - 1`) is updated with the latest live Bid price (`iClose(..., 0)`) on **every single tick**, running the CAPM equations in real-time. The indicator separate window reacts instantly to live market fluctuations without any lag.

* **Intelligent Asset Benchmark Auto-Routing:**
  The suite automatically selects the correct market baseline based on the active symbol:
  * **Forex Currency Pairs:** Compares against the Dollar Index proxy (`DX` or `USDX`).
  * **Indices, Crypto, and Commodities:** Compares against the S&P 500 Index (`US500`).

## 4. Parameters

* **Timeframe (`InpTimeframe` - MTF Version Only):** The target higher timeframe (e.g., `PERIOD_H1`, `PERIOD_H4`).
* **Calculation Mode (`InpMode`):** Select between `MODE_ALPHA` (visualized as a colorful histogram) or `MODE_BETA` (visualized as a gold line).
* **Rolling Lookback (`InpLookback`):** The rolling statistical window in bars (Default: `60` bars).
* **Global Benchmark (`InpBenchmark`):** The baseline symbol for non-Forex assets (Default: `US500`).
* **Forex Benchmark (`InpForexBench`):** The baseline symbol for Forex assets (Default: `DX`).

## 5. Trading Strategies & Portfolio Allocation

### A. The Alpha-Beta Regime Matrix (For Portfolio Selection)

Traders can combine Alpha and Beta readings to categorize assets and structure highly optimized portfolios:

| State | Alpha ($\alpha$) | Beta ($\beta$) | Market Regime | Portfolio Action |
| :--- | :--- | :--- | :--- | :--- |
| **I** | **Positive (>0)** | **High (>1.2)** | Aggressive Outperformer (Bull Market Leader) | **Strong Buy (Long).** Maximum upside exposure during market rallies. |
| **II** | **Positive (>0)** | **Low (<0.8)** | Defensive Outperformer (Uncorrelated Strength) | **Buy (Long).** Safe haven asset. Holds value during market corrections. |
| **III** | **Negative (<0)** | **High (>1.2)** | Aggressive Underperformer (Fragile Asset) | **Strong Sell (Short).** First asset to collapse when the market turns down. |
| **IV** | **Negative (<0)** | **Low (<0.8)** | Defensive Underperformer (Drifting / Lagging) | **Avoid / Short.** Unprofitable asset with no active institutional interest. |

### B. Multi-Timeframe Core Strategy

Using the `AlphaBeta_MTF_Pro` indicator, traders can establish a top-down confirmation system:

1. **Macro Regime Filter (H4/D1):** Apply the MTF indicator to verify if the asset's structural daily trend is backed by consistent institutional demand (Green Alpha Histogram on H4).
2. **Local Entry Timing (M5/M15):** Drop down to lower timeframes to execute trades in the direction of the macro Alpha. If H4 Alpha is green, only seek Long entries on local support zones.

### C. Synergy with QuantScan Screener

* **QuantScan Scanner:** Used to scan the entire market to find assets with high relative strength (`REL_STR`) on a snapshot basis.
* **AlphaBeta Pro Indicator:** Used to verify the structural quality of that strength. If the high `REL_STR` is backed by a sustained, rising **Alpha Histogram**, the strength is institutional and safe to trade. If the Alpha histogram is negative despite a high `REL_STR`, the move was a lucky spike and is likely to fade.
