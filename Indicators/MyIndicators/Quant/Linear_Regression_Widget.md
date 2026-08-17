# Institutional Linear Regression HUD Cockpit Widget (V1.00)

## Technical Specification & Operational Manual

## 1. Summary (Introduction)

The **LinReg_Widget_Pro (V1.00)** is an institutional-grade, real-time trend-integrity and directional velocity heads-up display (HUD) widget. Plotted as a highly compact, non-intrusive overlay in the bottom-left corner of the price chart (`#property indicator_chart_window`), the widget monitors the rolling **Linear Regression Coefficient of Determination ($R^2$)** and **Slope direction** for a single user-defined timeframe.

In quantitative execution, identifying the current market regime is crucial. Trend-following strategies (such as breakout or pullback-reentries) perform exceptionally well when price efficiency is high, but suffer severe drawdown during choppy consolidations. Conversely, mean-reversion strategies are highly profitable during random-walk cycles but fail during strong linear expansions.

The **Linear Regression Widget** resolves this structural classification problem by acting as an objective **Regime Filter**. It categorizes trend integrity into three logical, color-coded zones:

* **Strong Trend / High Efficiency (MediumSeaGreen):** $R^2 \ge \text{InpTrendLevel}$ (typically `0.7`). Indicates a powerful linear expansion. Optimal trend-following environment.
* **Weak Trend / Transitional Phase (Orange):** $R^2$ is between `0.3` and `InpTrendLevel`. Indicates trend initiation, deceleration, or structural transition.
* **Chop / Random Walk (SlateGray):** $R^2 \le 0.3$. Price is in a mean-reverting congestion zone. Optimal environment for mean-reversion and boundary rebounding.

---

## 2. Mathematical & Statistical Foundations

The indicator utilizes a rolling window of length $N$ (`InpLinRegPeriod`) to calculate the least-squares linear regression line $y = a + bx$:

### A. Linear Regression Slope (Velocity)

The slope ($b$) measures the directional price change per bar over the rolling window, represented as the numerator of the regression formula:

$$b = \frac{N \sum_{i=0}^{N-1} (X_i \cdot Y_i) - \sum_{i=0}^{N-1} X_i \sum_{i=0}^{N-1} Y_i}{N \sum_{i=0}^{N-1} X_i^2 - \left(\sum_{i=0}^{N-1} X_i\right)^2}$$

Where $X_i$ represents the chronological bar index ($0 \dots N-1$) and $Y_i$ represents the corresponding close price.

* **Upward Velocity ($b > 0.0$):** Plotted with an up arrow (**▲**).
* **Downward Velocity ($b < 0.0$):** Plotted with a down arrow (**▼**).
* **Flat Velocity ($b = 0.0$):** Plotted with a flat square (**■**).

### B. Coefficient of Determination ($R^2$ - Trend Strength)

The $R^2$ represents the proportion of variance in the price that is predictable from the linear model, measuring the trend's "straightness" and efficiency:

$$R^2 = \frac{\big( N\sum XY - \sum X\sum Y \big)^2}{\big[ N\sum X^2 - (\sum X)^2 \big] \big[ N\sum Y^2 - (\sum Y)^2 \big]}$$

---

## 3. The 3-Zone Dynamic Thermal Color Palette

The background and text colors of the widget button are dynamically updated based on the calculated $R^2$ value and the user-defined `InpTrendLevel` threshold:

| Zone Index | $R^2$ Value Range | Cell Background Color | Text Color | Market Microstructure State |
| :---: | :--- | :--- | :--- | :--- |
| **`+1`** | $R^2 \ge \text{InpTrendLevel}$ | **`clrMediumSeaGreen`** | `clrWhite` | **Strong Linear Trend.** Highly efficient directional flow. |
| **`0`** | $0.3 < R^2 < \text{InpTrendLevel}$ | **`clrOrange`** | `clrBlack` | **Transitional / Weak Trend.** Loss of momentum or early trend build. |
| **`-1`** | $R^2 \le 0.3$ | **`clrSlateGray`** | `clrWhite` | **Chop / Congestion.** High-noise, mean-reverting random walk. |

---

## 4. Recommended Configuration Presets

| Asset Class | Timeframe | Lookback Period ($N$) | Trend Level ($R^2$) | Quantitative Objective |
| :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | `PERIOD_M15` | `20` | `0.70` | **Execution Filter.** Confirms intraday trend strength before executing breakout strategies. |
| **Equity Indices** | `PERIOD_H1` | `15` | `0.75` | **Linear Integrity.** Detects high-velocity institutional trends during cash open hours. |
| **Cryptocurrencies** | `PERIOD_H4` | `25` | `0.65` | **Volatile Squeeze.** Normalizes cryptocurrency swings, isolating true macro directional legs. |

---

## 5. Visual & Technical Highlights

* **High-Frequency Tick Throttling (200 ms):**
  To prevent CPU bloat and chart lag during fast-moving market sessions, the widget restricts its calculations using a high-precision timer:

  ```mql5
  ulong current_ms = GetTickCount64();
  if(current_ms - g_last_update_ms >= 200)
    {
     g_last_update_ms = current_ms;
     RenderDashboard();
    }
  ```

  This guarantees that even under a heavy tick-stream, the dashboard updates at most 5 times per second.

* **Flicker-Free Object Modification:**
  The engine uses `CreateButton()` with a flat, borderless style (`BORDER_FLAT`). Rather than deleting and recreating buttons on every update (which would cause annoying flickering), the script uses `ObjectMove()` and `ObjectSetString()` to update coordinates and labels dynamically.
* **Unified Corner Anchoring:**
  All elements are anchored to `CORNER_LEFT_LOWER`. The Y-coordinates are calculated upwards ($header\_y > row\_y$), ensuring the widget stays perfectly aligned above the chart's timeline, regardless of terminal resizing.

---

## 6. HUD Cockpit Operational Playbook

Traders and automated Expert Advisors can use the widget as a master cockpit panel to make high-expectancy trend-following decisions:

### A. Algorithmic Trend-Following Go/No-Go Filter

Before activating trend-following algorithms (such as Chandelier Exit pullbacks, breakout models, or MA crossovers):

* **Execution:**
  * Check the `LinReg_Widget_Pro` background color.
  * **ALLOW Trend Trading:** If the cell is **`clrMediumSeaGreen`** ($R^2 \ge 0.7$), trend-following algorithms are highly viable due to strong linear price integrity.
  * **VETO Trend Trading:** If the cell is **`clrSlateGray`** ($R^2 \le 0.3$), block all trend-following signals. The market is in a choppy, mean-reverting congestion phase where trend-following models suffer from severe whipsaw drawdowns.

### B. Mean-Reversion Squeeze Entry

During tight consolidation phases, $R^2$ contracts deeply into the SlateGray zone. A breakout from this squeeze is imminent when the $R^2$ begins to expand rapidly.

* **Execution:**
  * Identify when the cell has been **SlateGray** ($R^2 \le 0.3$) for an extended period (market contraction).
  * Monitor for the exact transition bar where the cell turns **Orange** ($R^2 > 0.3$) and the direction arrow is pointing up (**▲**) or down (**▼**).
  * This represents an early-stage **volatility breakout entry**. Enter in the direction of the arrow, placing a tight Stop Loss outside the consolidation boundaries.
