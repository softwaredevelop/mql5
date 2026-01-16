# Laguerre Channel Pro Suite

## 1. Summary (Introduction)

The **Laguerre Channel Pro Suite** represents a modern evolution of the classic Keltner Channel. By replacing the traditional Moving Average middle line with John Ehlers' advanced **Laguerre Filter**, these indicators offer superior responsiveness and significantly reduced lag.

The suite consists of two professional-grade indicators designed for different trading styles:

1. **`Laguerre_Channel_Pro`**: Uses a standard Laguerre Filter with a fixed, user-definable `Gamma`. Ideal for traders who want precise control over the smoothing factor.
2. **`Laguerre_Channel_Adaptive_Pro`**: Uses an **Adaptive Laguerre Filter** that dynamically adjusts its responsiveness based on the measured market cycle period. Ideal for traders seeking a "hands-off" solution that adapts to changing market conditions automatically.

Both indicators utilize **Average True Range (ATR)** bands to define dynamic support and resistance levels, creating a robust system for identifying trends, breakouts, and mean reversion opportunities.

## 2. Key Features & Architecture

* **Low-Lag Middle Line:** The core advantage is the Laguerre Filter, which tracks price action much closer than an EMA or SMA of equivalent smoothness.
* **O(1) Incremental Calculation:** Optimized for high performance. The indicators only process new bars, ensuring zero lag and minimal CPU usage even on heavy charts.
* **Unified Heikin Ashi Support:** Built-in support for all Heikin Ashi price types (Close, Open, High, Low, Median, Typical, Weighted) for both the middle line and the ATR calculation.
* **Modular Design:** Powered by our professional calculation engines (`Laguerre_Engine`, `ATR_Calculator`).

## 3. The Two Variants Explained

### A. Standard Laguerre Channel (`Laguerre_Channel_Pro`)

This version gives you full control. The responsiveness of the middle line is determined by the **Gamma** parameter ($0.0 - 1.0$).

* **Low Gamma (e.g., 0.2 - 0.4):** Very responsive, closely follows price. Good for scalping.
* **High Gamma (e.g., 0.7 - 0.85):** Very smooth, filters out noise. Good for trend following.

### B. Adaptive Laguerre Channel (`Laguerre_Channel_Adaptive_Pro`)

This version is "self-tuning". It uses a **Homodyne Discriminator** algorithm to measure the dominant cycle period of the market in real-time.

* **Cycle Measurement:** It calculates the current market cycle length (e.g., 20 bars).
* **Dynamic Gamma:** It automatically calculates the optimal `Gamma` for that cycle length.
* **Result:** The channel tightens during trends (to capture moves) and flattens out during ranging markets (to avoid whipsaws) without manual intervention.

## 4. Parameters

### Common Parameters (Both Indicators)

* **Price Source (`InpSourcePrice`):** Selects the input data.
  * *Standard:* Close, Open, High, Low, Median, Typical, Weighted.
  * *Heikin Ashi:* HA Close, HA Median, etc. (Recommended for smoother signals).
* **ATR Period (`InpAtrPeriod`):** The lookback period for volatility calculation. Default is `14`.
* **ATR Multiplier (`InpMultiplier`):** Determines the width of the channel.
  * `1.5 - 2.0`: Standard setting for trend trading.
  * `2.5 - 3.0`: Wider setting for catching extreme reversals.
* **ATR Source (`InpAtrSource`):** Allows you to calculate volatility based on:
  * `ATR_SOURCE_STANDARD`: Uses raw OHLC candles (True volatility).
  * `ATR_SOURCE_HEIKIN_ASHI`: Uses Heikin Ashi candles (Smoothed volatility).

### Specific to Standard Version

* **Gamma (`InpGamma`):** The damping factor. Default is `0.7`.
  * Higher value = Smoother line, more lag.
  * Lower value = Faster line, more noise.

## 5. Usage and Trading Strategies

### Trend Following (Breakouts)

* **Signal:** When a candle closes **outside** the channel (above the Upper Band or below the Lower Band).
* **Confirmation:** The Middle Line (Laguerre) should be sloping in the direction of the breakout.
* **Exit:** When price closes back inside the channel or crosses the Middle Line.

### Trend Pullbacks

* **Context:** In a strong trend (price is riding the Upper/Lower band).
* **Signal:** Price pulls back to touch the **Middle Line**.
* **Action:** Enter in the direction of the trend if the Middle Line holds as support/resistance.

### Mean Reversion (Ranging Markets)

* **Context:** The Middle Line is flat (horizontal).
* **Signal:** Price touches or pierces the Outer Bands.
* **Action:** Trade back towards the Middle Line.

### The "Squeeze"

* When the bands contract significantly (low ATR), it indicates a period of low volatility. This often precedes a violent breakout. The Laguerre Channel visualizes this compression clearly.
