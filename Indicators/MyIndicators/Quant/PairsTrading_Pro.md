# Pairs Trading Cointegration Pro Suite (Standard & MTF)

## 1. Summary

The **Pairs Trading Cointegration Pro Suite** is an institutional-grade, high-performance statistical arbitrage trading suite comprising four advanced indicators:

* `PairsTrading_Pro` (Z-Score separate window oscillator)
* `PairsTrading_Bands_Pro` (7-line main-chart overlay bands)
* `PairsTrading_MTF_Pro` (Multi-Timeframe separate window oscillator)
* `PairsTrading_Bands_MTF_Pro` (Multi-Timeframe 7-line main-chart overlay bands)

Based on Modern Portfolio Theory and econometric cointegration, the suite decomposes the pricing relationship of two correlated assets into a stationary, volatility-normalized spread.

While traditional retail pairs trading methods rely on simple price correlation (which is highly unstable and prone to structural drift), this suite utilizes a dynamic rolling **Ordinary Least Squares (OLS) mathematical engine**. It dynamically calculates the rolling Hedge Ratio ($\beta$) and Intercept ($\alpha$) between any two assets to extract the true stationary spread.

### The Single-Symbol Paradigm & O(1) Memory Access

To maximize trading speed and simplify execution panels, the suite automatically determines **Symbol A** from the chart's native symbol (`_Symbol`). The trader only needs to input **Symbol B** (`InpSecondSymbol`) on the parameters window.

By binding Symbol A strictly to the current chart, the calculation engine accesses prices directly via the native `close[]` array inside the `OnCalculate()` function. This completely eliminates $O(N)$ lookup overheads (like `iBarShift` and `iClose`) for Symbol A, reducing tick processing time to a true $O(1)$ constant time complexity.

---

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on synchronized close prices for Asset $A$ ($P_{A,t}$, representing the native `_Symbol`) and Asset $B$ ($P_{B,t}$, representing `InpSecondSymbol`) over an active rolling or anchored window of size $N$ (`window_size`):

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

