# Lead-Lag Dominance Index Pro (LLDI Pro)

## 1. Summary (Introduction)

The `LLD_Pro` (Lead-Lag Dominance Index) is an institutional-grade, high-frequency quantitative tool designed to detect and measure the lead-lag relationships between any two financial instruments in real-time. In financial markets, information does not flow instantaneously to all assets. Highly liquid market-representative instruments (such as indices like DXY or major assets like BTCUSD) often react to macroeconomic and sentiment shifts seconds or minutes before secondary correlated assets (like EURUSD, or altcoins like SUIUSD and ETHUSD) follow suit.

By measuring the mathematical lead-lag relationship, `LLD_Pro` solves two of the most critical questions in cross-asset trading:

1. **Who is driving the current market regime?** (Which asset is leading and which is trailing?)
2. **What is the current execution window?** (By how many bars does the leader anticipate the follower?)

The indicator features a highly optimized $O(1)$ real-time mathematical engine, a high-precision 4-decimal status panel, and a bulletproof, gap-resistant bar-time synchronization module.

## 2. Mathematical Foundations and Calculation Logic

To perform a mathematically valid cross-correlation on financial time series, the pricing data must first be transformed to satisfy stationary conditions, preventing the phenomenon of spurious regression.

### A. Logarithmic Return Transformation

The indicator transforms closing price series $P_t$ for both Symbol $A$ (Chart) and Symbol $B$ (Secondary Comparison) into stationarized log-returns ($R_t$):

$$R_{A,t} = \ln\left(\frac{P_{A,t}}{P_{A,t-1}}\right)$$

$$R_{B,t} = \ln\left(\frac{P_{B,t}}{P_{B,t-1}}\right)$$

### B. Shifted Pearson Cross-Correlation (CCF)

For each bar $t$, the indicator computes the Pearson correlation coefficient ($r$) over a rolling window $W$ (`InpWindowSize`) using multiple lag offsets $k$ ($1 \le k \le \text{MaxLag}$):

* **Direction 1: Symbol B leads Symbol A** ($r_{B \rightarrow A}$)
  Correlates the past of B with the present of A. The window of B is shifted backward by $k$ bars:
  $$r_{B \rightarrow A}(k) = \text{Corr}(R_{B, t-k \dots t-k-W}, R_{A, t \dots t-W})$$

* **Direction 2: Symbol A leads Symbol B** ($r_{A \rightarrow B}$)
  Correlates the past of A with the present of B. The window of A is shifted backward by $k$ bars:
  $$r_{A \rightarrow B}(k) = \text{Corr}(R_{A, t-k \dots t-k-W}, R_{B, t \dots t-W})$$

### C. Dominance Index (LLDI) and Optimal Lag

The absolute peak (maximum) correlation is identified for both directions:
$$\text{Peak}_{B \rightarrow A} = \max_{k} |r_{B \rightarrow A}(k)| \quad \text{at optimal lag } L_B$$
$$\text{Peak}_{A \rightarrow B} = \max_{k} |r_{A \rightarrow B}(k)| \quad \text{at optimal lag } L_A$$

The **Lead-Lag Dominance Index (LLDI)** is computed as:
$$\text{LLDI}_t = \text{Peak}_{B \rightarrow A} - \text{Peak}_{A \rightarrow B}$$

* **$\text{LLDI} > 0.02$ (Blue Histogram):** Symbol B (Secondary) is dominant and leads Symbol A (Chart).
* **$\text{LLDI} < -0.02$ (Red Histogram):** Symbol A (Chart) is dominant and leads Symbol B (Secondary).
* **$\text{LLDI} \in [-0.02, 0.02]$ (Gray Histogram):** Symmetrical relationship (no clear leader).

The **Optimal Lag** represents the exact shift $L$ (expressed in bars) at which the absolute correlation is maximized. It is signed positive if Symbol B leads, and negative if Symbol A leads.

## 3. MQL5 Implementation Details

* **Decoupled Architecture:**
  The mathematical logic is kept completely separate in `LLD_Calculator.mqh` (encapsulated in `CLeadLagDominanceCalculator`), while the visual representation, buffers, and object drawing are handled by the lightweight `LLD_Pro.mq5` wrapper.

