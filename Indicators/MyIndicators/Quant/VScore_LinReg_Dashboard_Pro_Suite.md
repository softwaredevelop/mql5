# Unified V-Score & Linear Regression R2/Slope Scanner Pro Suite

## 1. Summary (Introduction)

The **Unified V-Score & Linear Regression R2/Slope Scanner Pro Suite** is an institutional-grade, high-performance quantitative market scanning and chart-HUD suite comprising two advanced indicators:

* `VScore_LinReg_Dashboard_Pro` (Multi-Asset Scanner Dashboard)
* `VScore_LinReg_Widget_Pro` (Minimalist Single-Asset Chart HUD Widget)

In modern algorithmic trading, relying on a single indicator class generates significant blind spots. Trend-following indicators fail during range consolidations, while mean-reversion oscillators suffer heavy losses during strong trend expansions. This suite resolves this fundamental conflict by fusing **statistical volatility boundaries** with **least-squares trend integrity** in a highly optimized, space-saving real-time separate or chart-overlay matrix.

Traders can deploy two distinct configurations depending on their workflow:

1. **The Multi-Asset Scanner (`VScore_LinReg_Dashboard_Pro`):** Displays a comprehensive hőtérkép grid of up to dozens of assets simultaneously, enabling traders to identify opportunities across the entire market from a single chart.
2. **The Single-Asset Chart HUD Widget (`VScore_LinReg_Widget_Pro`):** Positioned discretely in the bottom-left corner of the chart, this minimalist 2-row, 3-column widget automatically tracks whichever symbol is currently active, providing high-resolution higher-timeframe (MTF) trend and volatility status without cluttering price action.

---

## 2. Mathematical Foundations

The calculation pipeline consists of five cascading mathematical steps executed on every bar to translate raw price action into dynamic, volume-weighted adaptive coordinates:

### A. Dynamic Volatility Mean-Reversion (V-Score - $V_t$)

The V-Score is calculated recursively by normalising the distance of price ($P$) from its volume-weighted moving average (VWAP) using the rolling standard deviation ($\sigma_{\text{VWAP}}$) calculated over the lookback period $N_{\text{VS}}$ (`InpVScorePeriod`):

$$\text{V-Score}_t = \frac{P_t - \text{VWAP}_t(\text{Reset})}{\sigma_{\text{VWAP}, t}}$$

Where the VWAP anchor reset is governed by `InpVWAPReset` (typically `PERIOD_SESSION`).

### B. Linear Regression Slope ($m_t$ - Trend Velocity) and Intercept ($a_t$)

Linear Regression mathematically calculates the rate of price change per bar ($m_t$) and the starting coordinate ($a_t$) over a rolling observation window $N_{\text{LR}}$ (`InpLinRegPeriod` or `InpPeriod`) by minimizing the sum of squared errors:

$$m_t = \frac{N_{\text{LR}} \sum_{k=0}^{N_{\text{LR}}-1} (k \times P_{t-N_{\text{LR}}+1+k}) - \sum_{k=0}^{N_{\text{LR}}-1} k \sum_{k=0}^{N_{\text{LR}}-1} P_{t-N_{\text{LR}}+1+k}}{N_{\text{LR}} \sum_{k=0}^{N_{\text{LR}}-1} k^2 - \left(\sum_{k=0}^{N_{\text{LR}}-1} k\right)^2}$$

$$a_t = \frac{\sum_{k=0}^{N_{\text{LR}}-1} P_{t-N_{\text{LR}}+1+k} - m_t \sum_{k=0}^{N_{\text{LR}}-1} k}{N_{\text{LR}}}$$

### C. Coefficient of Determination (R-Squared - $R^2_t$)

R-Squared quantifies how closely price action fits the computed regression line, bounded strictly between $0.0$ and $1.0$:

$$R^2_t = \frac{\text{SSR}_t}{\text{SST}_t} \quad \left(0.0 \le R^2_t \le 1.0\right)$$

Where $\text{SSR}_t$ is the regression sum of squares and $\text{SST}_t$ is the total sum of squares.

---

## 3. Volatility-Trend Matrix (Swapped Thermal Palette)

To represent the progressive build-up of market momentum, both the scanner and the widget utilize unified, standardized thermal coloring systems:

### A. V-Score Volatility Heatmap Colors

Displays the raw V-Score value. It uses the institutional **Swapped Thermal Palette** (Blue for Bullish, Red/Coral for Bearish, aligned with Heikin Ashi candle colors) to signify statistical extremities:

