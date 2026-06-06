# Lead-Lag Dominance Index Pro (LLDI Pro)

## 1. Summary (Introduction)

The `LLD_Pro` (Lead-Lag Dominance Index) is a high-performance quantitative trading tool designed to detect and measure the lead-lag relationships between any two financial instruments in real-time. In financial markets, information does not flow instantaneously to all assets. Highly liquid market-representative instruments (such as indices like DXY or majors like BTCUSD) often react to macroeconomic and sentiment shifts seconds or minutes before secondary correlated assets (like EURUSD or altcoins like SUIUSD, ETHUSD) follow suit.

By measuring the mathematical lead-lag relationship, `LLD_Pro` solves two of the most critical questions in cross-asset trading:

1. **Who is driving the current market regime?** (Which asset is leading and which is trailing?)
2. **What is the current execution window?** (By how many bars does the leader anticipate the follower?)

The indicator features a highly optimized mathematical engine, a minimalist dynamic separate-window status label, and a bulletproof, gap-resistant bar-time synchronization module.

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

* **Bulletproof O(1) Bar-Time Synchronization:**
  Financial instruments do not always have perfectly synchronized historical bar counts due to low liquidity periods, server restarts, or weekend gaps.
  `LLD_Pro` employs a high-performance $O(1)$ synchronization loop that maps and aligns the prices of Symbol B directly to the timestamp of Symbol A's bars using the native `iBarShift(..., false)` and `iClose` combination. It guarantees perfect chronological alignment on any timeframe without complex array resizing.

* **Timer-Driven Weekend Refresh:**
  Asynchronous loading of historical data on weekends often causes standard indicators to get stuck on blank screens. `LLD_Pro` registers a 1-second system timer (`OnTimer`). If data synchronization fails initially, the timer continuously checks for data availability and triggers a `ChartRedraw()` once loaded, ensuring the indicator renders even during weekends when ticks are absent.

* **Minimalist Status Label:**
  To maintain a clean and professional workspace, all numeric outputs are designed to be read directly from the indicator separate window header or the MT5 Data Window. The status label is strictly dedicated to displaying the active regime in a dynamically colored format:
  * **REGIME: [B] LEADS [A]** (DodgerBlue)
  * **REGIME: [A] LEADS [B]** (Crimson)
  * **REGIME: SYMMETRICAL / CO-DEPENDENT** (Gray)

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

*Rule:* To trade short physical delays, use lower timeframes (M1 to M15).

### B. Multi-Timeframe (MTF) Top-Down Strategy

To achieve high-probability execution, traders should apply a structured top-down filter across three timeframes:

1. **The Compass (H1 Timeframe):**
   * *Objective:* Determine the dominant intraday regime.
   * *Action:* Ensure that the H1 LLDI is strongly Blue (BTCUSD leads) or Red (SUIUSD leads). If H1 is Gray (Symmetrical), avoid lead-lag trading on lower timeframes as the macro-structure is disconnected.

2. **The Sniper Scope (M15 Timeframe):**
   * *Objective:* Identify lag arbitrage opportunities.
   * *Action:* Once the macro regime is confirmed (e.g., BTCUSD leads on H1), look at the M15 Optimal Lag (e.g., `Optimal Lag = 2` means a 30-minute delay). If BTCUSD breaks a key level on M15 but SUIUSD is lagging behind, you have a validated ~30-minute execution window.

3. **The Trigger (M5 Timeframe):**
   * *Objective:* Find the precise entry moment.
   * *Action:* Drop down to the M5 chart. Wait for the M5 LLDI to quickly spike into DodgerBlue. This confirms that the 30-minute lag identified on M15 is starting to resolve on the micro-level, indicating the perfect entry point.

### C. The Weekend Symmetrical/Zero-Height Phenomenon

During weekends, some brokers suspend or restrict quoting on major crypto pairs like BTCUSD while allowing altcoins like SUIUSD to tick actively.
Because BTCUSD represents a flat horizontal price line, its returns are `0.0`, resulting in a variance of `0.0`. Consequently, all Pearson correlation calculations return `0.0`, and the LLDI drops to exactly `0.0000`.
Since histogram bars with a height of `0.0` have no pixels, the rightmost part of the indicator separate window will appear completely blank (empty) during these weekend periods. On weekdays, once both markets are active, the gap will completely disappear, and the histogram will draw fully.
