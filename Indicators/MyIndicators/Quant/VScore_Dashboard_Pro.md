# V-Score Dashboard Pro (Indicator)

## 1. Summary

**V-Score Dashboard Pro** is an institutional-grade multi-asset scanner panel designed to monitor and visualize the real-time V-Score (VWAP Z-Score) across a customized list of symbols or the entire Market Watch. It compresses market-wide volatility deviations into a highly compact, 2-column separate chart overlay table, allowing traders to instantly spot extreme overbought/oversold and trend-momentum conditions.

Featuring **Click-to-Switch** interactive chart technology, the dashboard allows traders to click on any symbol button in the table to instantly change the active chart's symbol, dramatically accelerating the workflow of quantitative scanning.

## 2. Mathematical Foundations and Calculation Logic

The dashboard leverages the core `CVScoreCalculator` engine to measure how far the current price has deviated from its Volume-Weighted Average Price (VWAP) relative to rolling standard deviation.

### A. Volatility Z-Score Formula

For each selected instrument, the engine calculates the V-Score on the target timeframe:

$$\text{V-Score}_t = \frac{C_t - \text{VWAP}_t}{\sigma_t}$$

Where:

* $C_t$ = The current closing/bid price of the asset.
* $\text{VWAP}_t$ = The Volume-Weighted Average Price computed starting from the selected anchor reset (`InpVWAPReset`).
* $\sigma_t$ = The rolling Standard Deviation of the distance between Close and VWAP over the lookback window $W$ (`InpPeriod`):

$$\sigma_t = \sqrt{\frac{1}{W} \sum_{k=0}^{W-1} (C_{t-k} - \text{VWAP}_{t-k})^2}$$

### B. Dynamic Anchor Resets

The indicator supports dynamic resets based on standard market sessions:

* **Session Reset (`PERIOD_SESSION`):** Resets daily. Excellent for intraday scalping on M5 and M15.
* **Weekly Reset (`PERIOD_WEEK`):** Resets weekly. Ideal for swing trading on H1 and H4.
* **Monthly Reset (`PERIOD_MONTH`):** Resets monthly. Perfect for medium-term portfolio allocation.

## 3. MQL5 UI & Architecture

To support real-time scanning across up to 15+ symbols simultaneously, the indicator utilizes several high-performance programming patterns:

### A. 200ms High-Frequency Tick Throttling

During periods of high volatility, hundreds of ticks can arrive per second, causing standard calculators to lag. `VScore_Dashboard_Pro` implements a software-level microsecond throttle inside `OnCalculate`. The dashboard only updates if more than **200 milliseconds** have elapsed since the last render. This maintains a fluid, real-time feel (up to 5 updates per second) while reducing CPU overhead by up to 95%.

### B. Time-Aligned MTF Synchronization

For each instrument, the indicator dynamically checks historical data availability using an aggressive history sync check (`EnsureDataReady`). It copies and aligns high-resolution rates data using a fast local `CopyClose`/`CopyTickVolume` loop, preventing terminal freezes. If historical data for a specific asset is temporarily loading, the cell displays a silver "Sync..." string instead of returning zero or freezing.

### C. Non-Flickering UI Rendering

By utilizing a strict "check-then-create" pattern inside the `CreateButton` wrapper, graphical button objects are only initialized once on the chart. Subsequent ticks only update the text, background color, and text color, preventing screen-flickering and providing a native, high-quality visual experience.

### D. Interactive Chart Switching (OnChartEvent)

Each symbol row is drawn as a flat, clickable `OBJ_BUTTON` object. The indicator intercepts mouse clicks via `OnChartEvent(CHARTEVENT_OBJECT_CLICK)`. It extracts the target symbol from the button name and immediately switches the active chart to that symbol using `ChartSetSymbolPeriod`.

## 4. Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `InpCustomSymbols` | string | `""` | Comma-separated list of symbols (e.g. "EURUSD,XAUUSD,BTCUSD"). Leave empty to scan all active Market Watch symbols. |
| `InpMaxSymbols` | int | `15` | Maximum number of symbol rows to display in the table to prevent screen clutter. |
| `InpTimeframe` | ENUM_TIMEFRAMES | `PERIOD_M15` | The target timeframe to compute the V-Score on. |
| `InpPeriod` | int | `21` | The rolling lookback window ($W$) for the standard deviation calculation. |
| `InpVWAPReset` | ENUM_VWAP_PERIOD | `PERIOD_SESSION` | The reset anchor for the underlying VWAP calculation (Daily/Weekly/Monthly). |
| `InpTableX` | int | `20` | Table horizontal offset from the top-left corner of the chart (in pixels). |
| `InpTableY` | int | `60` | Table vertical offset from the top-left corner of the chart (in pixels). |
| `InpFontSize` | int | `9` | Font size used for table buttons and text. |
| `InpRefreshSeconds` | int | `3` | Secondary timer interval for refreshing the dashboard when there are no ticks (e.g. on weekends). |

## 5. Thermal Zone Interpretation

The cell background and text colors are dynamically updated according to a **5-Zone Thermal Heatmap** designed to quickly identify price-to-value extremes:

[ V-Score >= 2.0 ]      ->  [ OrangeRed BG  / White Text ]  ->  Bull Extreme (Overbought / Distribution)
[ 1.5 <= V-Score < 2.0 ] ->  [ Coral BG      / Black Text ]  ->  Bull Flow    (Strong Momentum)
[ -1.5 < V-Score < 1.5 ] ->  [ White BG      / Gray Text  ]  ->  Neutral      (Mean Reversion Noise)
[ -2.0 < V-Score <= -1.5]->  [ LightSkyBlue  / Black Text ]  ->  Bear Flow    (Strong Momentum)
[ V-Score <= -2.0 ]      ->  [ DeepSkyBlue BG/ White Text ]  ->  Bear Extreme (Oversold / Accumulation)

### Practical Trading Workflows

1. **The Outlier Hunt (Mean Reversion):** Keep the dashboard visible in the corner of your main workspace. Look for cells that turn **DeepSkyBlue** (Oversold) or **OrangeRed** (Overbought). Click on the symbol button to switch your chart to that asset, and seek reversal patterns (such as exhaustion candles or divergence).
2. **The Flow Follower (Momentum):** If a cell turns **Coral** or **LightSkyBlue**, it means the asset has entered a "Flow" regime (breaking past the 1.5 "Point of No Return"). This indicates a strong institutional trend is underway. Switch to the chart to find continuation pullbacks.
