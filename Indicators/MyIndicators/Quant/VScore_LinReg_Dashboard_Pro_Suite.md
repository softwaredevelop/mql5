# Unified V-Score & Linear Regression R2/Slope Scanner Pro Suite

## 1. Summary (Introduction)

The **Unified V-Score & Linear Regression R2/Slope Scanner Pro Suite** is an institutional-grade, multi-asset quantitative market scanner designed as the ultimate dashboard companion:

* `VScore_LinReg_Dashboard_Pro`

In modern algorithmic trading, relying on a single indicator class generates significant blind spots. Trend-following indicators fail during range consolidations, while mean-reversion oscillators suffer heavy losses during strong trend expansions. This dashboard resolves this fundamental conflict by fusing **statistical volatility boundaries** with **least-squares trend integrity** in a highly optimized, space-saving real-time hőtérkép matrix.

By monitoring up to dozens of assets simultaneously across three compact columns, the scanner gives quantitative traders an instant bird's-eye view of both volatility expansions and structural trend quality.

---

## 2. The Quantitative Synergy Concept (Volatility vs. Trend Integrity)

The scanner represents a multi-dimensional approach to market analysis, mapping volatility and trend structure into a cohesive decision matrix:

### A. Volatility Mapping (The V-Score)

The V-Score measures how far the price has stretched relative to its volume-weighted average price (VWAP), expressed in standard deviations (Sigma units). It identifies absolute liquidity pools, institutional imbalances, and overbought/oversold exhaustion zones.

### B. Trend Quality Mapping (The Linear Regression $R^2$ & Slope)

Linear Regression mathematically measures the speed of price change per bar (Slope) and quantifies how closely price action fits the regression line (R-Squared). $R^2$ filters out random noise and identifies whether a movement is a volatile tüske or a highly structured, institutional trend.

### C. The Volatility-Trend Synergy Matrix

Combining these two independent metrics unlocks highly precise directional filters:

| Market Scenario | V-Score State | R-Squared ($R^2$) State | Slope Bias | Quantitative Interpretation & Tactical Action |
| :--- | :--- | :--- | :---: | :--- |
| **Liquidity Exhaustion (Mean Reversion)** | Extreme High/Low ($\ge \pm 2.0$) | Low / Chop ($\le 0.30$) | Any | **High-Probability Pivot Zone.** Price is extremely overextended, but the trend has no structural backing. High probability of rapid mean reversion back to VWAP. Prepare to trade reversals. |
| **Trend Acceleration (Breakout Run)** | Neutral / Expanding ($[0.0, 1.5]$) | Strong ($\ge 0.70$) | Positive (`▲`) / Negative (`▼`) | **Clean Trend Continuation.** Price is stably breaking out. The trend is highly structured and supported by institutional volume. Join the trend on pullbacks. |
| **Institutional Squeeze (Trend Climax)** | Extreme High/Low ($\ge \pm 2.0$) | Strong ($\ge 0.70$) | Positive (`▲`) / Negative (`▼`) | **Trend Climax / Short Squeeze.** Price is highly overextended but the trend is exceptionally structured. **Do not short against a strong bull climax!** Wait for the $R^2$ to contract first. |
| **Sideways Chop (Range Consolidation)** | Neutral / Zero Axis | Low / Chop ($\le 0.30$) | Flat (`■`) | **Equilibrium / Random Noise.** Volatility is low, and price is mean-reverting randomly inside a tight range. Avoid trend entries. Scalp range boundaries using minor support/resistance. |

---

## 3. Interactive User Interface Details

The scanner is mapped to a high-contrast, minimalist separate subwindow grid:

### A. Column 1: Symbol Switcher

Displays the asset ticker (e.g. `EURUSD`, `DE40`). Each symbol acts as an **interactive, clickable button**. Clicking on a symbol button instantly switches the main MT5 chart symbol to that asset while preserving the current timeframe, enabling rapid execution.

### B. Column 2: V-Score Volatility Heatmap

Displays the real-time V-Score value. It uses the institutional **Swapped Thermal Palette** to signify statistical extremities:

* **$\ge 2.0$:** `clrOrangeRed` (Bullish Extreme / Liquidity Exhaustion)
* **$\ge 1.5$:** `clrCoral` (Bullish Flow / Volatility Expansion)
* **$\le -2.0$:** `clrDeepSkyBlue` (Bearish Extreme / Liquidity Exhaustion)
* **$\le -1.5$:** `clrLightSkyBlue` (Bearish Flow / Volatility Expansion)
* **Otherwise:** `clrWhite` with `clrDarkGray` text (Equilibrium / Noise)

### C. Column 3: R2 Trend Integrity & Slope Direction

Displays the $R^2$ coefficient mapped directly to a directional trend arrow based on the Slope:

