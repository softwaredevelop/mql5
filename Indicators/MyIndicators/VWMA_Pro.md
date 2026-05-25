# Volume-Weighted Moving Average Pro (VWMA Pro)

## 1. Summary (Introduction)

The `VWMA_Pro` is an advanced, high-performance trend-following indicator designed to incorporate trading volume directly into price analysis. While traditional moving averages (like SMA or EMA) treat all bars equally regardless of trading activity, the Volume-Weighted Moving Average (VWMA) weights prices based on the volume transacted during each bar.

This results in a moving average that reacts faster and more accurately during high-volume market events (such as breakouts, institutional positioning, and news releases) while remaining smooth and less prone to false signals during low-volume consolidation phases.

As a core component of our professional suite, `VWMA_Pro` features complete, seamless integration with **Heikin Ashi** price structures, allowing traders to smooth out market noise while maintaining precise volume-weighted calculations.

## 2. Mathematical Foundations and Calculation Logic

The mathematical structure of the VWMA calculates the sum of the product of price and volume over a given lookback period, divided by the sum of the volume over that same period.

### Mathematical Formula

$$\text{VWMA}_t = \frac{\sum_{i=0}^{N-1} (P_{t-i} \times V_{t-i})}{\sum_{i=0}^{N-1} V_{t-i}}$$

Where:

* $P_{t-i}$ = The selected price (e.g., Close, Typical, Heikin Ashi Close) at bar $t-i$.
* $V_{t-i}$ = The volume (Real Volume or Tick Volume) at bar $t-i$.
* $N$ = The lookback period (`InpPeriod`).

### VWMA vs. SMA Comparison

To understand the impact of volume, consider a lookback period ($N$) of 3 bars:

| Bar | Price ($P$) | Volume ($V$) | $P \times V$ |
| :--- | :--- | :--- | :--- |
| Bar 1 | 100.00 | 1,000 | 100,000 |
| Bar 2 | 101.00 | 2,000 | 202,000 |
| Bar 3 | 105.00 | 7,000 | 735,000 |
| **Sum** | **-** | **10,000** | **1,037,000** |

* **Simple Moving Average (SMA):**
  $$\text{SMA} = \frac{100.00 + 101.00 + 105.00}{3} = 102.00$$

* **Volume-Weighted Moving Average (VWMA):**
  $$\text{VWMA} = \frac{1,037,000}{10,000} = 103.70$$

Because the price surge to $105.00$ on Bar 3 was backed by significantly higher volume ($7,000$), the VWMA dynamically adjusted upward to reflect true institutional buying pressure.

## 3. MQL5 Implementation Details

The architecture of `VWMA_Pro` is strictly split between data visualization and mathematical computations to ensure modularity and code reuse.

### Decoupled Engine Pattern

* **Engine (`VWMA_Calculator.mqh`):** A stateful mathematical calculator encapsulated in the class `CVWMA_Calculator`. It performs the calculations on native chronological arrays (`ArraySetAsSeries(..., false)`).
* **Wrapper (`VWMA_Pro.mq5`):** A lightweight custom indicator that manages inputs, chart display buffers, and passes price and volume arrays to the engine.

### Performance Optimization ($O(1)$)

Rather than recalculating the entire history on every tick, the engine utilizes the platform's `prev_calculated` parameter. It limits calculation to the newest bars, achieving near-instantaneous execution even on large historical charts.

### Platform-Aware Volume Selector

MT5 brokers differ in whether they provide Real Volume or only Tick Volume. The indicator checks this dynamically:

* If `SYMBOL_VOLUME_LIMIT` is greater than 0, the engine uses **Real Volume** (`volume[]`).
* If not, it automatically falls back to **Tick Volume** (`tick_volume[]`).

### Robust Error and Edge-Case Handling

* **Zero Volume Safety:** If the total volume sum within a lookback window is zero, the engine gracefully falls back to the current bar's price to prevent "Division by Zero" errors.
* **Missing Volume Fallback:** If the calculator is called from a context without volume data, it flags a warning in the terminal journal and sets the indicator buffer to `EMPTY_VALUE`, preventing the display of misleading chart data.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback window ($N$) for the average calculation. Default is `20`.
* **Applied Price (`InpSourcePrice`):** The price source used as $P$ in the formula. Supports standard MT5 prices as well as custom Heikin Ashi calculated prices:
  * Standard: Close, Open, High, Low, Median, Typical, Weighted.
  * Heikin Ashi: HA Close, HA Open, HA High, HA Low, HA Median, HA Typical, HA Weighted.

## 5. Usage and Interpretation

### A. Volume Confirmation (VWMA vs. SMA)

By plotting a VWMA and an SMA of the same period on the same chart, traders can visualize institutional participation:

* **Bullish Institutional Pressure:** When the VWMA is **above** the SMA, it means prices are rising on higher volume.
* **Bearish Institutional Pressure:** When the VWMA is **below** the SMA, it means prices are falling on higher volume.
* **Low-volume divergence:** If price rises but the VWMA falls below the SMA, the upward move lacks volume confirmation and is likely a retail trap.

### B. Breakout Validation

During major support or resistance breakouts:

* If the price crosses the VWMA on **expanding volume**, the breakout is validated.
* If the price moves past a level but the VWMA remains sluggish, the breakout is weak and prone to failure.

### C. Dynamic Support and Resistance

The VWMA acts as a highly reliable support/resistance level because it represents the average transaction price weighted by actual volume. Markets tend to retest and bounce off the VWMA line during healthy trends.