* **$\ge 2.0$:** `clrOrangeRed` (Bullish Extreme / Liquidity Exhaustion)
* **$\ge 1.5$:** `clrCoral` (Bullish Flow / Volatility Expansion)
* **$\le -2.0$:** `clrDeepSkyBlue` (Bearish Extreme / Liquidity Exhaustion)
* **$\le -1.5$:** `clrLightSkyBlue` (Bearish Flow / Volatility Expansion)
* **Otherwise:** `clrWhite` with `clrDarkGray` text (Equilibrium / Noise)

### B. LinReg R2 Trend Quality & Slope Direction

Displays the $R^2$ trend integrity, accompanied by a directional trend arrow based on the Slope:

* **`▲` (Bullish Bias):** Slope is positive ($m \ge 0$).
* **`▼` (Bearish Bias):** Slope is negative ($m < 0$).
* **`■` (Neutral Bias):** Slope is flat ($m = 0$).
The cell background color adapts dynamically to the $R^2$ trend-strength levels:
* **$\ge \text{InpTrendLevel}$ (default 0.7):** `clrMediumSeaGreen` (Strong Trend)
* **$\le 0.3$:** `clrSlateGray` (Chop / Sideways consolidation)
* **Otherwise:** `clrOrange` (Weak / Transitioning Trend)

---

## 4. Multi-Asset Dashboards vs. Chart HUD Widgets

The suite offers two distinct layouts optimized for different stages of the quantitative trading workflow:

```text

               [MULTI-ASSET SCANNER DASHBOARD]
           Positioned at InpTableY (e.g. top-left)
+---------------+---------------+---------------+
| Symbol (M15)  |    V-Score    |   R2 & Slope  |
+---------------+---------------+---------------+
|    EURUSD     |     1.165     |    ▲ 0.235    |
|    GBPUSD     |    -1.123     |    ▼ 0.343    |  <-- Switch chart on click
|    USDJPY     |     1.082     |    ▲ 0.797    |
+---------------+---------------+---------------+

                                 ||
                                 || Switch Chart
                                 \/

                  [SINGLE-ASSET CHART HUD WIDGET]
             Positioned at bottom-left (CORNER_LEFT_LOWER)
+-----------------------------------------------+
| Symbol (H1)   |    V-Score    |   R2 & Slope  |  Y = InpTableY + row_h + 2
+---------------+---------------+---------------+
|    EURUSD     |     1.165     |    ▲ 0.235    |  Y = InpTableY (e.g. 20px)
+---------------+---------------+---------------+

```

### A. The Multi-Asset Scanner Dashboard (`VScore_LinReg_Dashboard_Pro`)

* **Purpose:** Multi-market scanning and filtration.
* **Layout:** Displays multiple rows, each corresponding to a different asset selected from the Market Watch or a custom comma-separated string list.
* **Interaction:** Clicking any symbol's button dynamically changes the active chart's symbol to that asset, acting as an interactive trading portal.

### B. The Single-Asset Chart HUD Widget (`VScore_LinReg_Widget_Pro`)

* **Purpose:** Focused execution and higher-timeframe trend/volatility status monitoring.
* **Layout:** Displays a minimalist 2-row, 3-column table positioned discreetly in the bottom-left corner (`CORNER_LEFT_LOWER`).
* **Symbol Coupling:** No symbol list input is required. The widget automatically and dynamically reads the active chart's symbol (`_Symbol`). If the user switches symbols, the widget instantly updates.
* **Y-Coordinate Inversion:** Because the bottom-left corner measuring grows **upwards** from the bottom edge of the chart:
  * The **Data Row** is positioned closer to the bottom at `InpTableY` (e.g., 20 pixels).
  * The **Header Row** is positioned above the data row at `InpTableY + row_h + 2` (e.g., 44 pixels).
  This keeps the layout perfectly structured, compact, and aligned.

---

## 5. Performance-Safe Engineering (Zero-Copy & Throttling)

Running multi-asset scans across dozens of currency pairs can easily crash a standard terminal. The Pro Suite resolves this by utilizing professional performance safety layers:

* **Real-Time Tick Throttling:**
  The `OnCalculate` event restricts refresh operations to a minimum interval of 200 milliseconds (maximum 5 updates per second), filtering out high-frequency tick noise and keeping CPU utilization near 0%. A background timer (`OnTimer`) refreshes the grid every `InpRefreshSeconds` (default: 3 seconds) during low-volatility periods.