* **`▲` (Bullish Bias):** Slope is positive ($m \ge 0$).
* **`▼` (Bearish Bias):** Slope is negative ($m < 0$).
* **`■` (Neutral Bias):** Slope is flat ($m = 0$).
The cell background color adapts dynamically to the $R^2$ trend-strength levels:
* **$\ge \text{InpTrendLevel}$ (default 0.7):** `clrMediumSeaGreen` (Strong Trend)
* **$\le 0.3$:** `clrSlateGray` (Chop / Sideways consolidation)
* **Otherwise:** `clrOrange` (Weak / Transitioning Trend)

---

## 4. Performance & Memory Safety (Institutional Standard)

Running multi-asset scanners in MT5 can often degrade terminal performance. The Pro Suite resolves this through advanced optimization:

* **Real-Time Tick Throttling:**
  The `OnCalculate` event restricts refresh operations to a minimum interval of 200 milliseconds (maximum 5 updates per second), filtering out high-frequency tick noise and keeping CPU utilization near 0%. A background timer (`OnTimer`) refreshes the grid every `InpRefreshSeconds` (default: 3 seconds) during low-volatility periods.
* **Zero-Leak Stack Allocation:**
  All calculator classes (`CVScoreCalculator` and `CLinearRegressionCalculator`) are instantiated directly on the stack inside retrieval functions. This avoids heap allocations (`new`/`delete` operators), completely eliminating memory fragmentation and leak vulnerabilities.
* **Limited History Copy Depth:**
  To optimize memory footprint, the scanner copy routines only request a minimal history buffer (300 bars) necessary to stabilize the indicators, bypassing heavy full-history arrays.

---

## 5. Parameters

### A. Scanner Asset Settings

* **Custom Symbols (`InpCustomSymbols`):** Comma-separated list of symbols to scan (e.g. `EURUSD,GBPUSD,USDJPY`). If left blank, the scanner automatically imports all active symbols from the Market Watch window.
* **Maximum Symbols (`InpMaxSymbols`):** The maximum number of symbols displayed in the rács (Default: `15`).
* **Target Timeframe (`InpTimeframe`):** The target timeframe to calculate all scanner values on (Default: `PERIOD_M15`).

### B. V-Score Settings

* **V-Score Period (`InpVScorePeriod`):** The lookback period ($N$) for the volatility calculations (Default: `21`).
* **VWAP Anchor Reset (`InpVWAPReset`):** The anchor reset cycle for the VWAP centerline (Default: `PERIOD_SESSION`).

### C. Linear Regression Settings

* **Regression Period (`InpLinRegPeriod`):** The lookback window ($N$) for the linear regression calculations (Default: `20`).
* **Strong Trend Level (`InpTrendLevel`):** The $R^2$ threshold marking the boundary of a strong trend (Default: `0.70`).

### D. Display Settings

* **Table X Offset (`InpTableX`):** Horizontal positioning offset in pixels (Default: `20`).
* **Table Y Offset (`InpTableY`):** Vertical positioning offset in pixels (Default: `60`).
* **UI Font Size (`InpFontSize`):** Font size used inside button objects (Default: `9`).

---

## 6. Advanced Scanner Core Trading Strategies

### Strategy A: The Liquidity Reversal Setup (Extreme V-Score + Low R2)

Designed to catch institutional reversals at major support/resistance levels.

1. **The Scanner Setup:** Run `VScore_LinReg_Dashboard_Pro` set to `PERIOD_M15`.
2. **The Scanner Signal:** Monitor the table for assets that exhibit:
   * **V-Score Column:** Stretched into extreme zones (either `clrOrangeRed` $\ge 2.0$ or `clrDeepSkyBlue` $\le -2.0$).
   * **R2 Column:** Colored `clrSlateGray` ($\le 0.30$), indicating that the price extension has no structured trending backing (Pure Liquidity Run).
3. **Execution:**
   * Click the symbol button to switch the chart.
   * Enter a mean-reversion trade (Short if V-Score is high, Long if V-Score is low) once the local M15 candle closes.
   * **Stop-Loss:** Place the protective stop strictly beyond the trigger candle's high/low. Target the VWAP centerline.

### Strategy B: The Trend Continuation Run (Extreme V-Score + Strong R2)

During an explosive breakout, trading against the momentum leads to heavy losses. This strategy uses the scanner to identify strong, structured trends and trade continuations on pullbacks.

1. **The Scanner Setup:** Run the scanner set to `PERIOD_M15` or `PERIOD_H1`.
2. **The Scanner Signal:** Look for assets exhibiting:
   * **V-Score Column:** Stretched into flow/extreme zones ($\ge \pm 1.5$ to $\pm 2.0$).
   * **R2 Column:** Colored strictly **`clrMediumSeaGreen`** ($\ge 0.70$), with the directional arrow pointing in the direction of the V-Score (positive arrow `▲` for positive V-Score, negative arrow `▼` for negative V-Score).
3. **Execution:**
   * Click the symbol button.
   * **Do not short against a strong bull climax!** Instead, wait for the price to pull back and test the local 20 EMA or VWAP line.
   * Enter continuation trades strictly in the direction of the macro trend once a rejection candle closes back in the trend direction.
