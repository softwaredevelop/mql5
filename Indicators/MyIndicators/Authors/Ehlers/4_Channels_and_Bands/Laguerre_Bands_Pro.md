# Laguerre Bands Pro (Bollinger Concept)

## 1. Summary (Introduction)

The **Laguerre Bands Pro** is a sophisticated volatility indicator that merges the low-latency characteristics of John Ehlers' Laguerre Filter with the statistical robustness of Bollinger Bands®.

While traditional Bollinger Bands use a Simple Moving Average (SMA) as the centerline, this indicator employs a **Laguerre Filter**. The Laguerre Filter is renowned for its ability to smooth price data with significantly less lag than conventional averages. By calculating the standard deviation bands around this superior centerline, the Laguerre Bands Pro offers a more responsive and accurate depiction of price volatility and trend direction.

This tool is part of our **Professional MQL5 Indicator Suite**, featuring O(1) incremental calculation and full Heikin Ashi support.

## 2. Mathematical Foundations

The indicator combines two distinct mathematical concepts:

1. **The Centerline (Laguerre Filter):**
    Instead of a time-based average (like a 20-period SMA), the centerline is calculated using the Laguerre Transform. The smoothness is controlled by the **Gamma** factor ($\gamma$), not a period length.
    * $\text{Centerline}_t = \text{LaguerreFilter}(\text{Price}, \gamma)_t$

2. **The Bands (Standard Deviation):**
    The bands are calculated based on the standard deviation of the price from the Laguerre centerline over a specified lookback **Period**.
    * $\text{StdDev}_t = \sqrt{\frac{\sum_{i=0}^{N-1} (\text{Price}_{t-i} - \text{Centerline}_t)^2}{N}}$
    * $\text{Upper Band}_t = \text{Centerline}_t + (\text{Deviation} \times \text{StdDev}_t)$
    * $\text{Lower Band}_t = \text{Centerline}_t - (\text{Deviation} \times \text{StdDev}_t)$

**Key Difference from Standard Bollinger Bands:**
In standard Bollinger Bands, the standard deviation is calculated relative to the SMA. Here, it is calculated relative to the Laguerre Filter. Because the Laguerre Filter tracks the price more closely, the bands often react faster to volatility expansion and contraction.

## 3. Features & Architecture

* **Low-Lag Response:** The bands adjust to price changes much faster than standard Bollinger Bands, reducing the "lag time" before a signal is generated.
* **O(1) Incremental Calculation:** Optimized for high performance. The indicator processes only new bars, ensuring zero lag and minimal CPU usage.
* **Unified Heikin Ashi Support:** Built-in support for all Heikin Ashi price types (Close, Open, High, Low, Median, Typical, Weighted). Both the centerline and the standard deviation are calculated using the selected HA price source.
* **Modular Design:** Powered by our robust `Laguerre_Engine`.

## 4. Parameters

* **Gamma (`InpGamma`):** Controls the smoothness of the centerline. Default is `0.7`.
  * Range: $0.0$ to $1.0$.
  * Lower values (e.g., 0.5) make the line faster (less lag).
  * Higher values (e.g., 0.85) make the line smoother (more lag).
* **Source Price (`InpSourcePrice`):** Selects the input data (Standard or Heikin Ashi).
* **StdDev Period (`InpPeriod`):** The lookback period used *only* for calculating the standard deviation (volatility). Default is `20`.
* **Deviation (`InpDeviation`):** The multiplier for the standard deviation. Default is `2.0`.

## 5. Usage and Trading Strategies

### The "Laguerre Squeeze"

Just like with Bollinger Bands, when the bands contract (narrow), it indicates a period of low volatility. Because the Laguerre filter is faster, the "squeeze" often appears more clearly defined. A breakout from this squeeze is a powerful signal.

### Trend Following

* **Uptrend:** Price tends to stay between the Centerline and the Upper Band. The Centerline acts as dynamic support.
* **Downtrend:** Price tends to stay between the Centerline and the Lower Band. The Centerline acts as dynamic resistance.

### Reversals

Because the Laguerre centerline is so responsive, a crossover of the price and the centerline is a more significant event than crossing a standard SMA.

* **Long Signal:** Price crosses above the Laguerre Centerline, and the bands start to expand.
* **Short Signal:** Price crosses below the Laguerre Centerline, and the bands start to expand.