By rearranging the spread equation back to the price space of Asset $A$ (the chart's active symbol), the suite projects the dynamic statistical boundaries as a 7-channel corridor directly onto the main price chart:

### A. Equilibrium Core (Z = 0)

The Center Line represents the cointegrated fair value price of Asset A relative to Asset B:
$$\text{Center Line (Equilibrium):} \quad \hat{P}_{A,i} = \beta_i P_{B,i} + \alpha_i$$

### B. Warning Bands (Z = +-1.5 / Inner Channel)

Triggers early scale-in warning zones for potential mean-reversion trades:
$$\text{Upper Inner Band:} \quad \text{Band}_{\text{up, inner}} = \hat{P}_{A,i} + M_{\text{inner}} \times \sigma_{\text{spread}}$$
$$\text{Lower Inner Band:} \quad \text{Band}_{\text{low, inner}} = \hat{P}_{A,i} - M_{\text{inner}} \times \sigma_{\text{spread}}$$

### C. Core Entry Bands (Z = +-2.0 / Outer Channel)

Statistically represents a 95.4% probability of price containment under a normal distribution. This is the optimal entry boundary for statistical arbitrage:
$$\text{Upper Outer Band:} \quad \text{Band}_{\text{up, outer}} = \hat{P}_{A,i} + M_{\text{outer}} \times \sigma_{\text{spread}}$$
$$\text{Lower Outer Band:} \quad \text{Band}_{\text{low, outer}} = \hat{P}_{A,i} - M_{\text{outer}} \times \sigma_{\text{spread}}$$

### D. Extreme Stop-Out Bands (Z = +-2.5 / Capitulation Channel)

A high-volatility cushion representing a 98.8% probability limit. Reaching this zone suggests a severe cointegration breakdown or macro capitulation. Useful for absolute stop-losses or hyper-aggressive reversal entries:
$$\text{Upper Extreme Band:} \quad \text{Band}_{\text{up, extreme}} = \hat{P}_{A,i} + M_{\text{extreme}} \times \sigma_{\text{spread}}$$
$$\text{Lower Extreme Band:} \quad \text{Band}_{\text{low, extreme}} = \hat{P}_{A,i} - M_{\text{extreme}} \times \sigma_{\text{spread}}$$

---

## 4. The Statistically Pure Cutoff (Session-Start Noise Filtering)

When employing session anchors (`ANCHOR_SESSION` or `ANCHOR_CUSTOM_SESSION`), the active window size resets to 1 at the beginning of each active period and increments bar-by-bar.

During the first 14 bars of a session, running OLS is statistically invalid due to severe degrees-of-freedom limitations. Calculating standard deviations on 3, 5, or 8 samples yields highly erratic, spiked, and squeezed channels that create false signals and compress the chart's vertical scale.

### A. The EMPTY_VALUE Cutoff Solution

To maintain institutional quantitative standards, the bands **strictly enforce a 15-bar minimum cutoff**.

* **The Rule:** If $N_{\text{active}} < 15$ or standard deviation is $\le 0$, all 7 band buffers are populated with `EMPTY_VALUE`.
* **The Visual Benefit:** Instead of collapsing the channels onto the raw price line (which creates a messy, overlapping web of lines at the start of every session), the channels simply remain invisible during the initialization phase, rendering only when the mathematical model has stabilized.

### B. Standard vs. MTF Cutoff Widths

You will observe that Multi-Timeframe (MTF) charts display a wider blank zone at the beginning of each session compared to standard single-timeframe charts. This is a mathematically correct scaling consequence:

* On a local **M15** chart, 15 bars require exactly **3.75 hours** of market activity to stabilize.
* On an **H1 (MTF)** chart, 15 bars require exactly **15 hours** of market activity to stabilize.
* Because the higher timeframe requires longer historical duration to construct its OLS sample pool, the MTF version correctly maintains a wider blank zone, shielding the trader from pre-stabilization noise on the macro level.

---

## 5. The Pure vs. Hybrid MTF Dilemma

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

## 6. Parameters

### A. Common Parameters

* **Comparison Symbol (`InpSecondSymbol`):** The benchmark asset to correlate with (Symbol B). Symbol A is automatically set to the chart's native `_Symbol`.
* **Anchor Reset (`InpAnchor`):** The reset anchor period (None, Session, Week, Month, Custom Session).
* **Lookback (`InpLookback`):** The rolling regression window size (Used if Anchor = None). Default: `120`.
* **Custom Start (`InpCustomStart`):** Session start time in format "HH:MM" (Used if Anchor = Custom).
* **Custom End (`InpCustomEnd`):** Session end time in format "HH:MM" (Used if Anchor = Custom).

### B. Bands Specific Parameters

* **Draw Center Line (`InpDrawCenterLine`):** Toggle to draw the gold Equilibrium Center Line ($Z=0.0$).
* **Draw Inner Bands (`InpDrawInnerBands`):** Toggle to draw the dotted Coral/LightSkyBlue Warning Bands ($Z=\pm 1.5$).
* **Inner Band Multiplier (`InpInnerMultiplier`):** The Z-Score multiplier for the inner bands (Default: `1.5`).
* **Draw Outer Bands (`InpDrawOuterBands`):** Toggle to draw the dashed OrangeRed/DeepSkyBlue Core Entry Bands ($Z=\pm 2.0$).
* **Outer Band Multiplier (`InpOuterMultiplier`):** The Z-Score multiplier for the outer bands (Default: `2.0`).
* **Draw Extreme Bands (`InpDrawExtremeBands`):** Toggle to draw the solid Crimson/DodgerBlue Stop/Reversal Bands ($Z=\pm 2.5$).
* **Extreme Band Multiplier (`InpExtremeMultiplier`):** The Z-Score multiplier for the extreme bands (Default: `2.5`).

---

## 7. Optimized Global Multi-Asset Presets

To ensure statistical validity, only trade assets that share a **fundamental, structural, or macroeconomic link**. Below are the most robust, cointegrated global pairs optimized for live execution, mapped in `PairsTrading_Preset_Manager.mqh` (Symbol A is set as the chart's main active asset):

| Asset Class | Symbol A (Chart) | Symbol B (`InpSecondSymbol`) | Recommended TF | Lookback / Anchor | Inner / Outer / Extreme Mult | Trading Style & Concept |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Energies** | `UKOIL` (Brent) | `USOIL` (WTI) | `M5` / `M15` | `120` / `ANCHOR_NONE` | `1.5` / `2.0` / `2.5` | **Crude Oil Spread.** Sweet/Light vs. Heavy/Sour grade arbitrage. Heavily mean-reverting. |
| **Precious Metals** | `XAUUSD` (Gold) | `XAGUSD` (Silver) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` / `2.5` | **Gold-to-Silver Ratio.** Decades-old commodity value parity. Highly stable weekly anchors. |
| **Forex Majors** | `EURUSD` | `GBPUSD` | `M5` / `M15` | `120` / `ANCHOR_CUSTOM_SESSION` <br>*(e.g., 09:00 - 18:00)* | `1.5` / `2.0` / `2.5` | **European Relative Value.** High cointegration due to close UK-Eurozone macro ties. Custom session filters out overnight illiquidity. |
| **Forex Commodity** | `AUDUSD` | `NZDUSD` | `M15` / `H1` | `120` / `ANCHOR_SESSION` | `1.5` / `2.0` / `2.5` | **Aussie vs. Kiwi.** Commodity export-driven Oceanic currencies. Daily reset captures session shifts beautifully. |
| **Equity Indices** | `US100` (Nasdaq) | `US500` (S&P500) | `M15` / `H1` | `144` / `ANCHOR_WEEK` | `1.5` / `2.0` / `2.5` | **Growth vs. Broad Market.** Tech sector rotations vs. global indexing. Excellent weekly trend reversion. |
| **Equity Indices** | `DE40` (DAX) | `EU50` (Stoxx50) | `M15` / `H1` | `120` / `ANCHOR_WEEK` | `1.5` / `2.0` / `2.5` | **Group Arbitrage.** High European index cointegration due to shared Eurozone macro factors. |
