# Pairs Trading Cointegration Pro Suite (Oscillator & Bands)

## 1. Summary

The **Pairs Trading Cointegration Pro Suite** is an institutional-grade, high-performance separate window statistical arbitrage trading suite comprising two advanced indicators: `PairsTrading_Pro` (Z-Score separate window oscillator) and `PairsTrading_Bands_Pro` (Main-chart overlay bands). Based on Modern Portfolio Theory and econometric cointegration, the suite decomposes the pricing relationship of two correlated assets into a stationary, volatility-normalized spread.

While traditional retail pairs trading methods rely on simple price correlation (which is highly unstable and prone to structural drift), the `PairsTrading_Pro` suite utilizes a dynamic rolling **Ordinary Least Squares (OLS) mathematical engine**. It dynamically calculates the rolling Hedge Ratio ($\beta$) and Intercept ($\alpha$) between any two assets to extract the true stationary spread.

Featuring **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session), the indicators can completely isolate intraday/intraweek price relationships from overnight gaps and illiquidity, delivering a highly visual and robust quantitative scanner system.

---

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on synchronized close prices for Asset $A$ ($P_{A,t}$) and Asset $B$ ($P_{B,t}$) over an active rolling or anchored window of size $N$ (`window_size`):

### A. Rolling Ordinary Least Squares (OLS)

The calculator computes the rolling mean of Asset $A$ ($\bar{A}$) and Benchmark $B$ ($\bar{B}$). It then solves the OLS regression of $A$ on $B$ to find the dynamic Hedge Ratio ($\beta$) and Intercept ($\alpha$):

$$\beta_i = \frac{\text{Covariance}(A, B)}{\text{Variance}(B)}$$

$$\alpha_i = \bar{A}_i - (\beta_i \times \bar{B}_i)$$

### B. Dynamic Spread and Standard Deviation

The spread at each bar $t$ within the window is calculated. Because we subtract the OLS intercept ($\alpha_i$), the rolling mean of this spread over the window is **algebraically guaranteed to be exactly 0.0**:

$$\text{Spread}_{t} = P_{A,t} - \beta_i P_{B,t} - \alpha_i \quad \text{for } t = i-N+1 \dots i$$

The sample standard deviation ($\sigma_{\text{spread}}$) of the spread over the active window is computed as:

$$\sigma_{\text{spread}} = \sqrt{\frac{1}{N-1} \sum_{k=0}^{N-1} (\text{Spread}_{i-k})^2}$$

### C. Separate Window Z-Score (PairsTrading_Pro)

The final Z-Score is calculated, representing how many standard deviations the current spread has drifted away from its statistical equilibrium of $0.0$:

$$Z_i = \frac{P_{A,i} - \beta_i P_{B,i} - \alpha_i}{\sigma_{\text{spread}}}$$

* **$Z \ge 2.0$ (OrangeRed Histogram):** Spread is extremely overvalued (Short A, Long B).
* **$Z \le -2.0$ (DeepSkyBlue Histogram):** Spread is extremely undervalued (Long A, Short B).
* **$Z \in [-1.5, 1.5]$ (Gray Histogram):** Symmetrical neutral noise zone.

### D. Main Chart Cointegration Bands (PairsTrading_Bands_Pro)

By rearranging the spread equation back to the price space of Asset $A$, we project the dynamic statistical boundaries directly onto the main price chart:

$$\text{Center Line (Equilibrium / } Z=0.0\text{):} \quad \hat{P}_{A,i} = \beta_i P_{B,i} + \alpha_i$$

$$\text{Outer Upper Band (Extreme / } Z=+M_{\text{outer}}\text{):} \quad \text{Band}_{\text{up, outer}} = \hat{P}_{A,i} + M_{\text{outer}} \times \sigma_{\text{spread}}$$

$$\text{Outer Lower Band (Extreme / } Z=-M_{\text{outer}}\text{):} \quad \text{Band}_{\text{low, outer}} = \hat{P}_{A,i} - M_{\text{outer}} \times \sigma_{\text{spread}}$$

$$\text{Inner Upper Band (Warning / } Z=+M_{\text{inner}}\text{):} \quad \text{Band}_{\text{up, inner}} = \hat{P}_{A,i} + M_{\text{inner}} \times \sigma_{\text{spread}}$$