* **Zero-Leak Stack Allocation:**
  All calculator classes (`CVScoreCalculator` and `CLinearRegressionCalculator`) are instantiated directly on the stack inside retrieval functions. This avoids heap allocations (`new`/`delete` operators), completely eliminating memory fragmentation and leak vulnerabilities.
* **Asynchronous History Loading (`EnsureDataReady`):**
  Prevents thread blocking while history is loading. If an asset is not yet synchronized, the scanner prints `Sync...` and moves on to the next asset, preventing frozen charts on startup.

---

## 6. Parameters

### A. Scanner / Widget Settings

* **Custom Symbols (`InpCustomSymbols` - Dashboard Only):** Comma-separated list of symbols to scan. If left blank, the scanner automatically imports all active symbols from the Market Watch window.
* **Maximum Symbols (`InpMaxSymbols` - Dashboard Only):** The maximum number of symbols displayed in the scanner (Default: `15`).
* **Target Timeframe (`InpTimeframe`):** The target timeframe to calculate all values on (Default: `PERIOD_M15`).
* **Background Timer Refresh (`InpRefreshSeconds`):** Background timer fallback update interval (Default: `3`).

### B. V-Score Settings

* **V-Score Period (`InpVScorePeriod`):** The lookback period ($N_{\text{VS}}$) for the volatility calculations (Default: `21`).
* **VWAP Anchor Reset (`InpVWAPReset`):** The anchor reset cycle for the VWAP centerline (Default: `PERIOD_SESSION`).

### C. Linear Regression Settings

* **Regression Period (`InpLinRegPeriod`):** The lookback window ($N_{\text{LR}}$) for the linear regression calculations (Default: `20`).
* **Strong Trend Level (`InpTrendLevel`):** The $R^2$ threshold marking the boundary of a strong trend (Default: `0.70`).

### D. Placement Settings

* **Table X Offset (`InpTableX`):** Horizontal positioning offset in pixels (Default: `20`).
* **Table Y Offset (`InpTableY`):** Vertical positioning offset in pixels (Default: `60` for Dashboard, `30` for Widget).
* **UI Font Size (`InpFontSize`):** Font size used inside button objects (Default: `9`).

---

## 7. Advanced Trading Strategies

### A. The Institutional Top-Down Quantitative Workflow

By combining the Multi-Asset Scanner Dashboard on a secondary screen with the Chart HUD Widget on your execution charts, you establish a seamless, highly professional top-down trading routine:

```text

+-------------------------------------------------------------+
|               [STEP 1: MULTI-ASSET SCANNING]                |
|  Run VScore_LinReg_Dashboard_Pro on separate M15/H1 chart   |
|                                                             |
|  *Scan for: V-Score at Extreme (-2.135 Blue)                |
|* Filter: R2 at Chop (Gray / 0.070)                          |
|  *Signal: Perfect Liquidity Reversal Setup!                 |
+-------------------------------------------------------------+
                              ||
                              || Click Symbol Button
                              \/
+-------------------------------------------------------------+
|                 [STEP 2: CHART TRANSITION]                  |
|  Active chart switches automatically (e.g. to AUDUSD, M1)   |
+-------------------------------------------------------------+
                              ||
                              || Verify Local Setup
                              \/
+-------------------------------------------------------------+
|                [STEP 3: EXECUTION & HUD TRADING]            |
|* Execute Long entry on local M1.                            |
|  *Keep eyes on the bottom-left VScore_LinReg_Widget_Pro     |
|    which displays the H1/M15 macro-state.                   |
|* Maintain position as long as macro R2 stays Gray/Orange,   |
|    confirming mean reversion back to H1 VWAP.               |
+-------------------------------------------------------------+

```

### B. Scalping on Lower Timeframes with Macro Volatility Anchors

Trading short-term chart configurations (M1/M3) without macro context often leads to taking trades directly into large-scale institutional walls.

1. **The Setup:** Open an M1 or M3 chart for execution. Apply `VScore_LinReg_Widget_Pro` set strictly to **`PERIOD_M15`** or **`PERIOD_H1`**.
2. **The Volatility Anchor:** Monitor the V-Score column inside the bottom-left widget. If the macro H1 V-Score is trading at `1.850` (Bullish Extreme - Coral/Red), the price has reached its macro statistical expansion boundary.
3. **Execution:**
   * On your local M1 chart, strictly look for **short entry setups** (reversals).
   * Even if local indicators suggest buying, the macro widget confirms that the asset has hit a major volatility resistance zone, giving your short trades an exceptionally high win-rate.
   * Place your stop-loss strictly beyond the high of the M1 setup candle, targeting the local VWAP centerline.
