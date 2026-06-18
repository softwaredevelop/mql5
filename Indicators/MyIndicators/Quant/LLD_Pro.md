# Lead-Lag Dominance Index Pro Suite (LLDI Pro & MTF Pro)

## 1. Summary (Introduction)

The **Lead-Lag Dominance Index Pro Suite (`LLD_Pro` & `LLD_MTF_Pro`)** is an institutional-grade, high-frequency quantitative toolset designed to detect and measure temporal lead-lag relationships between any two financial instruments in real-time. In financial markets, information does not flow instantaneously to all assets. Highly liquid, market-representative instruments (such as indices like DXY, or benchmark assets like BTCUSD) often react to macroeconomic and sentiment shifts seconds or minutes before secondary correlated assets (like EURUSD, or altcoins like SUIUSD and ETHUSD) follow suit.

By measuring the mathematical cross-correlation phase shift, the LLD Suite solves two of the most critical questions in cross-asset trading:

1. **Who is driving the current market regime?** (Which asset is leading and which is trailing?)
2. **What is the current execution window?** (By how many bars does the leader anticipate the follower?)

The suite includes both a single-timeframe tactical oscillator (`LLD_Pro`) and a multi-timeframe macro monitor (`LLD_MTF_Pro`). Featuring **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session), the indicators can completely isolate intraday/intraweek price relationships from overnight gaps and illiquidity. The entire architecture features a highly optimized $O(1)$ real-time mathematical engine, a high-precision 5-decimal status panel, and a bulletproof, dual-symbol synchronization module.

---

## 2. Mathematical Foundations and Calculation Logic

To perform a mathematically valid cross-correlation on financial time series, the pricing data must first be transformed to satisfy stationary conditions, preventing the phenomenon of spurious regression.

### A. Logarithmic Return Transformation

The engine transforms closing price series $P_t$ for both Symbol $A$ (Primary Chart) and Symbol $B$ (Secondary Comparison) into stationarized log-returns ($R_t$):

$$R_{A,t} = \ln\left(\frac{P_{A,t}}{P_{A,t-1}}\right)$$

$$R_{B,t} = \ln\left(\frac{P_{B,t}}{P_{B,t-1}}\right)$$

### B. Shifted Pearson Cross-Correlation (CCF)

For each target bar $t$, the indicator computes the Pearson correlation coefficient ($r$) over a rolling or anchored window $W$ (`window_size`) using multiple lag offsets $k$ ($1 \le k \le \text{MaxLag}$):

* **Direction 1: Symbol B leads Symbol A** ($r_{B \rightarrow A}$)
  Correlates the past of B with the present of A. The window of B is shifted backward by $k$ bars:
  $$r_{B \rightarrow A}(k) = \text{Corr}(R_{B, t-k \dots t-k-W}, R_{A, t \dots t-W})$$

* **Direction 2: Symbol A leads Symbol B** ($r_{A \rightarrow B}$)
  Correlates the past of A with the present of B. The window of A is shifted backward by $k$ bars:
  $$r_{A \rightarrow B}(k) = \text{Corr}(R_{A, t-k \dots t-k-W}, R_{B, t \dots t-W})$$

The absolute peak (maximum) correlation is identified for both directions:
$$\text{Peak}_{B \rightarrow A} = \max_{k} |r_{B \rightarrow A}(k)| \quad \text{at optimal lag } L_B$$
$$\text{Peak}_{A \rightarrow B} = \max_{k} |r_{A \rightarrow B}(k)| \quad \text{at optimal lag } L_A$$

The **Lead-Lag Dominance Index (LLDI)** is computed as:
$$\text{LLDI}_t = \text{Peak}_{B \rightarrow A} - \text{Peak}_{A \rightarrow B}$$

* **$\text{LLDI} > 0.02$ (Blue Histogram):** Symbol B (Secondary) is dominant and leads Symbol A (Chart).
* **$\text{LLDI} < -0.02$ (Red Histogram):** Symbol A (Chart) is dominant and leads Symbol B (Secondary).
* **$\text{LLDI} \in [-0.02, 0.02]$ (Gray Histogram):** Symmetrical relationship (no clear leader or absolute co-movement).

---

## 3. MQL5 UI & Advanced Architecture

### A. Unified Math Engine (`LLD_Calculator.mqh`)

All logarithmic transformations, rolling windows, and optimal lag sweeps are strictly decoupled from visual rendering and encapsulated inside the stateful `CLeadLagDominanceCalculator` class.

### B. Dual-Symbol HTF Synchronization Module (`EnsureHTFDataReady`)

When calculating multi-timeframe cross-correlations across two distinct symbols, asynchronous history gaps or loading delays can cause fatal array out-of-range errors. `LLD_MTF_Pro` implements a rigorous dual-gate check:

```mql5
if(!EnsureHTFDataReady(_Symbol, InpTimeframe, required_bars) ||
   !EnsureHTFDataReady(InpSecondSymbol, InpTimeframe, required_bars))
```

This forces the indicator to pause calculations and wait for the MT5 terminal to fully construct and synchronize history for both assets before executing the mathematical engine.

### C. High-Performance $O(1)$ Block Memory Transfer