$$\text{Inner Lower Band (Warning / } Z=-M_{\text{inner}}\text{):} \quad \text{Band}_{\text{low, inner}} = \hat{P}_{A,i} - M_{\text{inner}} \times \sigma_{\text{spread}}$$

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`PairsTrading_Calculator.mqh`):**
  All covariance, variance, rolling OLS, and Z-Score computations are encapsulated inside the highly optimized `CPairsTradingCalculator` include class. It exposes public getter methods (`GetBeta()`, `GetAlpha()`, `GetStdDev()`) to feed calculated coefficients directly to the main-chart bands wrapper, completely eliminating redundant loops and guaranteeing 100% data alignment.

* **Strict $O(1)$ Real-Time Tick Optimization:**
  The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. This keeps CPU usage at absolute zero, allowing both the separate-window histogram and the main-chart bands to update live in real-time.

* **VWAP-Style Anchored Resets:**
  In addition to standard rolling windows (`InpLookback`), the indicators support dynamic resets:
  * **Daily Reset (`ANCHOR_SESSION`):** Resets daily. Excellent for intraday trading.
  * **Weekly Reset (`ANCHOR_WEEK`):** Resets weekly. Ideal for swing trading.
  * **Custom Session (`ANCHOR_CUSTOM_SESSION`):** Resets at a user-defined broker-time range (e.g. `09:00` to `18:00`). It completely filters out overnight gaps and illiquid trading hours, plotting `EMPTY_VALUE` during inactive periods to keep statistics pure.

* **Advanced Bar-Time Synchronization:**
  Assets do not always share identical trading calendars or liquidity densities. `PairsTrading_Pro` aligns Symbol A and Symbol B prices perfectly by timestamp using `iBarShift(..., false)` and `iClose`, ensuring that different market open/close times do not distort the calculation. To ensure chart-independence, the synchronization uses a dedicated `iClose` fallback rather than the local chart's `close[0]`.

* **Hardlocked Separate Window Scale Bounds `[-3.5, 3.5]`:**
  To prevent single extreme black-swan spikes (e.g., Z-score hitting $-10.0$ during weekend gaps) from squishing the entire historical chart into an unreadable flat line, the separate window's scale is fixed between `-3.5` and `3.5`. Outliers are simply clipped at the boundaries, maintaining a perfect, consistent visual aspect ratio across all timeframes.

---

## 4. Parameters

### A. Common Parameters

* **Symbol A (`InpSymbolA`):** The primary asset to trade (Default: `"UKOIL"` - Brent Crude Oil).
* **Symbol B (`InpSymbolB`):** The secondary benchmark asset (Default: `"USOIL"` - WTI Crude Oil).
* **Anchor Reset (`InpAnchor`):** The reset anchor period (None, Session, Week, Month, Custom Session).
* **Lookback (`InpLookback`):** The rolling regression window size (Used if Anchor = None).
* **Custom Start (`InpCustomStart`):** Session start time in format "HH:MM" (Used if Anchor = Custom).
* **Custom End (`InpCustomEnd`):** Session end time in format "HH:MM" (Used if Anchor = Custom).

### B. Bands Specific Parameters

* **Draw Center Line (`InpDrawCenterLine`):** Toggle to draw the gold Equilibrium Center Line ($Z=0.0$).
* **Draw Inner Bands (`InpDrawInnerBands`):** Toggle to draw the dotted Coral/LightSkyBlue Warning Bands ($Z=\pm 1.5$).
* **Inner Band Multiplier (`InpInnerMultiplier`):** The Z-Score multiplier for the inner bands (Default: `1.5`).
* **Draw Outer Bands (`InpDrawOuterBands`):** Toggle to draw the dashed Crimson/DeepSkyBlue Extreme Bands ($Z=\pm 2.0$).
* **Outer Band Multiplier (`InpOuterMultiplier`):** The Z-Score multiplier for the outer bands (Default: `2.0`).

---

## 5. Advanced Statistical Arbitrage Strategies

### A. Classic Spread Execution (Mean Reversion)

