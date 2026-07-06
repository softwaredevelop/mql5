# John Ehlers' Linear Regression Pro Suite (Standard, MTF & Dashboard)

## 1. Summary (Introduction)

The **John Ehlers' Linear Regression Pro Suite** is an institutional-grade trend-integrity, directional velocity, and multi-asset scanning suite comprising five advanced indicators:

* `LinReg_R2_Pro` (Standard R-Squared Trend Quality)
* `LinReg_R2_MTF_Pro` (Multi-Timeframe R-Squared Trend Quality)
* `LinReg_Slope_Pro` (Standard Directional Velocity)
* `LinReg_Slope_MTF_Pro` (Multi-Timeframe Directional Velocity)
* `LinReg_R2_Dashboard_Pro` (Multi-Asset Trend-Integrity Heatmap Scanner)

Traditional momentum indicators (such as MACD or RSI) suffer from severe phase lag and cannot distinguish between a highly volatile, unstable price extension and a clean, institutional, structured trend. This suite resolves this limitation by applying **Ordinary Least-Squares Linear Regression** mathematics to price action.

Linear regression mathematically splits the current market state into two independent, highly descriptive dimensions:

1. **Trend Quality (R-Squared - $R^2$):** Bounded strictly between $0.0$ and $1.0$, $R^2$ measures the statistical strength and structural integrity of the active trend. It quantifies how closely price action fits the computed regression line, identifying consolidations (Chops) vs. clean institutional trends.
2. **Directional Velocity (Slope - $m$):** Measures the rate of price change per bar. The Slope's direction determines trend bias (positive for bullish, negative for bearish), while its amplitude defines momentum velocity.

The suite features dynamic Heikin Ashi price integration, a highly advanced **5-Zone Swapped Thermal Slope Palette**, dynamic horizontal levels, multi-asset real-time heatmap scanning, and advanced multi-timeframe step-blocking algorithms.

---

## 2. Mathematical Foundations

The core calculation engine calculates a straight line of best fit over a rolling observation window $N$ (`InpPeriod` or `InpPeriodADX`) by minimizing the sum of squared differences between price and the regression line:

### A. Slope ($m_t$ - Trend Velocity) and Intercept ($a_t$)

At each bar $t$, the price coordinates $P_i$ (Standard or Heikin Ashi) are mapped to a standard linear timeline $x_k = k$ (where $k$ runs from $0$ to $N-1$, representing oldest to newest coordinates in the window). The slope (rate of change) and intercept (starting coordinate) are calculated:

$$m_t = \frac{N \sum_{k=0}^{N-1} (k \times P_{t-N+1+k}) - \sum_{k=0}^{N-1} k \sum_{k=0}^{N-1} P_{t-N+1+k}}{N \sum_{k=0}^{N-1} k^2 - \left(\sum_{k=0}^{N-1} k\right)^2}$$

$$a_t = \frac{\sum_{k=0}^{N-1} P_{t-N+1+k} - m_t \sum_{k=0}^{N-1} k}{N}$$

### B. Linear Regression Forecast ($\text{Forecast}_t$)

The endpoint of the regression line projected onto the current active bar represents the "fair value" forecast:

$$\text{Forecast}_t = a_t + m_t \times (N - 1)$$

### C. Coefficient of Determination (R-Squared - $R^2_t$)

R-Squared quantifies the proportion of total price variance explained by the regression model. It is calculated by dividing the Regression Sum of Squares ($\text{SSR}$) by the Total Sum of Squares ($\text{SST}$):

$$\text{Mean}_P = \frac{1}{N} \sum_{k=0}^{N-1} P_{t-N+1+k}$$

$$\text{SST}_t = \sum_{k=0}^{N-1} (P_{t-N+1+k} - \text{Mean}_P)^2$$

$$\text{SSR}_t = \sum_{k=0}^{N-1} \left( (a_t + m_t \times k) - \text{Mean}_P \right)^2$$

$$R^2_t = \frac{\text{SSR}_t}{\text{SST}_t} \quad \left(0.0 \le R^2_t \le 1.0\right)$$

---

## 3. High-Resolution Precision and Thermal Color Palettes

The suite integrates several advanced visual and formatting enhancements designed for high-resolution rendering:

### A. Sub-Pip Slope Resolution Guard (7-Digit Precision)

Because the Slope represents price change per bar, on major currency pairs (such as EURUSD, where price is around $1.14100$), the slope value is naturally extremely small (e.g. `0.0000215`).

If the indicator precision is limited to standard 5 decimal places, the terminal rounds these values, causing the Data Window and legends to print flat visual values. The Slope suite resolves this by dynamically expanding the visual decimal resolution based on symbol digits:
$$\text{Indicator Digits} = \text{Symbol Digits} + 2 \quad (\text{e.g., 7 for EURUSD})$$
This is programmatically executed inside `OnInit()` using:

```mql5
IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 2);
```

### B. Symmetrical Swapped Thermal Slope Palette

`LinReg_Slope_Pro` implements an advanced, 5-zone hibrid thermal color matrix that fuses **Slope Direction** (above/below zero) with **R2 Trend Integrity** to give traders a three-dimensional representation of price momentum in a single separate subwindow without requiring a zero line:

* **Zone 0: Chop / Sideways Consolidation (`clrGray`)**
  Regardless of slope direction, if the trend integrity is weak ($R^2 \le 0.3$), the trend is classified as noise.
* **Zone 1: Bullish Flow / Weak Trend (`clrPaleGreen`)**
  Slope is positive ($m \ge 0$) but trend integrity is moderate ($0.3 < R^2 < \text{InpTrendLevel}$). Represents early trend building or minor retracements.