* **Real-Time $O(1)$ Tick-by-Tick Engine:**
  In standard MT5 implementations, indicators are calculated once per bar, making real-time readings static inside the current candle. `LLD_Pro` solves this by modifying the incremental `start_index` passed to the calculator. Instead of using `prev_calculated` directly, it passes `prev_calculated - 1`. This forces the calculator to recalculate the returns and correlation metrics for the **current forming bar** (index `rates_total - 1`) on **every single tick**, maintaining high performance ($O(1)$) while ensuring the visual display and label are dynamically updating in real-time.

* **Bulletproof Bar-Time Synchronization:**
  `LLD_Pro` employs a high-performance alignment loop that maps and aligns the prices of Symbol B directly to the timestamp of Symbol A's bars using the native `iBarShift(..., false)` and `iClose` combination. It guarantees perfect chronological alignment on any timeframe and resolves data-gap blankness.

* **Timer-Driven Weekend Refresh:**
  Asynchronous loading of historical data on weekends often causes standard indicators to get stuck on blank screens. `LLD_Pro` registers a 1-second system timer (`OnTimer`). If data synchronization fails initially, the timer continuously checks for data availability and triggers a `ChartRedraw()` once loaded.

## 4. Parameters

* **Comparison Symbol (`InpSecondSymbol`):** The secondary symbol to correlate with (e.g., `USDX` or `BTCUSD`). Default is `BTCUSD`.
* **Rolling Window (`InpWindowSize`):** The number of historical bars used to calculate each correlation point. Default is `50`.
* **Maximum Lag (`InpMaxLag`):** The maximum number of bar shifts tested. Determines the limit of the search window for leader/follower. Default is `10`.

## 5. Usage and Interpretation

### A. Lag Scaling Across Timeframes

The physical lag time is absolute, but its representation in bars depends on the chart timeframe. If the physical delay is 15 minutes:

* On the **M1** chart, the lag is represented as **15 bars** (`Optimal Lag = 15`).
* On the **M5** chart, the lag is represented as **3 bars** (`Optimal Lag = 3`).
* On the **M15** chart, the lag is represented as **1 bar** (`Optimal Lag = 1`).
* On the **H1** chart, the delay is too small to be represented as a phase shift. The indicator will show a **Symmetrical / Gray** regime (`Optimal Lag = 0`) because the sub-bar offset is compressed inside a single 1-hour candle.

### B. The Contemporaneous Lockstep Phenomenon (Symmetry vs. Lead-Lag)

A significant quantitative insight occurs when pairing highly cointegrated assets within the same asset class (e.g. **BTCUSD vs. ETHUSD** or **BTCUSD vs. SUIUSD**):

* Since major cryptocurrencies are highly integrated, their real-time correlations occur almost entirely at lag $k = 0$ (Contemporaneous Correlation).
* At shifted lags ($k \ge 1$), the predictive power of BTCUSD over ETHUSD is roughly equivalent to the predictive power of ETHUSD over BTCUSD ($\text{Peak}_{B \rightarrow A} \approx \text{Peak}_{A \rightarrow B}$).
* This mathematically yields $\text{LLDI} \approx 0.00000$ (Symmetrical/Gray). This flat reading is not a bug; it is a **mathematical proof of instantaneous market integration**.
* Conversely, when pairing uncorrelated or macro-driven assets (e.g. **DXY vs. BTCUSD**), clear asymmetric lead-lag relationships appear, producing non-zero, beautifully colored LLDI values with 5-decimal precision.

### C. Multi-Timeframe (MTF) Top-Down Strategy

To achieve high-probability execution, traders should apply a structured top-down filter across three timeframes:

1. **The Compass (H1 Timeframe):** Verify if the H1 LLDI is strongly Blue (Second symbol leads) or Red (Chart symbol leads) to identify the major intraday driver.
2. **The Sniper Scope (M15 Timeframe):** Once the macro direction is confirmed, look at the M15 Optimal Lag to determine the delay window (e.g. `Optimal Lag = 3` = 45 minutes).
3. **The Trigger (M5 Timeframe):** Drop down to the M5 chart. Wait for the M5 LLDI to quickly spike into the dominant color, signaling that the lag is beginning to resolve on the micro-level.
