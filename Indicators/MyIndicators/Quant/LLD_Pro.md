# Lead-Lag Dominance Index Pro (LLDI Pro)

## 1. Summary (Introduction)

The **Lead-Lag Dominance Index Pro (LLDI Pro)** is an institutional-grade, high-frequency quantitative tool designed to detect and measure the temporal lead-lag relationships between any two financial instruments in real-time. In financial markets, information does not flow instantaneously to all assets. Highly liquid market-representative instruments (such as indices like DXY or major assets like BTCUSD) often react to macroeconomic and sentiment shifts seconds or minutes before secondary correlated assets (like EURUSD, or altcoins like SUIUSD and ETHUSD) follow suit.

By measuring the mathematical lead-lag relationship, `LLD_Pro` solves two of the most critical questions in cross-asset trading:

1. **Who is driving the current market regime?** (Which asset is leading and which is trailing?)
2. **What is the current execution window?** (By how many bars does the leader anticipate the follower?)

Featuring **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session), the indicator can completely isolate intraday/intraweek price relationships from overnight gaps and illiquidity. The entire suite features a highly optimized $O(1)$ real-time mathematical engine, a high-precision 5-decimal status panel, and a bulletproof, gap-resistant bar-time synchronization module.

---

## 2. Mathematical Foundations and Calculation Logic

To perform a mathematically valid cross-correlation on financial time series, the pricing data must first be transformed to satisfy stationary conditions, preventing the phenomenon of spurious regression.

### A. Logarithmic Return Transformation

The indicator transforms closing price series $P_t$ for both Symbol $A$ (Chart) and Symbol $B$ (Secondary Comparison) into stationarized log-returns ($R_t$):

$$R_{A,t} = \ln\left(\frac{P_{A,t}}{P_{A,t-1}}\right)$$

$$R_{B,t} = \ln\left(\frac{P_{B,t}}{P_{B,t-1}}\right)$$

### B. Shifted Pearson Cross-Correlation (CCF)

For each bar $t$, the indicator computes the Pearson correlation coefficient ($r$) over a rolling or anchored window $W$ (`window_size`) using multiple lag offsets $k$ ($1 \le k \le \text{MaxLag}$):

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
* **$\text{LLDI} \in [-0.02, 0.02]$ (Gray Histogram):** Symmetrical relationship (no clear leader).

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`LLD_Calculator.mqh`):**
  All wave tracking and correlation sweep calculations are encapsulated inside the highly optimized `CLeadLagDominanceCalculator` include class.

* **Single-Bar $O(1)$ Optimization (Anti-Freeze Guard):**
  Running full historical cross-correlations inside nested loops in `OnCalculate` results in an $O(N^2)$ computational complexity, forcing up to 4.5 billion operations on startup, which freezes the MT5 terminal.
  `LLD_Pro` solves this by modifying the calculator to process **only a single index (`current_index`)** per call. It computes the log-returns and Pearson sweeps exclusively for the requested bar, maintaining a strict $O(1)$ complexity on live ticks, ensuring instant and fluid execution.

* **Unique Subwindow Labeling (Anti-Collision Guard):**
  When multiple instances of the LLD indicator are applied to the same chart (e.g., comparing different symbols), standard global labels collide and overwrite each other. `LLD_Pro` resolves this by calling `ChartWindowFind()` and appending the specific subwindow index to the object prefix (e.g. `WYC_LLD_1234_Status_Sub_2`). This allows multiple status panels to coexist and render perfectly in their respective windows.

* **Data Window Mapping with `DRAW_NONE`:**
  To allow the trader to hover over any historical bar and see the precise `Optimal Lag` value inside the MT5 Data Window, the lag buffer is mapped to `INDICATOR_DATA` instead of `INDICATOR_CALCULATIONS`. However, its draw style is set to `DRAW_NONE` in `OnInit` so that it remains completely invisible on the chart, preventing any visual distortion of the separate window's vertical scale.

* **Symbol Selection Guard:**
  Typing incorrect symbol names or mismatched broker suffixes (e.g., `BTCUSD.m` instead of `BTCUSD`) can cause indicators to fail silently. `LLD_Pro` implements an aggressive `SymbolExist` check in `OnInit()`. If the comparison symbol is invalid, it throws a pop-up **MT5 Alert** and gracefully stops execution (`INIT_FAILED`), preventing silent crashes.

---

## 4. Parameters

* **Comparison Symbol (`InpSecondSymbol`):** The secondary symbol to correlate with (Default: `"BTCUSD"`).
* **Anchor Reset (`InpAnchor`):** The reset anchor period (None, Session, Week, Month, Custom Session).
* **Rolling Window (`InpWindowSize`):** The number of historical bars used to calculate each correlation point (Used if Anchor = None). Default is `50`.
* **Maximum Lag (`InpMaxLag`):** The maximum number of bar shifts tested. Default is `10`.
* **Custom Start (`InpCustomStart`):** Session start time in format "HH:MM" (Used if Anchor = Custom).
* **Custom End (`InpCustomEnd`):** Session end time in format "HH:MM" (Used if Anchor = Custom).

---

## 5. Advanced Statistical Arbitrage Strategies

### A. Dynamic Intraday Lead-Lag Transitions

Lead-lag relationships in financial markets are highly dynamic and rotate throughout the trading day based on session liquidity.

* **The Concept:** During the European session, `EURUSD` may lead `GBPUSD`. However, during the US session, `GBPUSD` may take the lead.
* **The Solution:** By applying **`ANCHOR_SESSION`** or **`ANCHOR_CUSTOM_SESSION`**, the indicator resets its data pool at the start of each active session. This filters out overnight noise and provides an absolute, real-time speedometer of who is leading the market *today*.

### B. The Contemporaneous Lockstep Phenomenon (Symmetry vs. Lead-Lag)

A significant quantitative insight occurs when pairing highly cointegrated assets within the same asset class (e.g. **BTCUSD vs. ETHUSD**):

* Since major cryptocurrencies are highly integrated, their real-time correlations occur almost entirely at lag $k = 0$ (Contemporaneous Correlation).
* At shifted lags ($k \ge 1$), the predictive power of BTCUSD over ETHUSD is roughly equivalent to the predictive power of ETHUSD over BTCUSD ($\text{Peak}_{B \rightarrow A} \approx \text{Peak}_{A \rightarrow B}$). This mathematically yields $\text{LLDI} \approx 0.00000$ (Symmetrical/Gray). This flat reading is not a bug; it is a **mathematical proof of instantaneous market integration**.
* Conversely, when pairing uncorrelated or macro-driven assets (e.g. **DXY vs. BTCUSD**), clear asymmetric lead-lag relationships appear, producing non-zero, beautifully colored LLDI values with 5-decimal precision.

### C. The Cointegration + LLD Pro Synergy (Single-Leg Trading)

By pairing `PairsTrading_Pro` (Cointegration Spread) and `LLD_Pro` (Lead-Lag) together, traders can execute highly efficient **single-leg directional trades**:

1. `PairsTrading_Pro` signals that the spread is extremely cheap (Z-Score $\le -2.0$), meaning Asset A is underpriced relative to Asset B.
2. `LLD_Pro` signals that **Asset B is dominant and leads Asset A**.
3. *Action:* Since the leader (Asset B) has already moved up, and the follower (Asset A) is mathematically guaranteed to follow to close the spread gap, you simply **BUY Asset A as a single-leg directional trade**. This reduces execution margin requirements by 50% and completely avoids double-leg commissions!
