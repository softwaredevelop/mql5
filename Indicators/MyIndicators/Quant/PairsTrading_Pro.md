# Pairs Trading Cointegration Pro Suite (Standard & MTF)

## 1. Summary

The **Pairs Trading Cointegration Pro Suite** is an institutional-grade, high-performance statistical arbitrage trading suite comprising four advanced indicators:

* `PairsTrading_Pro` (Z-Score separate window oscillator)
* `PairsTrading_Bands_Pro` (Main-chart overlay bands)
* `PairsTrading_MTF_Pro` (Multi-Timeframe separate window oscillator)
* `PairsTrading_Bands_MTF_Pro` (Multi-Timeframe main-chart overlay bands)

Based on Modern Portfolio Theory and econometric cointegration, the suite decomposes the pricing relationship of two correlated assets into a stationary, volatility-normalized spread.

While traditional retail pairs trading methods rely on simple price correlation (which is highly unstable and prone to structural drift), this suite utilizes a dynamic rolling **Ordinary Least Squares (OLS) mathematical engine**. It dynamically calculates the rolling Hedge Ratio ($\beta$) and Intercept ($\alpha$) between any two assets to extract the true stationary spread.

Featuring **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session), the indicators can completely isolate intraday/intraweek price relationships from overnight gaps and illiquidity, delivering a highly visual and robust quantitative scanner system.

---

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on synchronized close prices for Asset $A$ ($P_{A,t}$) and Asset $B$ ($P_{B,t}$) over an active rolling or anchored window of size $N$ (`window_size`):

### A. Rolling Ordinary Least Squares (OLS)

The calculator computes the rolling mean of Asset $A$ ($\bar{A}$) and Benchmark $B$ ($\bar{B}$). It solves the OLS regression of $A$ on $B$ to find the dynamic Hedge Ratio ($\beta$) and Intercept ($\alpha$):

$$\beta_i = \frac{\text{Covariance}(A, B)}{\text{Variance}(B)}$$

$$\alpha_i = \bar{A}_i - (\beta_i \times \bar{B}_i)$$

### B. Dynamic Spread and Standard Deviation

The spread at each bar $t$ within the window is calculated. Because we subtract the OLS intercept ($\alpha_i$), the rolling mean of this spread over the window is **algebraically guaranteed to be exactly 0.0**:

$$\text{Spread}_{t} = P_{A,t} - \beta_i P_{B,t} - \alpha_i \quad \text{for } t = i-N+1 \dots i$$

The sample standard deviation ($\sigma_{\text{spread}}$) of the spread over the active window is computed as:

$$\sigma_{\text{spread}} = \sqrt{\frac{1}{N-1} \sum_{k=0}^{N-1} (\text{Spread}_{i-k})^2}$$

### C. Volatility-Normalized Z-Score (PairsTrading_Pro)

The final Z-Score is calculated, representing how many standard deviations the current spread has drifted away from its statistical equilibrium of $0.0$:

$$Z_i = \frac{P_{A,i} - \beta_i P_{B,i} - \alpha_i}{\sigma_{\text{spread}}}$$

---

## 3. Cointegration Bands (Main Chart Projection)

By rearranging the spread equation back to the price space of Asset $A$, the suite projects the dynamic statistical boundaries directly onto the main price chart:

$$\text{Center Line (Equilibrium / } Z=0.0\text{):} \quad \hat{P}_{A,i} = \beta_i P_{B,i} + \alpha_i$$

$$\text{Outer Upper Band (Extreme / } Z=+M_{\text{outer}}\text{):} \quad \text{Band}_{\text{up, outer}} = \hat{P}_{A,i} + M_{\text{outer}} \times \sigma_{\text{spread}}$$

$$\text{Outer Lower Band (Extreme / } Z=-M_{\text{outer}}\text{):} \quad \text{Band}_{\text{low, outer}} = \hat{P}_{A,i} - M_{\text{outer}} \times \sigma_{\text{spread}}$$

$$\text{Inner Upper Band (Warning / } Z=+M_{\text{inner}}\text{):} \quad \text{Band}_{\text{up, inner}} = \hat{P}_{A,i} + M_{\text{inner}} \times \sigma_{\text{spread}}$$