* **Zone 2: Bullish Climax / Strong Trend (`clrMediumSeaGreen`)**
  Slope is positive ($m \ge 0$) and trend integrity is strong ($R^2 \ge \text{InpTrendLevel}$), indicating stable institutional buying.
* **Zone 3: Bearish Climax / Strong Trend (`clrCrimson`)**
  Slope is negative ($m < 0$) and trend integrity is strong ($R^2 \ge \text{InpTrendLevel}$), indicating stable institutional selling.
* **Zone 4: Bearish Flow / Weak Trend (`clrLightCoral`)**
  Slope is negative ($m < 0$) but trend integrity is moderate ($0.3 < R^2 < \text{InpTrendLevel}$). Represents early bearish trend building or minor corrections.

```mql5
#property indicator_color1  clrGray, clrMediumSeaGreen, clrPaleGreen, clrCrimson, clrLightCoral
```

---

## 4. Multi-Asset Heatmap Scanner (LinReg R2 Dashboard)

`LinReg_R2_Dashboard_Pro` is an elite multi-asset scanner that maps the trend integrity and directional bias of up to dozens of symbols on a single chart using a space-saving thermal grid:

* **Click-to-Switch Navigation:** Clicking on any asset's label dynamically shifts the current MT5 chart to that symbol, allowing instant trade execution.
* **The Directional Arrow Trigger:** Rather than cluttering the screen with multiple buffers, each cell displays the exact $R^2$ trend integrity, accompanied by a directional trend arrow:
  * **`▲` (Bullish):** Slope is positive ($m \ge 0$).
  * **`▼` (Bearish):** Slope is negative ($m < 0$).
  * **`■` (Neutral):** Price is consolidated.
* **High-Speed Volume Routing:** The dashboard queries `SYMBOL_VOLUME_LIMIT` to dynamically feed tick volume or real exchange volume into the calculation matrix.
* **Performance-Safe Execution:** The scanner incorporates a real-time **Tick Throttling** mechanism, updating only on new bar formations or controlled tick delays to keep CPU utilization near 0.

---

## 5. Advanced MQL5 MTF Implementation Details

Both the R2 and Slope MTF indicators resolve standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Forming LTF Block Flat-Force (The Warping Solution)

To prevent real-time step warping and slope distortion on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start of current forming block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR State Stability

Since the linear regression calculations rely on a sequential, rolling history of price data, calling calculations continuously on the live forming bar on every tick could corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 6. Parameters

### A. Core Regression Settings

* **Regression Period (`InpPeriod` / `InpPeriodADX`):** The rolling window size ($N$) for the linear regression calculations (Default: `20`, Range: $\ge 2$).
* **Candle Source (`InpSource`):** Selects the price series source (`SOURCE_STANDARD` or `SOURCE_HEIKIN_ASHI`). Default: `SOURCE_STANDARD`.
* **Applied Price (`InpPrice`):** The price series source to analyze (Default: `PRICE_CLOSE`).
* **Strong Trend Level (`InpTrendLevel`):** The $R^2$ threshold marking the boundary of a strong institutional trend (Default: `0.70`).

### B. MTF Specific Settings (MTF Versions Only)

* **Target Timeframe (`InpUpperTimeframe` / `InpTimeframe`):** The target higher timeframe to calculate regression statistics on (Default: `PERIOD_H1`).

### C. Dashboard Specific Settings (Dashboard Version Only)

* **Custom Symbols list (`InpSymbols`):** Comma-separated list of symbols to scan (Default: `EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF`).

---

## 7. Quantitative Trading Strategies

### A. The Linear Regression Squeeze (R2 Breakout)

The R2 Trend Quality indicator provides a clear mathematical distinction between sideways consolidations and active breakouts:

1. **Setup:** Open `LinReg_R2_Pro` configured with a standard period of **`21`** on an M15 chart.
2. **The Squeeze:** Wait for the $R^2$ histogram to drop below the **`0.30`** level (Neutral Gray), indicating that the market is in a choppy, non-directional consolidation.
3. **The Breakout Trigger:**
   * **BUY Setup:** When $R^2$ crosses **above 0.30 and rises toward 0.70**, and the corresponding `LinReg_Slope_Pro` turns **Green** (Slope > 0). Open Long.
   * **SELL Setup:** When $R^2$ crosses **above 0.30 and rises toward 0.70**, and the corresponding `LinReg_Slope_Pro` turns **Red** (Slope < 0). Open Short.
4. **Stop-Loss:** Place the protective stop strictly beyond the consolidation zone's high/low.

### B. Thermal Slope Pullback Riding

The 5-Zone Swapped Thermal Slope Palette gives traders an instant visual cue of trend pullbacks during established trends:

1. **Setup:** Apply `LinReg_Slope_Pro` configured with a period of **`21`** on an H1 chart.
2. **Trend Definition:**
   * **Uptrend:** The histogram is green. **MediumSeaGreen** (Strong trend) indicates the trend is mature.
   * **Downtrend:** The histogram is red. **Crimson** indicates the bearish trend is mature.
3. **Execution Setup:**
   * In an established Uptrend, wait for the histogram to shift from **MediumSeaGreen** down to **PaleGreen** (or briefly to **Gray**), indicating a weak/corrective pullback while the overall direction remains positive.
   * **BUY Trigger:** Enter Long as soon as the histogram shifts back from PaleGreen to **MediumSeaGreen** (re-acceleration of the trend).
   * In a Downtrend, wait for the histogram to shift from **Crimson** up to **LightCoral** (or briefly to **Gray**). Enter Short once the histogram shifts back to **Crimson**.
4. **Stop-Loss:** Place the protective stop strictly beyond the pullback candle's extreme high/low.