Traditional MQL5 MTF indicators utilize slow `iBarShift` and `iClose` API calls inside nested historical loops, causing severe terminal lag. `LLD_MTF_Pro` eliminates this by utilizing high-speed memory block copying (`CopyClose`) directly into chronologically aligned dynamic arrays (`h_close_A`, `h_close_B`) whenever a new HTF bar forms. This reduces complexity from $O(N)$ API lookups to an instantaneous block transfer.

### D. Zero-Lag Flat Step MTF Mapping

To project higher timeframe results onto a lower timeframe chart without repainting or calculation lag, `LLD_MTF_Pro` dynamically locates the exact operational starting bar corresponding to the live forming HTF bar:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
```

Historical HTF steps remain strictly frozen (non-repainting), while the active lower timeframe step block updates instantaneously on every live tick.

### E. Anti-Collision Subwindow Labeling & Invisible Data Mapping

* **Unique Prefixes:** Status panels automatically bind to their specific subwindow ID (`ChartWindowFind()`), allowing multiple LLD instances (e.g., comparing different assets or timeframes) to render cleanly on a single chart without overwriting each other.

* **Data Window Mapping:** The `Optimal Lag` buffer is set to `INDICATOR_DATA` so its exact value can be inspected in the MT5 Data Window upon hovering, but it is explicitly styled as `DRAW_NONE` to keep the visual histogram scale pure and uncompressed.

---

## 4. Input Parameters

* **Comparison Symbol (`InpSecondSymbol`):** The secondary comparison instrument (Default: `"BTCUSD"`).
* **Target Timeframe (`InpTimeframe`):** *(MTF Version Only)* The higher timeframe to monitor (Default: `PERIOD_M5`).
* **Anchor Reset Period (`InpAnchor`):** The dynamic reset mode (`ANCHOR_NONE`, `SESSION`, `WEEK`, `MONTH`, `CUSTOM_SESSION`).
* **Rolling Window Size (`InpWindowSize`):** The lookback sample size for rolling correlation (Used if Anchor = None). Default: `50`.
* **Maximum Tested Lag (`InpMaxLag`):** The maximum phase shift window tested. Default: `10`.
* **Custom Start Time (`InpCustomStart`):** Session start time in "HH:MM" broker time (Used if Anchor = Custom).
* **Custom End Time (`InpCustomEnd`):** Session end time in "HH:MM" broker time (Used if Anchor = Custom).

---

## 5. Quantitative Trading Strategies

### A. Dynamic Intraday Lead-Lag Rotations

Lead-lag relationships in financial markets are highly dynamic and rotate throughout the trading day based on regional liquidity.

* **The Concept:** During the European session, `EURUSD` may lead `GBPUSD`. However, when New York opens, US equity futures or US Treasury yields may take the definitive lead.
* **The Execution:** By setting `InpAnchor = ANCHOR_SESSION`, the indicator flushes its historical buffer at midnight (or at the custom broker open), providing an unpolluted, intraday momentum gauge of who is driving the market *today*.

### B. Contemporaneous Lockstep Cointegration (The Symmetrical Proof)

When pairing highly cointegrated assets belonging to the same asset class (e.g., **BTCUSD vs. ETHUSD**):

* Real-time co-movement occurs almost entirely at lag $k = 0$.
* At shifted lags ($k \ge 1$), the predictive power of BTC over ETH equals ETH over BTC ($\text{Peak}_{B \rightarrow A} \approx \text{Peak}_{A \rightarrow B}$).
* This mathematically yields $\text{LLDI} \approx 0.00000$ (Gray Histogram). This flat reading is an institutional proof of absolute contemporaneous efficiency. When structural divergence breaks this symmetry, the histogram spikes into Blue or Red, signaling an immediate arbitrage opportunity.

### C. The Cointegration + LLDI Synergy (Single-Leg Arbitrage)

By combining `PairsTrading_Pro` (Cointegration Z-Score) with `LLD_Pro`, traders can execute highly profitable single-leg mean reversion trades:

1. `PairsTrading_Pro` indicates an extreme spread dislocation (Z-Score $\le -2.0$), meaning Asset A is severely undervalued relative to Asset B.
2. `LLD_Pro` confirms that **Asset B is dominant and leading Asset A** ($\text{LLDI} > 0.02$).
3. **The Trade:** Because the dominant leader (Asset B) has already established the upward trajectory, the trailing asset (Asset A) is mathematically bound to follow to close the cointegration gap. You execute a **BUY order exclusively on Asset A**. This eliminates double-leg transaction costs and reduces margin utilization by 50%.

### D. Top-Down Macro Dominance Alignment *(MTF Exclusive)*

Traders can utilize `LLD_MTF_Pro` to establish institutional macro direction while executing on a micro tactical chart:

1. Apply `LLD_MTF_Pro` on an `M1` or `M5` chart, set to monitor the **`PERIOD_H1`** timeframe comparing `_Symbol` against a macro benchmark (e.g., `US500` or `DXY`).
2. If the H1 MTF histogram is strongly **Blue**, the macro benchmark is driving the broader market upward.
3. **The Micro Entry:** Ignore all short/bearish signals on the lower timeframe chart. Wait for local LTF pullbacks or moving average retests, and execute **BUY orders only in the direction of the macro leader**, locking in an exceptional risk-to-reward ratio.