$$\text{Inner Lower Band (Warning / } Z=-M_{\text{inner}}\text{):} \quad \text{Band}_{\text{low, inner}} = \hat{P}_{A,i} - M_{\text{inner}} \times \sigma_{\text{spread}}$$

---

## 4. The Pure vs. Hybrid MTF Dilemma

When trading in a Multi-Timeframe (MTF) environment (e.g. tracking $M5$ cointegration on an $M1$ chart), a distinct structural divergence occurs between the main-chart bands and the separate-window oscillator:

### A. The Discrepancy

You may observe the lower timeframe price (M1) pierce the M5 outer band on the main chart, while the separate-window MTF Z-Score remains neutral (Gray).

* **The Reason:** The main chart compares the **live, real-time lower-timeframe price ($P_{A, \text{ltf}}$)** against the static higher-timeframe band. If the price spikes violently during the 5-minute interval, it will visually pierce the band. However, the **Pure MTF Oscillator** computes the Z-Score using the **closed higher-timeframe price ($P_{A, \text{htf}}$)**. Since the 5-minute candle hasn't closed yet or its average close is lower, the pure HTF Z-Score remains neutral.

### B. Pure MTF vs. Hybrid MTF Configuration

* **Pure MTF (Default):** Calculates everything strictly on the higher timeframe. It provides the highest statistical stability and filters out intraday/micro-timeframe false breakouts.
* **Hybrid MTF (Optional Custom Setup):** Uses the higher timeframe's stable structural parameters ($\beta_{\text{htf}}$, $\alpha_{\text{htf}}$, and $\sigma_{\text{spread, htf}}$), but computes the Z-Score numerator using the live lower-timeframe price ($P_{A, \text{ltf}}$).
  $$\text{Z}_{\text{hybrid}} = \frac{P_{A, \text{ltf}} - \beta_{\text{htf}} P_{B, \text{ltf}} - \alpha_{\text{htf}}}{\sigma_{\text{spread, htf}}}$$
  *Under this hybrid model, the separate window Z-Score is mathematically guaranteed to cross the $\pm 2.0$ boundaries at the exact second the price pierces the bands on the main chart.*

---

## 5. Parameters

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

## 6. Optimized Global Multi-Asset Presets

To ensure statistical validity, only trade assets that share a **fundamental, structural, or macroeconomic link**. Below are the most robust, cointegrated global pairs optimized for live execution, mapped in `PairsTrading_Preset_Manager.mqh`:

| Asset Class | Symbol A | Symbol B | Recommended TF | Lookback / Anchor | Inner / Outer Mult | Trading Style & Concept |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Energies** | `UKOIL` (Brent) | `USOIL` (WTI) | `M5` / `M15` | `120` / `ANCHOR_NONE` | `1.5` / `2.0` | **Crude Oil Spread.** Sweet/Light vs. Heavy/Sour grade arbitrage. Heavily mean-reverting. |
| **Precious Metals** | `XAUUSD` (Gold) | `XAGUSD` (Silver) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` | **Gold-to-Silver Ratio.** Decades-old commodity value parity. Highly stable weekly anchors. |
| **Forex Majors** | `EURUSD` | `GBPUSD` | `M5` / `M15` | `120` / `ANCHOR_CUSTOM_SESSION` <br>*(e.g., 09:00 - 18:00)* | `1.5` / `2.0` | **European Relative Value.** High cointegration due to close UK-Eurozone macro ties. Custom session filters out overnight illiquidity. |
| **Forex Commodity** | `AUDUSD` | `NZDUSD` | `M15` / `H1` | `120` / `ANCHOR_SESSION` | `1.5` / `2.0` | **Aussie vs. Kiwi.** Commodity export-driven Oceanic currencies. Daily reset captures session shifts beautifully. |
| **Equity Indices** | `US100` (Nasdaq) | `US500` (S&P500) | `M15` / `H1` | `144` / `ANCHOR_WEEK` | `1.5` / `2.0` | **Growth vs. Broad Market.** Tech sector rotations vs. global indexing. Excellent weekly trend reversion. |
| **Equity Indices** | `DE40` (DAX) | `EU50` (Stoxx50) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` | **Group Arbitrage.** High European index cointegration due to shared Eurozone macro factors. |
