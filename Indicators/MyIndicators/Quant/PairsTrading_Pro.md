# Pairs Trading Cointegration Pro (Indicator)

## 1. Summary (Introduction)

The **Pairs Trading Cointegration Pro** is an institutional-grade, high-performance separate window statistical arbitrage oscillator. While traditional pairs trading methods in retail trading rely simply on price correlation (which is highly unstable and prone to terminal spread drift), `PairsTrading_Pro` measures true **cointegration** using a dynamic rolling Ordinary Least Squares (OLS) mathematical engine.

The indicator dynamically calculates the rolling Hedge Ratio ($\beta$) and Intercept ($\alpha$) between any two assets (default: Brent vs. WTI Crude Oil), extracts the volatility-normalized spread, and plots a stacioner Z-Score as a **5-Zone Thermal Color Histogram**.

Featuring **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session), the indicator can completely isolate intraday/intraweek price relationships from overnight gaps and illiquidity, making it the ultimate tool for active statistical arbitrage.

---

## 2. Mathematical Foundations and Calculation Logic

The mathematical structure dynamically recalculates the cointegrated relationship at each bar $i$ over a rolling or anchored window of size $N$ (`window_size`):

### A. Rolling Ordinary Least Squares (OLS)

The indicator calculates the rolling mean of the Asset $A$ ($\bar{A}$) and the Benchmark $B$ ($\bar{B}$). It then solves the OLS regression of $A$ on $B$ to find the dynamic Hedge Ratio ($\beta$) and Intercept ($\alpha$):

$$\beta_i = \frac{\text{Covariance}(A, B)}{\text{Variance}(B)}$$

$$\alpha_i = \bar{A}_i - (\beta_i \times \bar{B}_i)$$

### B. Dynamic Spread and standard deviation

The spread at each bar $t$ within the window is calculated. Because we subtract the OLS intercept ($\alpha_i$), the rolling mean of this spread over the window is **algebraically guaranteed to be exactly 0.0**:

$$\text{Spread}_{t} = A_{t} - \beta_i B_{t} - \alpha_i \quad \text{for } t = i-N+1 \dots i$$

The sample standard deviation ($\sigma_{\text{spread}}$) of the spread over the active window is computed:

$$\sigma_{\text{spread}} = \sqrt{\frac{1}{N-1} \sum_{k=0}^{N-1} (\text{Spread}_{i-k})^2}$$

### C. Volatility-Normalized Z-Score

The final Z-Score is calculated, representing how many standard deviations the current spread has drifted away from its statistical equilibrium of $0.0$:

$$Z_i = \frac{\text{Spread}_i}{\sigma_{\text{spread}}}$$

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`PairsTrading_Calculator.mqh`):**
  All covariance, variance, rolling OLS, and Z-Score computations are encapsulated inside the highly optimized `CPairsTradingCalculator` include class.

* **Strict $O(1)$ Real-Time Tick Optimization:**
  The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. This keeps CPU usage at absolute zero, allowing the Z-Score to update live in real-time.

* **VWAP-Style Anchored Resets:**
  In addition to standard rolling windows (`InpLookback`), the indicator supports dynamic resets:
  * **Daily Reset (`ANCHOR_SESSION`):** Resets daily. Excellent for intraday trading.
  * **Weekly Reset (`ANCHOR_WEEK`):** Resets weekly. Ideal for swing trading.
  * **Custom Session (`ANCHOR_CUSTOM_SESSION`):** Resets at a user-defined broker-time range (e.g. `09:00` to `18:00`). It completely filters out overnight gaps and illiquid trading hours, leaving the Z-Score flat/empty (`EMPTY_VALUE`) during inactive periods.

* **Advanced Bar-Time Synchronization:**
  `PairsTrading_Pro` aligns Symbol A and Symbol B prices perfectly by timestamp using `iBarShift(..., false)` and `iClose`, ensuring that different market open/close times or missing bars do not distort the calculation.

* **Hardlocked Scale Bounds `[-3.5, 3.5]`:**
  To prevent single extreme black-swan spikes (e.g., Z-score hitting $-10.0$ during oil gaps) from squishing the entire historical chart into an unreadable flat line, the separate window's scale is fixed between `-3.5` and `3.5`. Outliers are simply clipped at the boundaries, maintaining a perfect, consistent visual aspect ratio across all timeframes.

---

## 4. Parameters

* **Symbol A (`InpSymbolA`):** The primary asset to trade (Default: `"UKOIL"` - Brent Crude Oil).
* **Symbol B (`InpSymbolB`):** The secondary benchmark asset (Default: `"USOIL"` - WTI Crude Oil).
* **Anchor Reset (`InpAnchor`):** The reset anchor period (None, Session, Week, Month, Custom Session).
* **Lookback (`InpLookback`):** The rolling regression window size (Used if Anchor = None).
* **Custom Start (`InpCustomStart`):** Session start time in format "HH:MM" (Used if Anchor = Custom).
* **Custom End (`InpCustomEnd`):** Session end time in format "HH:MM" (Used if Anchor = Custom).

---

## 5. Advanced Statistical Arbitrage Strategies

### A. Classic Spread Execution (Mean Reversion)

* **Buy the Spread ($Z \le -2.0$ - DeepSkyBlue):** Symbol A is extremely underpriced relative to Symbol B.
  * *Action:* **BUY Symbol A** (Long) and **SELL Symbol B** (Short) with equal cash exposure.
* **Sell the Spread ($Z \ge 2.0$ - OrangeRed):** Symbol A is extremely overpriced relative to Symbol B.
  * *Action:* **SELL Symbol A** (Short) and **BUY Symbol B** (Long) with equal cash exposure.
* **The Exit ($Z \to 0.0$ - Gray):** When the histogram returns to the middle $0.0$ axis, the spread has returned to its statistical equilibrium. Close both legs simultaneously to lock in the mean-reversion profit.

### B. The Quant-Grade Synergy: Cointegration + LLD Pro (Single-Leg Trading)

A major drawback of classic pairs trading is that opening two legs is capital-intensive and subject to double-broker execution slippage. By combining `PairsTrading_Pro` with the **`LLD_Pro` (Lead-Lag Dominance)** indicator, you can trade **a single, high-probability leg**:

1. **Identify the Spread Extremes:** `PairsTrading_Pro` alerts you that the spread is extremely cheap (e.g., $Z = -2.5$, meaning Symbol A is cheap, Symbol B is expensive).
2. **Identify the Leader:** Open the `LLD_Pro` indicator for the two symbols.
   * **If Symbol B (WTI) is the Leader (leads Symbol A / Brent):** WTI has already moved, and Brent (Symbol A) is mathematically guaranteed to follow to close the gap. Since Symbol A is currently too cheap, you simply **BUY Symbol A (Brent) as a single directional trade!**
   * This allows you to trade with half the margin requirement and zero execution hassle, leveraging the leader's predictive momentum to capture the gap-reversal.