* **Buy the Spread (Z-Score $\le -2.0$ or Price touches Lower Outer Band):** Symbol A is extremely underpriced relative to Symbol B.
  * *Action:* **BUY Symbol A** (Long) and **SELL Symbol B** (Short) with equal cash exposure.
* **Sell the Spread (Z-Score $\ge 2.0$ or Price touches Upper Outer Band):** Symbol A is extremely overpriced relative to Symbol B.
  * *Action:* **SELL Symbol A** (Short) and **BUY Symbol B** (Long) with equal cash exposure.
* **The Exit (Z-Score $\to 0.0$ or Price touches Center Line):** When the spread returns to its statistical equilibrium, close both legs simultaneously to lock in the mean-reversion profit.

### B. The Quant-Grade Synergy: Cointegration + LLD Pro (Single-Leg Trading)

A major drawback of classic pairs trading is that opening two legs is capital-intensive and subject to double-broker execution slippage. By combining `PairsTrading_Pro` with the **`LLD_Pro` (Lead-Lag Dominance)** indicator, you can trade **a single, high-probability leg**:

1. **Identify the Spread Extremes:** `PairsTrading_Pro` alerts you that the spread is extremely cheap (e.g., $Z = -2.5$, meaning Symbol A is cheap, Symbol B is expensive).
2. **Identify the Leader:** Open the `LLD_Pro` indicator for the two symbols.
   * **If Symbol B (WTI) is the Leader (leads Symbol A / Brent):** WTI has already moved, and Brent (Symbol A) is mathematically guaranteed to follow to close the gap. Since Symbol A is currently too cheap, you simply **BUY Symbol A (Brent) as a single directional trade!**
   * This allows you to trade with half the margin requirement and zero execution hassle, leveraging the leader's predictive momentum to capture the gap-reversal.

---

## 6. Optimized Global Multi-Asset Presets

To ensure statistical validity, only trade assets that share a **fundamental, structural, or macroeconomic link**. Below are the most robust, cointegrated global pairs optimized for live execution, mapped in `PairsTrading_Preset_Manager.mqh`:

| Asset Class | Symbol A | Symbol B | Recommended TF | Lookback / Anchor | Inner / Outer Mult | Trading Style & Concept |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Energies** | `UKOIL` (Brent) | `USOIL` (WTI) | `M5` / `M15` | `120` / `ANCHOR_NONE` | `1.5` / `2.0` | **Crude Oil Spread.** Sweet/Light vs. Heavy/Sour grade arbitrage. Heavily mean-reverting. |
| **Precious Metals** | `XAUUSD` (Gold) | `XAGUSD` (Silver) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` | **Gold-to-Silver Ratio.** Decades-old commodity value parity. Highly stable weekly anchors. |
| **Forex Majors** | `EURUSD` | `GBPUSD` | `M5` / `M15` | `120` / `ANCHOR_CUSTOM_SESSION` <br>*(e.g., 09:00 - 18:00)* | `1.5` / `2.0` | **European Relative Value.** High cointegration due to close UK-Eurozone macro ties. Custom session filters out overnight illiquidity. |
| **Forex Commodity** | `AUDUSD` | `NZDUSD` | `M15` / `H1` | `120` / `ANCHOR_SESSION` | `1.5` / `2.0` | **Aussie vs. Kiwi.** Commodity export-driven Oceanic currencies. Daily reset captures session shifts beautifully. |
| **Equity Indices** | `US100` (Nasdaq) | `US500` (S&P500) | `M15` / `H1` | `144` / `ANCHOR_WEEK` | `1.5` / `2.0` | **Growth vs. Broad Market.** Tech sector rotations vs. global indexing. Excellent weekly trend reversion. |
| **Equity Indices** | `DE40` (DAX) | `EU50` (Stoxx50) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` | **European Equity Arbitrage.** Germany's industrial core vs. broader Eurozone blue-chip baskets. |
| **MAG7 Tech** | `NVDA` (Nvidia) | `AMD` (AMD) | `H1` / `H4` | `60` / `ANCHOR_NONE` | `1.8` / `2.5` | **Semiconductor Sector Spread.** Extreme retail/AI hype valuation discrepancies. Higher multipliers filter stock gap volatility. |
